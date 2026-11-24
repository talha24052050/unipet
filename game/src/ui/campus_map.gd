extends Control
## Kampüs haritası: OSM verisinden çizilir; yer adlarına dokunup anında ışınlanılır.
## Sahne: scenes/ui/campus_map.tscn.
## - Oyun içinden `MapButton` ile katman (overlay_mode=true) olarak açıldığında 3B sahneyi yıkmaz (0 ms açılış/dönüş).
## - Tek başına sahne olarak da (`open_from`) çalışmaya devam eder.
## - İki parmak sıkıştırma / fare tekerleği ile yakınlaştırma (1×..4.5×) ve sürükleyerek gezinme destekler.

signal closed
signal teleport_requested(target_xz: Vector2, place: Dictionary)

const ZoneCatalog := preload("res://src/world/zone_catalog.gd")
const CAMPUS_DATA: String = "res://data/zones/davutpasa_campus.json"
const PLACES_DATA: String = "res://data/places.json"
const CARE_SPOTS_DATA: String = "res://data/care_spots.json"

## Haritada adıyla ve dokunulabilir noktasıyla gösterilen yer türleri.
const PLACE_KINDS: Dictionary = {
	"faculty": Color(0.12, 0.18, 0.42),
	"food": Color(0.85, 0.35, 0.15),
	"landmark": Color(0.73, 0.28, 0.23),
	"sport": Color(0.2, 0.5, 0.2),
	"dorm": Color(0.45, 0.35, 0.6),
	"service": Color(0.14, 0.42, 0.52),
	"transport": Color(0.3, 0.3, 0.3),
}
const PLACE_FONT_SIZE: int = 15
const PLACE_DOT: float = 5.0
## Yere dokunma toleransı (px).
const PLACE_TOUCH_RADIUS: float = 28.0
const GAME_SCENE: String = "res://scenes/main.tscn"
const ZOOM_MIN: float = 1.0
const ZOOM_MAX: float = 4.5
const DRAG_THRESHOLD_PX: float = 14.0

## Bakım yerleri simgeleri ve alan renkleri.
const COLOR_SPOT_EAT: Color = Color(0.92, 0.45, 0.1)
const COLOR_SPOT_REST: Color = Color(0.2, 0.5, 0.9)
const COLOR_SPOT_PLAY: Color = Color(0.25, 0.68, 0.28)
const SPOT_AREA_ALPHA: float = 0.22
const SPOT_AREA_OUTLINE_ALPHA: float = 0.5
const SPOT_ICON_RADIUS: float = 11.0
const LEGEND_FONT_SIZE: int = 18
const COLOR_LEGEND_TEXT: Color = Color(0.22, 0.24, 0.26)

const COLOR_BG: Color = Color(0.93, 0.93, 0.9)
const COLOR_CAMPUS: Color = Color(0.56, 0.74, 0.38)
const COLOR_GRASS: Color = Color(0.49, 0.73, 0.31)
const COLOR_WOOD: Color = Color(0.34, 0.56, 0.24)
const COLOR_PARKING: Color = Color(0.44, 0.46, 0.49)
const COLOR_PITCH: Color = Color(0.36, 0.6, 0.28)
const COLOR_PATH: Color = Color(0.97, 0.95, 0.88)
const COLOR_CYCLE: Color = Color(0.22, 0.48, 0.74)
const COLOR_ROAD: Color = Color(0.29, 0.31, 0.33)
const COLOR_BUILDING: Color = Color(0.86, 0.86, 0.84)
const COLOR_HISTORIC: Color = Color(0.94, 0.89, 0.78)
const COLOR_HISTORIC_ROOF: Color = Color(0.73, 0.28, 0.23)
const COLOR_MARKER: Color = Color(0.12, 0.18, 0.42)
const COLOR_MARKER_HERE: Color = Color(0.96, 0.76, 0.2)
const COLOR_DISCOVERED: Color = Color(0.98, 0.72, 0.1)
const COLOR_UNDISCOVERED: Color = Color(0.6, 0.6, 0.6)
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

## Statik önbellek: harita her açıldığında JSON ve poligon üçgenlemesi baştan yapılmasın (0 ms açılış!).
static var _cache_ready: bool = false
static var _cached_data: Dictionary = {}
static var _cached_bounds: Rect2 = Rect2()
static var _cached_places: Array = []
static var _cached_care_spots: Dictionary = {}
static var _cached_areas: Array = []      # [{"pts": PackedVector2Array, "col": Color}]
static var _cached_paths: Array = []      # [{"pts": PackedVector2Array, "col": Color, "w": float, "road": bool}]
static var _cached_buildings: Array = []  # [{"pts": PackedVector2Array, "historic": bool}]

