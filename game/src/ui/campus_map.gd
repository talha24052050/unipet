extends Control
## Kampüs haritası: OSM verisinden çizilir; yer adlarına dokunup ışınlanılır (tek bölge: tüm kampüs).
## Görsel dil YTÜ'nün resmi kampüs haritasından esinlenir (renkler/tarz); görselin kendisi kullanılmaz.
## Sahne: scenes/ui/campus_map.tscn. Açan sahne `CampusMap.open_from(here_pos)` ile çağırır.

const ZoneCatalog := preload("res://src/world/zone_catalog.gd")
const CAMPUS_DATA: String = "res://data/zones/davutpasa_campus.json"
const PLACES_DATA: String = "res://data/places.json"
## Haritada adıyla gösterilen yer türleri (kalabalık olmasın diye hepsi değil).
const PLACE_KINDS: Dictionary = {
	"faculty": Color(0.12, 0.18, 0.42),
	"food": Color(0.85, 0.35, 0.15),
	"landmark": Color(0.73, 0.28, 0.23),
	"sport": Color(0.2, 0.5, 0.2),
	"dorm": Color(0.45, 0.35, 0.6),
	"transport": Color(0.3, 0.3, 0.3),
}
const PLACE_FONT_SIZE: int = 15
const PLACE_DOT: float = 5.0
## Yere dokunma toleransı (px).
const PLACE_TOUCH_RADIUS: float = 28.0
const GAME_SCENE: String = "res://scenes/main.tscn"

const COLOR_BG: Color = Color(0.93, 0.93, 0.9)
const COLOR_CAMPUS: Color = Color(0.56, 0.74, 0.38)
const COLOR_GRASS: Color = Color(0.49, 0.73, 0.31)
const COLOR_PITCH: Color = Color(0.36, 0.6, 0.28)
const COLOR_PATH: Color = Color(0.97, 0.95, 0.88)
const COLOR_ROAD: Color = Color(0.29, 0.31, 0.33)
const COLOR_BUILDING: Color = Color(0.86, 0.86, 0.84)
const COLOR_HISTORIC: Color = Color(0.94, 0.89, 0.78)
const COLOR_HISTORIC_ROOF: Color = Color(0.73, 0.28, 0.23)
const COLOR_MARKER: Color = Color(0.12, 0.18, 0.42)
const COLOR_MARKER_HERE: Color = Color(0.96, 0.76, 0.2)
const HISTORIC_KEYS: PackedStringArray = ["kışla", "taşbina", "sanat ve tasarım", "otağ", "sancak", "hamam", "mescit", "cami"]
## Harita kenar boşluğu (px) ve üst başlık/alt panel yükseklikleri.
const MARGIN: float = 24.0
const TOP_BAR: float = 110.0
const BOTTOM_BAR: float = 170.0
const MARKER_RADIUS: float = 34.0
const PATH_WIDTH: float = 3.0
const ROAD_WIDTH: float = 6.0

## Haritayı açan sahnenin oyuncu konumu (kampüs koordinatı XZ); "buradasın" noktası.
static var here: Vector2 = Vector2.INF

var catalog: RefCounted
var selected_place: Dictionary = {}

var _data: Dictionary = {}
var _places: Array = []
var _bounds: Rect2 = Rect2()
var _scale: float = 1.0
var _offset: Vector2 = Vector2.ZERO
var _title: Label
var _confirm: PanelContainer
var _confirm_label: Label


## Oyundan haritayı açar.
static func open_from(tree: SceneTree, player_pos: Vector3) -> void:
	here = Vector2(player_pos.x, player_pos.z)
	tree.change_scene_to_file("res://scenes/ui/campus_map.tscn")


func _ready() -> void:
	catalog = Services.zones if Services.zones != null else ZoneCatalog.load_default()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CAMPUS_DATA))
	_data = parsed if parsed is Dictionary else {}
	_bounds = compute_bounds(_data)
	var pl: Variant = JSON.parse_string(FileAccess.get_file_as_string(PLACES_DATA))
	_places = (pl as Dictionary).get("places", []) if pl is Dictionary else []
	_build_ui()
	resized.connect(_fit)
	_fit()


## Tüm bina köşelerini kapsayan dikdörtgen (kampüs metresi).
static func compute_bounds(data: Dictionary) -> Rect2:
	var r: Rect2 = Rect2()
	var first: bool = true
	for b: Dictionary in data.get("buildings", []):
		for p: Array in b.get("points", []):
			var v: Vector2 = Vector2(float(p[0]), float(p[1]))
			if first:
				r = Rect2(v, Vector2.ZERO)
				first = false
			else:
				r = r.expand(v)
	return r.grow(40.0)