var overlay_mode: bool = false
var catalog: RefCounted
var selected_place: Dictionary = {}

var _data: Dictionary = {}
var _places: Array = []
var _care_spots: Dictionary = {}
var _bounds: Rect2 = Rect2()
var _base_scale: float = 1.0
var _base_offset: Vector2 = Vector2.ZERO
var _scale: float = 1.0
var _offset: Vector2 = Vector2.ZERO
var _zoom: float = 1.0
var _pan: Vector2 = Vector2.ZERO

var _title: Label
var _reset_btn: Button
var _confirm: PanelContainer
var _confirm_label: Label
var _discovery_label: Label
## Dokunma / sürükleme / sıkıştırma durumu
var _touches: Dictionary = {}
var _drag_start_pos: Vector2 = Vector2.ZERO
var _drag_moved: bool = false
var _mouse_down: bool = false

## Keşfedilen yer id'leri (profil); haritada altın halka, keşfedilmeyen küçük yerler gri nokta.
var discovered: PackedStringArray = PackedStringArray()

var care_spots: Dictionary:
	get:
		return _care_spots


## Tek başına sahne olarak açar (eski uyumluluk). Oyun içinde `MapButton` doğrudan overlay_mode kullanır.
static func open_from(tree: SceneTree, player_pos: Vector3) -> void:
	here = Vector2(player_pos.x, player_pos.z) if player_pos != Vector3.INF else Vector2.INF
	tree.change_scene_to_file("res://scenes/ui/campus_map.tscn")


static func _ensure_static_cache() -> void:
	if _cache_ready:
		return
	_cache_ready = true
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CAMPUS_DATA))
	_cached_data = parsed if parsed is Dictionary else {}
	_cached_bounds = compute_bounds(_cached_data)
	var pl: Variant = JSON.parse_string(FileAccess.get_file_as_string(PLACES_DATA))
	_cached_places = (pl as Dictionary).get("places", []) if pl is Dictionary else []
	var cs: Variant = JSON.parse_string(FileAccess.get_file_as_string(CARE_SPOTS_DATA))
	_cached_care_spots = cs if cs is Dictionary else {}

	_cached_areas.clear()
	for a: Dictionary in _cached_data.get("areas", []):
		var wpoly: PackedVector2Array = _raw_to_vec2(a.get("points", []))
		if wpoly.size() >= 3 and not Geometry2D.triangulate_polygon(wpoly).is_empty():
			var ak: String = str(a.get("kind", ""))
			var acol: Color = COLOR_PITCH if ak == "pitch" \
				else (COLOR_PARKING if ak == "parking" \
				else (COLOR_WOOD if ak == "wood" else COLOR_GRASS))
			_cached_areas.append({"pts": wpoly, "col": acol})

	_cached_paths.clear()
	for p: Dictionary in _cached_data.get("paths", []):
		var wline: PackedVector2Array = _raw_to_vec2(p.get("points", []))
		if wline.size() < 2:
			continue
		var pk: String = str(p.get("kind", ""))
		var pcol: Color = COLOR_PATH
		var pw: float = PATH_WIDTH
		if pk == "residential" or pk == "residential_oneway":
			pcol = COLOR_ROAD
			pw = ROAD_WIDTH + (1.2 if pk == "residential" else 0.0)
		elif pk == "service" or pk == "parking_aisle":
			pcol = COLOR_ROAD.lightened(0.08)
			pw = ROAD_WIDTH * 0.7
		elif pk == "cycleway":
			pcol = COLOR_CYCLE
			pw = PATH_WIDTH * 0.85
		_cached_paths.append({"pts": wline, "col": pcol, "w": pw})

	_cached_buildings.clear()
	for b: Dictionary in _cached_data.get("buildings", []):
		var wpoly: PackedVector2Array = _raw_to_vec2(b.get("points", []))
		if wpoly.size() < 3 or Geometry2D.triangulate_polygon(wpoly).is_empty():
			continue
		_cached_buildings.append({"pts": wpoly, "historic": is_historic(str(b.get("name", "")))})


static func _raw_to_vec2(points: Array) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	out.resize(points.size())
	for i: int in points.size():
		var pt: Array = points[i]
		out[i] = Vector2(float(pt[0]), float(pt[1]))
	return out


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	catalog = Services.zones if Services.zones != null else ZoneCatalog.load_default()
	_ensure_static_cache()
	_data = _cached_data
	_bounds = _cached_bounds
	_places = _cached_places
	_care_spots = _cached_care_spots
	discovered = (load("res://src/core/local_profile.gd") as GDScript).call("load_or_default").get("discovered")
	_build_ui()
	if not resized.is_connected(_fit):
		resized.connect(_fit)
	_fit()


## Overlay modunda haritayı anında açar; oyuncu konumunu ve keşif sayacını günceller.
func open_overlay(player_pos: Vector3) -> void:
	overlay_mode = true
	here = Vector2(player_pos.x, player_pos.z) if player_pos != Vector3.INF else Vector2.INF
	discovered = (load("res://src/core/local_profile.gd") as GDScript).call("load_or_default").get("discovered")
	if _discovery_label != null:
		_discovery_label.text = discovery_text(discovered.size(), _places.size())
	selected_place = {}
	if _confirm != null:
		_confirm.visible = false
	_touches.clear()
	_mouse_down = false
	reset_view()
	visible = true
	queue_redraw()


func reset_view() -> void:
	_zoom = 1.0
	_pan = Vector2.ZERO
	_update_transform()
	queue_redraw()


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
	if avail.x <= 1.0 or avail.y <= 1.0:
		return
	_base_scale = minf(avail.x / _bounds.size.x, avail.y / _bounds.size.y)
	var used: Vector2 = _bounds.size * _base_scale
	_base_offset = Vector2((size.x - used.x) * 0.5, TOP_BAR + (avail.y - used.y) * 0.5)
	_update_transform()
	queue_redraw()


func _update_transform() -> void:
	_zoom = clampf(_zoom, ZOOM_MIN, ZOOM_MAX)
	_scale = _base_scale * _zoom
	if _zoom <= 1.001:
		_pan = Vector2.ZERO
		_offset = _base_offset
	else:
		var map_size: Vector2 = _bounds.size * _scale
		var view_center: Vector2 = Vector2(size.x * 0.5, TOP_BAR + (size.y - TOP_BAR - BOTTOM_BAR) * 0.5)
		var base_center: Vector2 = _base_offset + _bounds.size * _base_scale * 0.5
		var max_pan: Vector2 = (map_size - _bounds.size * _base_scale) * 0.5 + Vector2(80.0, 80.0)
		_pan.x = clampf(_pan.x, -max_pan.x, max_pan.x)
		_pan.y = clampf(_pan.y, -max_pan.y, max_pan.y)
		_offset = view_center - map_size * 0.5 + (base_center - view_center) + _pan
	if _reset_btn != null:
		_reset_btn.visible = _zoom > 1.02 or _pan.length() > 4.0


func _zoom_at(screen_pivot: Vector2, new_zoom: float) -> void:
	var clamped: float = clampf(new_zoom, ZOOM_MIN, ZOOM_MAX)
	if is_equal_approx(clamped, _zoom):
		return
	var world_before: Vector2 = map_to_world(screen_pivot)
	_zoom = clamped
	_update_transform()
	if _zoom > 1.001:
		var mapped_after: Vector2 = world_to_map(world_before)
		_pan += screen_pivot - mapped_after
		_update_transform()
	queue_redraw()