## Kampüs koordinatı (x, z) → ekran pikseli. Kuzey (-Z) yukarıda.
func world_to_map(w: Vector2) -> Vector2:
	return _offset + (w - _bounds.position) * _scale


func map_to_world(m: Vector2) -> Vector2:
	return (m - _offset) / _scale + _bounds.position


func _fit() -> void:
	if _bounds.size.x <= 0.0:
		return
	var avail: Vector2 = size - Vector2(MARGIN * 2.0, TOP_BAR + BOTTOM_BAR + MARGIN)
	_scale = minf(avail.x / _bounds.size.x, avail.y / _bounds.size.y)
	var used: Vector2 = _bounds.size * _scale
	_offset = Vector2((size.x - used.x) * 0.5, TOP_BAR + (avail.y - used.y) * 0.5)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BG)
	draw_rect(Rect2(world_to_map(_bounds.position), _bounds.size * _scale), COLOR_CAMPUS)
	for a: Dictionary in _data.get("areas", []):
		var poly: PackedVector2Array = _to_map(a.get("points", []))
		if poly.size() >= 3 and not Geometry2D.triangulate_polygon(poly).is_empty():
			draw_colored_polygon(poly, COLOR_PITCH if str(a.get("kind", "")) == "pitch" else COLOR_GRASS)
	for p: Dictionary in _data.get("paths", []):
		var line: PackedVector2Array = _to_map(p.get("points", []))
		if line.size() >= 2:
			var road: bool = str(p.get("kind", "")) == "service"
			draw_polyline(line, COLOR_ROAD if road else COLOR_PATH, ROAD_WIDTH if road else PATH_WIDTH, true)
	for b: Dictionary in _data.get("buildings", []):
		var poly: PackedVector2Array = _to_map(b.get("points", []))
		if poly.size() < 3 or Geometry2D.triangulate_polygon(poly).is_empty():
			continue
		var historic: bool = is_historic(str(b.get("name", "")))
		draw_colored_polygon(poly, COLOR_HISTORIC if historic else COLOR_BUILDING)
		var outline: PackedVector2Array = poly.duplicate()
		outline.append(poly[0])
		draw_polyline(outline, COLOR_HISTORIC_ROOF if historic else COLOR_ROAD.lightened(0.3), 2.0 if historic else 1.0, true)
	var font: Font = get_theme_default_font()
	_draw_places(font)
	if not selected_place.is_empty():
		var sp: Array = selected_place.get("pos", [0, 0])
		var sm: Vector2 = world_to_map(Vector2(float(sp[0]), float(sp[1])))
		draw_circle(sm, PLACE_DOT + 8.0, COLOR_MARKER_HERE)
		draw_circle(sm, PLACE_DOT + 3.0, Color.WHITE)
	if here != Vector2.INF:
		var h: Vector2 = world_to_map(here)
		draw_circle(h, 12.0, Color.WHITE)
		draw_circle(h, 8.0, Color(0.85, 0.15, 0.15))


## Yer adları: tür rengiyle küçük nokta + ad (bölge işaretlerinin altında kalır).
func _draw_places(font: Font) -> void:
	for p: Dictionary in _places:
		var kind: String = str(p.get("kind", ""))
		if not PLACE_KINDS.has(kind) or str(p.get("id", "")) == "ortabahce":
			continue
		var pos: Array = p.get("pos", [0, 0])
		var m: Vector2 = world_to_map(Vector2(float(pos[0]), float(pos[1])))
		var col: Color = PLACE_KINDS[kind]
		draw_circle(m, PLACE_DOT + 1.5, Color.WHITE)
		draw_circle(m, PLACE_DOT, col)
		var label: String = short_name(str(p.get("name", "")))
		var at: Vector2 = m + Vector2(PLACE_DOT + 3.0, PLACE_FONT_SIZE * 0.35)
		draw_string_outline(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, PLACE_FONT_SIZE, 4, Color.WHITE)
		draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, PLACE_FONT_SIZE, col)


## Uzun resmi adları haritaya sığacak kısaltmaya çevirir.
static func short_name(name: String) -> String:
	var n: String = name.split(" / ")[0]
	for pair: Array in [["Elektrik-Elektronik Fakültesi", "EEF"], ["Fen-Edebiyat Fakültesi", "FEF"],
			["Kimya-Metalurji Fakültesi", "Kimya-Met."], ["İktisat ve İdari Bilimler Fakültesi", "İİBF"],
			["Yabancı Diller Yüksekokulu", "YDYO"], ["Sanat ve Tasarım Fakültesi", "Sanat-Tasarım"],
			[" Fakültesi", ""], [" Laboratuvarı", " Lab"], ["Öğrenci Yurdu", "Yurdu"]]:
		n = n.replace(pair[0], pair[1])
	return n if n.length() <= 18 else n.substr(0, 17) + "…"