func _world_poly_to_screen(wpoly: PackedVector2Array) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var n: int = wpoly.size()
	out.resize(n)
	var bpos: Vector2 = _bounds.position
	var sc: float = _scale
	var off: Vector2 = _offset
	for i: int in n:
		out[i] = off + (wpoly[i] - bpos) * sc
	return out


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BG)
	draw_rect(Rect2(world_to_map(_bounds.position), _bounds.size * _scale), COLOR_CAMPUS)
	var z_width_scale: float = clampf(sqrt(_zoom), 1.0, 2.0)

	for a: Dictionary in _cached_areas:
		draw_colored_polygon(_world_poly_to_screen(a["pts"] as PackedVector2Array), a["col"] as Color)
	for p: Dictionary in _cached_paths:
		draw_polyline(_world_poly_to_screen(p["pts"] as PackedVector2Array), p["col"] as Color, float(p["w"]) * z_width_scale, true)
	for b: Dictionary in _cached_buildings:
		var poly: PackedVector2Array = _world_poly_to_screen(b["pts"] as PackedVector2Array)
		var historic: bool = bool(b["historic"])
		draw_colored_polygon(poly, COLOR_HISTORIC if historic else COLOR_BUILDING)
		var outline: PackedVector2Array = poly.duplicate()
		outline.append(poly[0])
		draw_polyline(outline, COLOR_HISTORIC_ROOF if historic else COLOR_ROAD.lightened(0.3), (2.0 if historic else 1.0) * z_width_scale, true)

	var font: Font = get_theme_default_font()
	_draw_care_spots(font)
	_draw_places(font)
	if not selected_place.is_empty():
		var sp: Array = selected_place.get("pos", [0, 0])
		var sm: Vector2 = world_to_map(Vector2(float(sp[0]), float(sp[1])))
		draw_circle(sm, PLACE_DOT + 8.0, COLOR_MARKER_HERE)
		draw_circle(sm, PLACE_DOT + 3.0, Color.WHITE)
	if here != Vector2.INF:
		var h: Vector2 = world_to_map(here)
		draw_circle(h, 14.0, Color(0.85, 0.15, 0.15, 0.25))
		draw_circle(h, 11.0, Color.WHITE)
		draw_circle(h, 7.5, Color(0.85, 0.15, 0.15))

	# Üst başlık şeridi arka planı (yakınlaştırılmış harita başlık butonlarının altına temiz girsin)
	draw_rect(Rect2(0.0, 0.0, size.x, TOP_BAR - 4.0), Color(0.93, 0.93, 0.90, 0.92))
	if _confirm != null and not _confirm.visible:
		draw_rect(Rect2(0.0, size.y - BOTTOM_BAR * 0.78, size.x, BOTTOM_BAR * 0.78), Color(0.93, 0.93, 0.90, 0.90))
		_draw_legend(font)