func _to_map(points: Array) -> PackedVector2Array:
	var out: PackedVector2Array = []
	for p: Array in points:
		out.append(world_to_map(Vector2(float(p[0]), float(p[1]))))
	return out


static func is_historic(name: String) -> bool:
	var n: String = name.to_lower()
	for k: String in HISTORIC_KEYS:
		if n.contains(k):
			return true
	return false


## Ekran noktasına en yakın gösterilen yer (dokunma alanı içindeyse), yoksa {}.
func place_at(screen_pos: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var best_d: float = PLACE_TOUCH_RADIUS
	for p: Dictionary in _places:
		if not PLACE_KINDS.has(str(p.get("kind", ""))) or str(p.get("id", "")) == "ortabahce":
			continue
		var pos: Array = p.get("pos", [0, 0])
		var d: float = world_to_map(Vector2(float(pos[0]), float(pos[1]))).distance_to(screen_pos)
		if d < best_d:
			best_d = d
			best = p
	return best


func _gui_input(event: InputEvent) -> void:
	var pressed_at: Vector2 = Vector2.INF
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		pressed_at = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		pressed_at = (event as InputEventMouseButton).position
	if pressed_at == Vector2.INF:
		return
	var p: Dictionary = place_at(pressed_at)
	if not p.is_empty():
		select_place(p)
		accept_event()


func select_place(p: Dictionary) -> void:
	selected_place = p
	_confirm_label.text = "%s — buraya ışınlan?" % str(p.get("name", ""))
	_confirm.visible = true
	queue_redraw()


## Seçili yere ışınlan: oyun sahnesi yeniden yüklenir, oyuncu o noktada (yürünebilir en yakın yerde) doğar.
## Odadan çıkılıp yeniden girilir (sunucunun hız koruması ışınlanmayı hile saymasın).
func travel() -> void:
	if selected_place.is_empty():
		return
	var pos: Array = selected_place.get("pos", [0, 0])
	Services.net.leave_zone()
	Services.pending_teleport = Vector2(float(pos[0]), float(pos[1]))
	here = Vector2.INF
	get_tree().change_scene_to_file(GAME_SCENE)


func close() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)


func _build_ui() -> void:
	_title = Label.new()
	_title.text = "Davutpaşa Kampüsü"
	_title.add_theme_font_size_override("font_size", 40)
	_title.add_theme_color_override("font_color", COLOR_MARKER)
	_title.position = Vector2(MARGIN, 28)
	add_child(_title)
	var back: Button = Button.new()
	back.text = "Kapat"
	back.add_theme_font_size_override("font_size", 28)
	back.custom_minimum_size = Vector2(150, 96)
	back.anchor_left = 1.0
	back.anchor_right = 1.0
	back.offset_left = -150.0 - MARGIN
	back.offset_right = -MARGIN
	back.offset_top = 8.0
	back.offset_bottom = 104.0
	back.pressed.connect(close)
	add_child(back)

	_confirm = PanelContainer.new()
	_confirm.visible = false
	_confirm.anchor_top = 1.0
	_confirm.anchor_right = 1.0
	_confirm.anchor_bottom = 1.0
	_confirm.offset_left = MARGIN
	_confirm.offset_right = -MARGIN
	_confirm.offset_top = -BOTTOM_BAR + 8.0
	_confirm.offset_bottom = -MARGIN
	var vb: VBoxContainer = VBoxContainer.new()
	vb.name = "VBox"
	_confirm_label = Label.new()
	_confirm_label.add_theme_font_size_override("font_size", 28)
	_confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_confirm_label)
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Row"
	var go: Button = Button.new()
	go.name = "Go"
	go.text = "Git"
	go.custom_minimum_size = Vector2(0, 96)
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.add_theme_font_size_override("font_size", 30)
	go.pressed.connect(travel)
	var cancel: Button = Button.new()
	cancel.text = "Vazgeç"
	cancel.custom_minimum_size = Vector2(0, 96)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.add_theme_font_size_override("font_size", 30)
	cancel.pressed.connect(func() -> void:
		_confirm.visible = false
		selected_place = {}
		queue_redraw())
	row.add_child(go)
	row.add_child(cancel)
	vb.add_child(row)
	_confirm.add_child(vb)
	add_child(_confirm)