## Bakım yerleri: her tür için yarı saydam etki alanı ve merkez simgesi.
func _draw_care_spots(font: Font) -> void:
	var kinds: PackedStringArray = ["eat", "rest", "play"]
	for k: String in kinds:
		var col: Color = COLOR_SPOT_EAT if k == "eat" else (COLOR_SPOT_REST if k == "rest" else COLOR_SPOT_PLAY)
		for s: Dictionary in _care_spots.get(k, []):
			var w: Vector2 = Vector2(float(s.get("x", 0.0)), float(s.get("z", 0.0)))
			var center: Vector2 = world_to_map(w)
			var r_px: float = float(s.get("r", 20.0)) * _scale
			var fill: Color = col
			fill.a = SPOT_AREA_ALPHA
			draw_circle(center, r_px, fill)
			var outline: Color = col
			outline.a = SPOT_AREA_OUTLINE_ALPHA
			draw_arc(center, r_px, 0.0, TAU, 36, outline, 1.5, true)

	for k: String in kinds:
		var col: Color = COLOR_SPOT_EAT if k == "eat" else (COLOR_SPOT_REST if k == "rest" else COLOR_SPOT_PLAY)
		for s: Dictionary in _care_spots.get(k, []):
			var w: Vector2 = Vector2(float(s.get("x", 0.0)), float(s.get("z", 0.0)))
			var icon_pos: Vector2 = world_to_map(w)
			if _has_overlapping_spot(w, k):
				if k == "rest":
					icon_pos += Vector2(-SPOT_ICON_RADIUS - 1.0, 0.0)
				elif k == "play":
					icon_pos += Vector2(SPOT_ICON_RADIUS + 1.0, 0.0)

			draw_circle(icon_pos, SPOT_ICON_RADIUS + 1.5, Color.WHITE)
			draw_circle(icon_pos, SPOT_ICON_RADIUS, col)

			if k == "eat":
				draw_line(icon_pos + Vector2(-3.0, -5.0), icon_pos + Vector2(-3.0, 5.0), Color.WHITE, 1.8)
				draw_line(icon_pos + Vector2(-4.5, -5.0), icon_pos + Vector2(-1.5, -5.0), Color.WHITE, 1.5)
				draw_line(icon_pos + Vector2(3.0, -5.0), icon_pos + Vector2(3.0, 5.0), Color.WHITE, 1.8)
			elif k == "rest":
				var z_str: String = "z"
				var sz: Vector2 = font.get_string_size(z_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
				var ascent: float = font.get_ascent(14)
				var at: Vector2 = icon_pos + Vector2(-sz.x * 0.5, ascent * 0.35)
				draw_string(font, at, z_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
			elif k == "play":
				draw_circle(icon_pos, 4.0, Color.WHITE)


func _has_overlapping_spot(w: Vector2, current_kind: String) -> bool:
	for other_kind: String in ["eat", "rest", "play"]:
		if other_kind == current_kind:
			continue
		for other_s: Dictionary in _care_spots.get(other_kind, []):
			var other_w: Vector2 = Vector2(float(other_s.get("x", 0.0)), float(other_s.get("z", 0.0)))
			if w.distance_squared_to(other_w) < 4.0:
				return true
	return false


func _draw_legend(font: Font) -> void:
	var items: Array = [
		{"color": COLOR_SPOT_EAT, "text": " Yemek"},
		{"color": COLOR_SPOT_REST, "text": " Dinlenme 2×"},
		{"color": COLOR_SPOT_PLAY, "text": " Oyun 2×"},
	]
	var dot_radius: float = 5.0
	var dot_spacing: float = 14.0
	var sep: String = "    "
	var total_w: float = 0.0
	var sep_w: float = font.get_string_size(sep, HORIZONTAL_ALIGNMENT_LEFT, -1, LEGEND_FONT_SIZE).x
	var widths: Array = []
	for i: int in range(items.size()):
		var tw: float = font.get_string_size(str(items[i]["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, LEGEND_FONT_SIZE).x
		widths.append(tw)
		total_w += dot_spacing + tw
		if i < items.size() - 1:
			total_w += sep_w
	var cur_x: float = (size.x - total_w) * 0.5
	var at_y: float = size.y - (BOTTOM_BAR * 0.42)
	var dot_y: float = at_y - font.get_ascent(LEGEND_FONT_SIZE) * 0.3
	for i: int in range(items.size()):
		var col: Color = items[i]["color"]
		var txt: String = str(items[i]["text"])
		var dot_center: Vector2 = Vector2(cur_x + dot_radius, dot_y)
		draw_circle(dot_center, dot_radius + 1.0, Color.WHITE)
		draw_circle(dot_center, dot_radius, col)
		cur_x += dot_spacing
		draw_string_outline(font, Vector2(cur_x, at_y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, LEGEND_FONT_SIZE, 3, Color.WHITE)
		draw_string(font, Vector2(cur_x, at_y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, LEGEND_FONT_SIZE, COLOR_LEGEND_TEXT)
		cur_x += float(widths[i])
		if i < items.size() - 1:
			cur_x += sep_w


## Yer adları: çakışma önlemeli akıllı etiket yerleşimi (yakınlaştırdıkça tüm etiketler açılır!).
func _draw_places(font: Font) -> void:
	var placed_boxes: Array[Rect2] = []
	var sel_id: String = str(selected_place.get("id", ""))

	# Önce noktaları çiz
	for p: Dictionary in _places:
		var kind: String = str(p.get("kind", ""))
		var pos: Array = p.get("pos", [0, 0])
		var m: Vector2 = world_to_map(Vector2(float(pos[0]), float(pos[1])))
		var found: bool = discovered.has(str(p.get("id", "")))
		if found:
			draw_circle(m, PLACE_DOT + 4.5, COLOR_DISCOVERED)
		if not PLACE_KINDS.has(kind) or str(p.get("id", "")) == "ortabahce":
			draw_circle(m, PLACE_DOT * 0.7 + 1.5, Color.WHITE)
			draw_circle(m, PLACE_DOT * 0.7, COLOR_DISCOVERED if found else COLOR_UNDISCOVERED)
			continue
		var col: Color = PLACE_KINDS[kind]
		draw_circle(m, PLACE_DOT + 1.8, Color.WHITE)
		draw_circle(m, PLACE_DOT, col)

	# Sonra etiketleri önem sırasına göre (seçili -> ana binalar -> ikincil servisler) çakıştırmadan çiz
	for pass_idx: int in 2:
		for p: Dictionary in _places:
			var pid: String = str(p.get("id", ""))
			var kind: String = str(p.get("kind", ""))
			if not PLACE_KINDS.has(kind) or pid == "ortabahce":
				continue
			var is_priority: bool = (pid == sel_id) or (kind in ["landmark", "faculty", "sport", "dorm"]) \
				or pid in ["yemekhane", "buyuk_ev", "yeni_kutuphane", "yildiz_store_supermarket", "kongre_merkezi"]
			if (pass_idx == 0 and not is_priority) or (pass_idx == 1 and is_priority):
				continue
			var pos: Array = p.get("pos", [0, 0])
			var m: Vector2 = world_to_map(Vector2(float(pos[0]), float(pos[1])))
			var label: String = short_name(str(p.get("name", "")))
			var tsize: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, PLACE_FONT_SIZE)
			var at: Vector2 = m + Vector2(PLACE_DOT + 3.5, PLACE_FONT_SIZE * 0.35)
			var lbox: Rect2 = Rect2(at.x - 2.0, at.y - PLACE_FONT_SIZE * 0.85, tsize.x + 4.0, PLACE_FONT_SIZE + 2.0)
			if pid != sel_id and _zoom < 3.2:
				var overlaps: bool = false
				for eb: Rect2 in placed_boxes:
					if eb.intersects(lbox):
						overlaps = true
						break
				if overlaps:
					continue
			placed_boxes.append(lbox)
			var col: Color = PLACE_KINDS[kind]
			draw_string_outline(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, PLACE_FONT_SIZE, 4, Color.WHITE)
			draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, PLACE_FONT_SIZE, col)


static func discovery_text(found: int, total: int) -> String:
	return "Keşif: %d/%d yer  ·  Yakınlaştır / dokun ve ışınlan" % [found, total]


## Uzun resmi adları haritaya sığacak kısaltmaya çevirir.
static func short_name(name: String) -> String:
	var n: String = name.split(" / ")[0]
	for pair: Array in [
			["Davutpaşa Kışlası Mesciti", "Kışla Mescidi"],
			["Yıldız Teknik Üniversitesi Davutpaşa Kışlası", "Tarihi Kışla"],
			["Şehit Prof. Dr. İlhan Varank Kütüphanesi", "İlhan Varank Küt."],
			["Yeni Merkez Kütüphanesi", "Yeni Kütüphane"],
			["Merkez Kütüphanesi", "Yeni Kütüphane"],
			["Elektrik Elektronik Fakültesi", "EEF"],
			["Elektrik-Elektronik Fakültesi", "EEF"],
			["Fen-Edebiyat Fakültesi", "FEF"],
			["Kimya-Metalurji Fakültesi", "Kimya-Met."],
			["İktisat ve İdari Bilimler Fakültesi", "İİBF"],
			["Yabancı Diller Yüksekokulu", "YDYO"],
			["Sanat ve Tasarım Fakültesi", "Sanat-Tasarım"],
			[" Fakültesi", ""],
			[" Laboratuvarı", " Lab"],
			["Öğrenci Yurdu", "Yurdu"]]:
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
	if event is InputEventScreenTouch:
		var t: InputEventScreenTouch = event
		if t.pressed:
			_touches[t.index] = t.position
			if _touches.size() == 1:
				_drag_start_pos = t.position
				_drag_moved = false
			else:
				_drag_moved = true
		else:
			var was_single_tap: bool = (_touches.size() == 1 and not _drag_moved and t.position.y > TOP_BAR - 8.0)
			_touches.erase(t.index)
			if was_single_tap:
				var p: Dictionary = place_at(t.position)
				if not p.is_empty():
					select_place(p)
					accept_event()
		return

	if event is InputEventScreenDrag:
		var dg: InputEventScreenDrag = event
		if not _touches.has(dg.index):
			return
		if _touches.size() == 1:
			if dg.position.distance_to(_drag_start_pos) > DRAG_THRESHOLD_PX:
				_drag_moved = true
			if _drag_moved and _zoom > 1.001:
				_pan += dg.relative
				_update_transform()
				queue_redraw()
		elif _touches.size() >= 2:
			_drag_moved = true
			var other_idx: int = -1
			for k: int in _touches:
				if k != dg.index:
					other_idx = k
					break
			if other_idx != -1:
				var other_pos: Vector2 = _touches[other_idx]
				var prev_d: float = (_touches[dg.index] as Vector2).distance_to(other_pos)
				var new_d: float = dg.position.distance_to(other_pos)
				if prev_d > 4.0 and new_d > 4.0:
					var pivot: Vector2 = (dg.position + other_pos) * 0.5
					_zoom_at(pivot, _zoom * (new_d / prev_d))
		_touches[dg.index] = dg.position
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom_at(mb.position, _zoom * 1.18)
				accept_event()
				return
			if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_at(mb.position, _zoom / 1.18)
				accept_event()
				return
			if mb.button_index == MOUSE_BUTTON_LEFT:
				_mouse_down = true
				_drag_start_pos = mb.position
				_drag_moved = false
		elif mb.button_index == MOUSE_BUTTON_LEFT and _mouse_down:
			_mouse_down = false
			if not _drag_moved and mb.position.y > TOP_BAR - 8.0:
				var pm: Dictionary = place_at(mb.position)
				if not pm.is_empty():
					select_place(pm)
					accept_event()
		return

	if event is InputEventMouseMotion and _mouse_down:
		var mm: InputEventMouseMotion = event
		if mm.position.distance_to(_drag_start_pos) > DRAG_THRESHOLD_PX:
			_drag_moved = true
		if _drag_moved and _zoom > 1.001:
			_pan += mm.relative
			_update_transform()
			queue_redraw()


func select_place(p: Dictionary) -> void:
	Sfx.play(&"ui_click")
	selected_place = p
	var target_arr: Array = p.get("spawn", p.get("pos", [0, 0]))
	var target_xz: Vector2 = Vector2(float(target_arr[0]), float(target_arr[1]))
	if here != Vector2.INF:
		var dist_m: int = roundi(here.distance_to(target_xz))
		_confirm_label.text = "%s (%d m) — giriş meydanına ışınlan?" % [str(p.get("name", "")), dist_m]
	else:
		_confirm_label.text = "%s — buraya ışınlan?" % str(p.get("name", ""))
	_confirm.visible = true
	queue_redraw()


## Seçili yere güvenli dış giriş noktasından (`spawn`) anında ışınlan!
func travel() -> void:
	if selected_place.is_empty():
		return
	Sfx.play(&"teleport")
	var target_arr: Array = selected_place.get("spawn", selected_place.get("pos", [0, 0]))
	var target_xz: Vector2 = Vector2(float(target_arr[0]), float(target_arr[1]))
	if overlay_mode:
		var chosen: Dictionary = selected_place
		visible = false
		teleport_requested.emit(target_xz, chosen)
		return
	if Services.net != null:
		Services.net.leave_zone()
	Services.pending_teleport = target_xz
	here = Vector2.INF
	get_tree().change_scene_to_file(GAME_SCENE)


func close() -> void:
	Sfx.play(&"ui_click")
	if overlay_mode:
		visible = false
		closed.emit()
		return
	get_tree().change_scene_to_file(GAME_SCENE)


func _build_ui() -> void:
	_title = Label.new()
	_title.text = "Davutpaşa Kampüsü"
	_title.add_theme_font_size_override("font_size", 38)
	_title.add_theme_color_override("font_color", COLOR_MARKER)
	_title.position = Vector2(MARGIN, 14)
	add_child(_title)
	_discovery_label = Label.new()
	_discovery_label.name = "DiscoveryLabel"
	_discovery_label.text = discovery_text(discovered.size(), _places.size())
	_discovery_label.add_theme_font_size_override("font_size", 22)
	_discovery_label.add_theme_color_override("font_color", COLOR_DISCOVERED.darkened(0.25))
	_discovery_label.position = Vector2(MARGIN, 66)
	add_child(_discovery_label)

	_reset_btn = Button.new()
	_reset_btn.name = "ResetViewButton"
	_reset_btn.text = "Sıfırla"
	_reset_btn.add_theme_font_size_override("font_size", 24)
	_reset_btn.custom_minimum_size = Vector2(132, 96)
	_reset_btn.anchor_left = 1.0
	_reset_btn.anchor_right = 1.0
	_reset_btn.offset_left = -150.0 - 132.0 - MARGIN - 12.0
	_reset_btn.offset_right = -150.0 - MARGIN - 12.0
	_reset_btn.offset_top = 8.0
	_reset_btn.offset_bottom = 104.0
	_reset_btn.visible = false
	_reset_btn.pressed.connect(func() -> void:
		Sfx.play(&"ui_click")
		reset_view())
	add_child(_reset_btn)

	var back: Button = Button.new()
	back.name = "CloseButton"
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
	_confirm_label.add_theme_font_size_override("font_size", 26)
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
		Sfx.play(&"ui_click")
		_confirm.visible = false
		selected_place = {}
		queue_redraw())
	row.add_child(go)
	row.add_child(cancel)
	vb.add_child(row)
	_confirm.add_child(vb)
	add_child(_confirm)
