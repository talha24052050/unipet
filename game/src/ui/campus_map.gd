extends Control
## Gelişmiş Kampüs Haritası v2:
## - Anlık ışınlanma kaldırıldı; kampüs içi ulaşım YTÜ Mavi Ring ve 41AT otobüsleriyle sağlanır.
## - Kategori filtreleri (Tümü, 🚌 Duraklar, ☕ Kafeler, 🏛 Fakülteler, ⭐ Simge, 👥 Oyuncular) ve anlık arama.
## - Canlı çevrimiçi oyuncular, arkadaşlar (★ @Nick), kafe doluluk rozetleri (☕ N) ve hareketli Ring / 41AT otobüsleri.
## - Bir yere veya durağa dokununca mesafe, keşif durumu, en yakın Ring durağı ve "🧭 Hedef İşaretle" rehberi açılır.

signal closed
signal waypoint_requested(target_xz: Vector2, place: Dictionary)

const ZoneCatalog := preload("res://src/world/zone_catalog.gd")
const CafeZones := preload("res://src/world/cafe_social_zones.gd")
const CAMPUS_DATA: String = "res://data/zones/davutpasa_campus.json"
const PLACES_DATA: String = "res://data/places.json"
const CARE_SPOTS_DATA: String = "res://data/care_spots.json"
const TRANSIT_DATA: String = "res://data/transit_routes.json"

## Haritada adıyla ve dokunulabilir noktasıyla gösterilen yer türleri.
const PLACE_KINDS: Dictionary = {
	"faculty": Color(0.12, 0.18, 0.42),
	"food": Color(0.85, 0.35, 0.15),
	"landmark": Color(0.73, 0.28, 0.23),
	"sport": Color(0.2, 0.5, 0.2),
	"dorm": Color(0.45, 0.35, 0.6),
	"service": Color(0.14, 0.42, 0.52),
	"transport": Color(0.08, 0.36, 0.74),
	"bus_stop": Color(0.06, 0.38, 0.82),
}
const PLACE_FONT_SIZE: int = 15
const PLACE_DOT: float = 5.0
const PLACE_TOUCH_RADIUS: float = 30.0
const GAME_SCENE: String = "res://scenes/main.tscn"
const ZOOM_MIN: float = 1.0
const ZOOM_MAX: float = 4.5
const DRAG_THRESHOLD_PX: float = 14.0

## Bakım yerleri simgeleri ve alan renkleri.
const COLOR_SPOT_EAT: Color = Color(0.92, 0.45, 0.1)
const COLOR_SPOT_REST: Color = Color(0.2, 0.5, 0.9)
const COLOR_SPOT_PLAY: Color = Color(0.25, 0.68, 0.28)
const SPOT_AREA_ALPHA: float = 0.20
const SPOT_AREA_OUTLINE_ALPHA: float = 0.45
const SPOT_ICON_RADIUS: float = 10.5
const LEGEND_FONT_SIZE: int = 16
const COLOR_LEGEND_TEXT: Color = Color(0.20, 0.22, 0.25)

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
const COLOR_RING_ROUTE: Color = Color(0.10, 0.46, 0.92, 0.82)
const COLOR_WAYPOINT: Color = Color(0.98, 0.64, 0.08, 0.95)
const HISTORIC_KEYS: PackedStringArray = ["kışla", "taşbina", "sanat ve tasarım", "otağ", "sancak", "hamam", "mescit", "cami"]

const MARGIN: float = 20.0
const TOP_BAR: float = 158.0
const BOTTOM_BAR: float = 178.0
const PATH_WIDTH: float = 3.0
const ROAD_WIDTH: float = 6.0

const FILTER_DEFS: Array[Dictionary] = [
	{"id": "all", "label": "Tümü"},
	{"id": "stops", "label": "🚌 Duraklar"},
	{"id": "cafes", "label": "☕ Kafeler"},
	{"id": "faculty", "label": "🏛 Fakülte"},
	{"id": "landmark", "label": "⭐ Simge"},
	{"id": "players", "label": "👥 Oyuncular"},
]

static var here: Vector2 = Vector2.INF

static var _cache_ready: bool = false
static var _cached_data: Dictionary = {}
static var _cached_bounds: Rect2 = Rect2()
static var _cached_places: Array = []
static var _cached_care_spots: Dictionary = {}
static var _cached_areas: Array = []
static var _cached_paths: Array = []
static var _cached_buildings: Array = []
static var _cached_transit_stops: Array = []
static var _cached_transit_loop: PackedVector2Array = PackedVector2Array()

var overlay_mode: bool = false
var catalog: RefCounted
var selected_place: Dictionary = {}
var active_filter: String = "all"
var search_query: String = ""

var _data: Dictionary = {}
var _places: Array = []
var _care_spots: Dictionary = {}
var _transit_stops: Array = []
var _bounds: Rect2 = Rect2()
var _base_scale: float = 1.0
var _base_offset: Vector2 = Vector2.ZERO
var _scale: float = 1.0
var _offset: Vector2 = Vector2.ZERO
var _zoom: float = 1.0
var _pan: Vector2 = Vector2.ZERO

var _title: Label
var _reset_btn: Button
var _clear_wp_btn: Button
var _search_input: LineEdit
var _filter_btns: Dictionary = {}
var _confirm: PanelContainer
var _confirm_label: Label
var _confirm_sub_label: Label
var _discovery_label: Label
var _live_refresh_accum: float = 0.0

var _touches: Dictionary = {}
var _drag_start_pos: Vector2 = Vector2.ZERO
var _drag_moved: bool = false
var _mouse_down: bool = false

var discovered: PackedStringArray = PackedStringArray()

var care_spots: Dictionary:
	get:
		return _care_spots


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

	_cached_transit_stops.clear()
	_cached_transit_loop = PackedVector2Array()
	if FileAccess.file_exists(TRANSIT_DATA):
		var tr: Variant = JSON.parse_string(FileAccess.get_file_as_string(TRANSIT_DATA))
		if tr is Dictionary:
			_cached_transit_stops = (tr as Dictionary).get("stops", [])
			var wps: Array = (tr as Dictionary).get("waypoints", [])
			_cached_transit_loop = _raw_to_vec2(wps)
			if _cached_transit_loop.size() >= 2:
				_cached_transit_loop.append(_cached_transit_loop[0])

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


## Verilen kampüs noktasına en yakın Ring / 41AT durağını döndürür: {"id", "name", "pos": Vector2, "dist": float}
static func nearest_bus_stop(target_xz: Vector2) -> Dictionary:
	_ensure_static_cache()
	var best: Dictionary = {}
	var best_d: float = INF
	for st: Dictionary in _cached_transit_stops:
		var sp: Array = st.get("shelter_pos", st.get("road_pos", [0.0, 0.0]))
		var pos: Vector2 = Vector2(float(sp[0]), float(sp[1]))
		var d: float = target_xz.distance_to(pos)
		if d < best_d:
			best_d = d
			best = {
				"id": str(st.get("id", "")),
				"name": str(st.get("name", "Durak")),
				"pos": pos,
				"dist": d,
			}
	return best


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	catalog = Services.zones if Services.zones != null else ZoneCatalog.load_default()
	_ensure_static_cache()
	_data = _cached_data
	_bounds = _cached_bounds
	_places = _cached_places
	_care_spots = _cached_care_spots
	_transit_stops = _cached_transit_stops
	discovered = (load("res://src/core/local_profile.gd") as GDScript).call("load_or_default").get("discovered")
	_build_ui()
	if not resized.is_connected(_fit):
		resized.connect(_fit)
	_fit()


func _process(delta: float) -> void:
	if not visible:
		return
	_live_refresh_accum += delta
	if _live_refresh_accum >= 0.25:
		_live_refresh_accum = 0.0
		var p_node: Node3D = _find_live_player()
		if p_node != null:
			here = Vector2(p_node.global_position.x, p_node.global_position.z)
		if _clear_wp_btn != null:
			_clear_wp_btn.visible = Services != null and not Services.active_waypoint.is_empty()
		queue_redraw()


func _find_live_player() -> Node3D:
	if not is_inside_tree() or get_tree().current_scene == null:
		return null
	return get_tree().current_scene.get_node_or_null("Player") as Node3D


func open_overlay(player_pos: Vector3) -> void:
	overlay_mode = true
	here = Vector2(player_pos.x, player_pos.z) if player_pos != Vector3.INF else Vector2.INF
	discovered = (load("res://src/core/local_profile.gd") as GDScript).call("load_or_default").get("discovered")
	if _discovery_label != null:
		_discovery_label.text = discovery_text(discovered.size(), _places.size())
	selected_place = {}
	if _confirm != null:
		_confirm.visible = false
	if _clear_wp_btn != null:
		_clear_wp_btn.visible = Services != null and not Services.active_waypoint.is_empty()
	_touches.clear()
	_mouse_down = false
	reset_view()
	visible = true
	queue_redraw()


func set_category_filter(fid: String) -> void:
	active_filter = fid
	for k: String in _filter_btns:
		var b: Button = _filter_btns[k]
		b.modulate = Color(1.0, 0.94, 0.68, 1.0) if k == active_filter else Color(0.84, 0.88, 0.94, 1.0)
	queue_redraw()


func set_search_query(q: String) -> void:
	search_query = q.strip_edges().to_lower()
	queue_redraw()


func reset_view() -> void:
	_zoom = 1.0
	_pan = Vector2.ZERO
	_update_transform()
	queue_redraw()


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


func _place_matches_filter(p: Dictionary) -> bool:
	var kind: String = str(p.get("kind", ""))
	var nm: String = str(p.get("name", "")).to_lower()
	if not search_query.is_empty() and not nm.contains(search_query):
		return false
	match active_filter:
		"all":
			return true
		"stops":
			return kind == "bus_stop" or kind == "transport"
		"cafes":
			return kind == "food"
		"faculty":
			return kind == "faculty"
		"landmark":
			return kind in ["landmark", "service", "sport", "dorm"]
		"players":
			return false
	return true


func _stop_matches_filter(st: Dictionary) -> bool:
	var nm: String = str(st.get("name", "")).to_lower()
	var ds: String = str(st.get("desc", "")).to_lower()
	if not search_query.is_empty() and not (nm.contains(search_query) or ds.contains(search_query)):
		return false
	return active_filter in ["all", "stops"]


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BG)
	draw_rect(Rect2(world_to_map(_bounds.position), _bounds.size * _scale), COLOR_CAMPUS)
	var z_width_scale: float = clampf(sqrt(_zoom), 1.0, 2.0)

	for a: Dictionary in _cached_areas:
		draw_colored_polygon(_world_poly_to_screen(a["pts"] as PackedVector2Array), a["col"] as Color)
	for p: Dictionary in _cached_paths:
		draw_polyline(_world_poly_to_screen(p["pts"] as PackedVector2Array), p["col"] as Color, float(p["w"]) * z_width_scale, true)

	# YTÜ Mavi Ring / 41AT güzergah hattı (yolların üzerinde mavi hat)
	if _cached_transit_loop.size() >= 2 and active_filter in ["all", "stops"]:
		draw_polyline(_world_poly_to_screen(_cached_transit_loop), COLOR_RING_ROUTE, 3.2 * z_width_scale, true)

	for b: Dictionary in _cached_buildings:
		var poly: PackedVector2Array = _world_poly_to_screen(b["pts"] as PackedVector2Array)
		var historic: bool = bool(b["historic"])
		draw_colored_polygon(poly, COLOR_HISTORIC if historic else COLOR_BUILDING)
		var outline: PackedVector2Array = poly.duplicate()
		outline.append(poly[0])
		draw_polyline(outline, COLOR_HISTORIC_ROOF if historic else COLOR_ROAD.lightened(0.3), (2.0 if historic else 1.0) * z_width_scale, true)

	var font: Font = get_theme_default_font()
	if active_filter in ["all", "cafes"]:
		_draw_care_spots(font)
	_draw_places(font)
	_draw_transit_stops_and_buses(font)
	_draw_live_cafe_badges(font)
	_draw_live_players(font)
	_draw_active_waypoint(font)

	if not selected_place.is_empty():
		var sp: Array = selected_place.get("pos", [0, 0])
		var sm: Vector2 = world_to_map(Vector2(float(sp[0]), float(sp[1])))
		draw_circle(sm, PLACE_DOT + 8.5, COLOR_MARKER_HERE)
		draw_circle(sm, PLACE_DOT + 3.5, Color.WHITE)
	if here != Vector2.INF:
		var h: Vector2 = world_to_map(here)
		draw_circle(h, 14.0, Color(0.85, 0.15, 0.15, 0.25))
		draw_circle(h, 11.0, Color.WHITE)
		draw_circle(h, 7.5, Color(0.85, 0.15, 0.15))

	# Üst başlık ve filtre şeridi arka planı
	draw_rect(Rect2(0.0, 0.0, size.x, TOP_BAR - 2.0), Color(0.93, 0.93, 0.90, 0.95))
	if _confirm != null and not _confirm.visible:
		draw_rect(Rect2(0.0, size.y - BOTTOM_BAR * 0.65, size.x, BOTTOM_BAR * 0.65), Color(0.93, 0.93, 0.90, 0.92))
		_draw_legend(font)


func _draw_transit_stops_and_buses(font: Font) -> void:
	var sel_id: String = str(selected_place.get("id", ""))
	if active_filter in ["all", "stops"] or not search_query.is_empty():
		for st: Dictionary in _transit_stops:
			if not _stop_matches_filter(st):
				continue
			var sp: Array = st.get("shelter_pos", st.get("road_pos", [0, 0]))
			var m: Vector2 = world_to_map(Vector2(float(sp[0]), float(sp[1])))
			draw_circle(m, 8.5, Color.WHITE)
			draw_circle(m, 6.8, Color(0.06, 0.40, 0.86))
			draw_circle(m, 2.8, Color(0.96, 0.98, 1.0))
			if active_filter == "stops" or _zoom >= 1.65 or ("stop_" + str(st.get("id", ""))) == sel_id or not search_query.is_empty():
				var st_lbl: String = "🚌 " + str(st.get("name", "Durak"))
				var at: Vector2 = m + Vector2(9.0, 5.0)
				draw_string_outline(font, at, st_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color.WHITE)
				draw_string(font, at, st_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.05, 0.28, 0.68))

	# Sahnedeki canlı hareketli Ring ve 41AT otobüsleri
	if is_inside_tree() and get_tree().current_scene != null:
		var ct: Node = get_tree().current_scene.get_node_or_null("CampusTransit")
		if ct != null and ct.has_method("get_live_buses"):
			var buses: Array = ct.call("get_live_buses")
			for bus: Dictionary in buses:
				var bp: Vector2 = bus.get("pos", Vector2.ZERO)
				var bm: Vector2 = world_to_map(bp)
				var is_41at: bool = bool(bus.get("is_41at", false))
				var bcol: Color = Color(0.92, 0.62, 0.06) if is_41at else Color(0.08, 0.52, 0.96)
				draw_rect(Rect2(bm - Vector2(18.0, 9.5), Vector2(36.0, 19.0)), Color.WHITE, true)
				draw_rect(Rect2(bm - Vector2(16.5, 8.0), Vector2(33.0, 16.0)), bcol, true)
				var code_txt: String = "41AT" if is_41at else "RİNG"
				var tsz: Vector2 = font.get_string_size(code_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
				draw_string(font, bm + Vector2(-tsz.x * 0.5, 4.0), code_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.08, 0.08, 0.10) if is_41at else Color.WHITE)


func _draw_live_cafe_badges(font: Font) -> void:
	if Services == null or Services.net == null or active_filter not in ["all", "cafes", "players"]:
		return
	var cafes_state: Dictionary = Services.net.social_state.get("cafes", {})
	for cdef: Dictionary in CafeZones.CAFES:
		var cid: String = str(cdef["id"])
		var mems: Array = cafes_state.get(cid, [])
		if mems.is_empty():
			continue
		var dpos: Vector2 = cdef["door"]
		var m: Vector2 = world_to_map(dpos) + Vector2(0.0, -14.0)
		var txt: String = "☕ %d" % mems.size()
		var tw: float = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 12.0
		draw_rect(Rect2(m - Vector2(tw * 0.5, 10.0), Vector2(tw, 20.0)), Color(0.18, 0.12, 0.06, 0.92), true)
		draw_string(font, m + Vector2(-tw * 0.5 + 6.0, 5.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.86, 0.42))


func _draw_live_players(font: Font) -> void:
	if active_filter not in ["all", "players"] or not is_inside_tree() or get_tree().current_scene == null:
		return
	var ns: Node = get_tree().current_scene.get_node_or_null("NetworkSync")
	if ns == null or not ns.has_method("get_remote_players"):
		return
	var friend_ids: Dictionary = {}
	if Services != null and Services.net != null:
		for f: Dictionary in Services.net.social_state.get("friends", []):
			friend_ids[str(f.get("id", ""))] = true
	var rps: Dictionary = ns.call("get_remote_players")
	for pid_v: Variant in rps:
		var pid: String = str(pid_v)
		var rp: Node3D = rps[pid_v] as Node3D
		if rp == null or not is_instance_valid(rp):
			continue
		var pm: Vector2 = world_to_map(Vector2(rp.global_position.x, rp.global_position.z))
		var is_friend: bool = friend_ids.has(pid)
		var pcol: Color = Color(0.12, 0.78, 0.42) if is_friend else Color(0.14, 0.68, 0.92)
		draw_circle(pm, 8.5 if is_friend else 6.8, Color.WHITE)
		draw_circle(pm, 6.5 if is_friend else 5.0, pcol)
		if is_friend or active_filter == "players" or _zoom >= 1.8:
			var dname: String = str(rp.get("display_name")) if "display_name" in rp else ""
			if dname.is_empty():
				dname = pid.substr(0, 6)
			var tag: String = ("★ @%s" if is_friend else "@%s") % dname
			draw_string_outline(font, pm + Vector2(9.0, 5.0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color.WHITE)
			draw_string(font, pm + Vector2(9.0, 5.0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.06, 0.46, 0.24) if is_friend else Color(0.08, 0.34, 0.56))


func _draw_active_waypoint(font: Font) -> void:
	if Services == null or Services.active_waypoint.is_empty():
		return
	var wp_xz: Vector2 = Services.active_waypoint.get("pos", Vector2.ZERO)
	var wm: Vector2 = world_to_map(wp_xz)
	if here != Vector2.INF:
		var hm: Vector2 = world_to_map(here)
		draw_dashed_line(hm, wm, COLOR_WAYPOINT, 3.2, 10.0, true)
	draw_arc(wm, 14.0, 0.0, TAU, 28, COLOR_WAYPOINT, 3.0, true)
	draw_circle(wm, 6.0, COLOR_WAYPOINT)
	var wname: String = "🧭 " + short_name(str(Services.active_waypoint.get("name", "Hedef")))
	draw_string_outline(font, wm + Vector2(12.0, -8.0), wname, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color.WHITE)
	draw_string(font, wm + Vector2(12.0, -8.0), wname, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.72, 0.38, 0.02))


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
		{"color": Color(0.06, 0.40, 0.86), "text": " Ring/41AT"},
		{"color": COLOR_SPOT_EAT, "text": " Yemek"},
		{"color": COLOR_SPOT_REST, "text": " Dinlen"},
		{"color": COLOR_SPOT_PLAY, "text": " Oyun"},
		{"color": Color(0.12, 0.78, 0.42), "text": " Arkadaş"},
	]
	var dot_radius: float = 5.0
	var dot_spacing: float = 13.0
	var sep: String = "   "
	var total_w: float = 0.0
	var sep_w: float = font.get_string_size(sep, HORIZONTAL_ALIGNMENT_LEFT, -1, LEGEND_FONT_SIZE).x
	var widths: Array = []
	for i: int in range(items.size()):
		var tw: float = font.get_string_size(str(items[i]["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, LEGEND_FONT_SIZE).x
		widths.append(tw)
		total_w += dot_spacing + tw
		if i < items.size() - 1:
			total_w += sep_w
	var cur_x: float = maxf(12.0, (size.x - total_w) * 0.5)
	var at_y: float = size.y - (BOTTOM_BAR * 0.30)
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


func _draw_places(font: Font) -> void:
	var placed_boxes: Array[Rect2] = []
	var sel_id: String = str(selected_place.get("id", ""))

	for p: Dictionary in _places:
		if not _place_matches_filter(p):
			continue
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

	for pass_idx: int in 2:
		for p: Dictionary in _places:
			if not _place_matches_filter(p):
				continue
			var pid: String = str(p.get("id", ""))
			var kind: String = str(p.get("kind", ""))
			if not PLACE_KINDS.has(kind) or pid == "ortabahce":
				continue
			var is_priority: bool = (pid == sel_id) or (active_filter != "all") or (not search_query.is_empty()) \
				or (kind in ["landmark", "faculty", "sport", "dorm"]) \
				or pid in ["yemekhane", "buyuk_ev", "yeni_kutuphane", "yildiz_store_supermarket", "kongre_merkezi", "tarihi_hamam"]
			if (pass_idx == 0 and not is_priority) or (pass_idx == 1 and is_priority):
				continue
			var pos: Array = p.get("pos", [0, 0])
			var m: Vector2 = world_to_map(Vector2(float(pos[0]), float(pos[1])))
			var label: String = short_name(str(p.get("name", "")))
			var tsize: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, PLACE_FONT_SIZE)
			var at: Vector2 = m + Vector2(PLACE_DOT + 3.5, PLACE_FONT_SIZE * 0.35)
			var lbox: Rect2 = Rect2(at.x - 2.0, at.y - PLACE_FONT_SIZE * 0.85, tsize.x + 4.0, PLACE_FONT_SIZE + 2.0)
			if pid != sel_id and _zoom < 3.2 and search_query.is_empty():
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
	return "Keşif: %d/%d yer  ·  🚌 Ring ile ulaşım (hedef seç)" % [found, total]


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


func place_at(screen_pos: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var best_d: float = PLACE_TOUCH_RADIUS

	# Önce otobüs duraklarını kontrol et (Duraklar filtresinde veya yakınsa)
	if active_filter in ["all", "stops"] or not search_query.is_empty():
		for st: Dictionary in _transit_stops:
			if not _stop_matches_filter(st):
				continue
			var sp: Array = st.get("shelter_pos", st.get("road_pos", [0, 0]))
			var d_st: float = world_to_map(Vector2(float(sp[0]), float(sp[1]))).distance_to(screen_pos)
			if d_st < best_d:
				best_d = d_st
				best = {
					"id": "stop_" + str(st.get("id", "")),
					"name": "🚌 " + str(st.get("name", "Durak")),
					"kind": "bus_stop",
					"desc": str(st.get("desc", "")),
					"pos": sp,
					"spawn": sp,
				}

	for p: Dictionary in _places:
		if not _place_matches_filter(p):
			continue
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
			var was_single_tap: bool = (_touches.size() == 1 and not _drag_moved and t.position.y > TOP_BAR - 4.0)
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
			if not _drag_moved and mb.position.y > TOP_BAR - 4.0:
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
	var is_stop: bool = str(p.get("kind", "")) == "bus_stop"
	var disc_tag: String = ""
	if not is_stop:
		disc_tag = "  ·  ★ Keşfedildi" if discovered.has(str(p.get("id", ""))) else "  ·  ☆ Keşfedilmedi"
	if here != Vector2.INF:
		var dist_m: int = roundi(here.distance_to(target_xz))
		_confirm_label.text = "%s (%d m)%s" % [str(p.get("name", "")), dist_m, disc_tag]
	else:
		_confirm_label.text = "%s%s" % [str(p.get("name", "")), disc_tag]

	if _confirm_sub_label != null:
		if is_stop:
			_confirm_sub_label.text = "🚏 YTÜ Mavi Ring & 41AT Durağı — %s" % str(p.get("desc", "Ring güzergahı üzeri"))
		else:
			var nstop: Dictionary = nearest_bus_stop(target_xz)
			if not nstop.is_empty():
				_confirm_sub_label.text = "🚌 En Yakın Ring Durağı: %s (%d m yürüme)" % [str(nstop["name"]), roundi(float(nstop["dist"]))]
			else:
				_confirm_sub_label.text = "🚌 Kampüs içi ulaşım Mavi Ring ile sağlanır."
	_confirm.visible = true
	queue_redraw()


## Işınlanma yerine harita ve 3B dünyada hedef işaretler (Ring veya yürüyüşle ulaşım için).
func mark_waypoint() -> void:
	if selected_place.is_empty():
		return
	Sfx.play(&"ui_click")
	var target_arr: Array = selected_place.get("spawn", selected_place.get("pos", [0, 0]))
	var target_xz: Vector2 = Vector2(float(target_arr[0]), float(target_arr[1]))
	var nstop: Dictionary = nearest_bus_stop(target_xz)
	var stop_nm: String = str(nstop.get("name", ""))
	var chosen: Dictionary = selected_place
	if Services != null:
		Services.set_waypoint(target_xz, str(chosen.get("name", "Hedef")), stop_nm)
	if overlay_mode:
		visible = false
		waypoint_requested.emit(target_xz, chosen)
		return
	waypoint_requested.emit(target_xz, chosen)
	get_tree().change_scene_to_file(GAME_SCENE)


## Geriye dönük metod adı uyumluluğu: artık ışınlamaz, hedef işaretler!
func travel() -> void:
	mark_waypoint()


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
	_title.add_theme_font_size_override("font_size", 32)
	_title.add_theme_color_override("font_color", COLOR_MARKER)
	_title.position = Vector2(MARGIN, 10)
	add_child(_title)

	_discovery_label = Label.new()
	_discovery_label.name = "DiscoveryLabel"
	_discovery_label.text = discovery_text(discovered.size(), _places.size())
	_discovery_label.add_theme_font_size_override("font_size", 18)
	_discovery_label.add_theme_color_override("font_color", COLOR_DISCOVERED.darkened(0.28))
	_discovery_label.position = Vector2(MARGIN, 50)
	add_child(_discovery_label)

	_clear_wp_btn = Button.new()
	_clear_wp_btn.name = "ClearWaypointButton"
	_clear_wp_btn.text = "Hedefi Sil"
	_clear_wp_btn.add_theme_font_size_override("font_size", 18)
	_clear_wp_btn.custom_minimum_size = Vector2(116, 62)
	_clear_wp_btn.anchor_left = 1.0
	_clear_wp_btn.anchor_right = 1.0
	_clear_wp_btn.offset_left = -132.0 - 112.0 - 116.0 - MARGIN - 16.0
	_clear_wp_btn.offset_right = -132.0 - 112.0 - MARGIN - 16.0
	_clear_wp_btn.offset_top = 8.0
	_clear_wp_btn.offset_bottom = 70.0
	_clear_wp_btn.visible = Services != null and not Services.active_waypoint.is_empty()
	_clear_wp_btn.pressed.connect(func() -> void:
		Sfx.play(&"ui_click")
		if Services != null:
			Services.clear_waypoint()
		_clear_wp_btn.visible = false
		queue_redraw())
	add_child(_clear_wp_btn)

	_reset_btn = Button.new()
	_reset_btn.name = "ResetViewButton"
	_reset_btn.text = "Sıfırla"
	_reset_btn.add_theme_font_size_override("font_size", 20)
	_reset_btn.custom_minimum_size = Vector2(108, 62)
	_reset_btn.anchor_left = 1.0
	_reset_btn.anchor_right = 1.0
	_reset_btn.offset_left = -132.0 - 108.0 - MARGIN - 8.0
	_reset_btn.offset_right = -132.0 - MARGIN - 8.0
	_reset_btn.offset_top = 8.0
	_reset_btn.offset_bottom = 70.0
	_reset_btn.visible = false
	_reset_btn.pressed.connect(func() -> void:
		Sfx.play(&"ui_click")
		reset_view())
	add_child(_reset_btn)

	var back: Button = Button.new()
	back.name = "CloseButton"
	back.text = "Kapat"
	back.add_theme_font_size_override("font_size", 24)
	back.custom_minimum_size = Vector2(132, 62)
	back.anchor_left = 1.0
	back.anchor_right = 1.0
	back.offset_left = -132.0 - MARGIN
	back.offset_right = -MARGIN
	back.offset_top = 8.0
	back.offset_bottom = 70.0
	back.pressed.connect(close)
	add_child(back)

	# Arama + Kategori filtre satırı (y = 82..150)
	var filter_row: HBoxContainer = HBoxContainer.new()
	filter_row.name = "FilterBar"
	filter_row.anchor_right = 1.0
	filter_row.offset_left = MARGIN
	filter_row.offset_right = -MARGIN
	filter_row.offset_top = 82.0
	filter_row.offset_bottom = 148.0
	filter_row.add_theme_constant_override("separation", 6)
	add_child(filter_row)

	_search_input = LineEdit.new()
	_search_input.name = "MapSearchInput"
	_search_input.placeholder_text = "🔍 Yer/durak ara..."
	_search_input.clear_button_enabled = true
	_search_input.custom_minimum_size = Vector2(158, 52)
	_search_input.add_theme_font_size_override("font_size", 17)
	_search_input.text_changed.connect(set_search_query)
	filter_row.add_child(_search_input)

	var pill_scroll: ScrollContainer = ScrollContainer.new()
	pill_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pill_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	filter_row.add_child(pill_scroll)

	var pill_box: HBoxContainer = HBoxContainer.new()
	pill_box.add_theme_constant_override("separation", 6)
	pill_scroll.add_child(pill_box)

	for fdef: Dictionary in FILTER_DEFS:
		var fid: String = str(fdef["id"])
		var fb: Button = Button.new()
		fb.name = "Filter_%s" % fid
		fb.text = str(fdef["label"])
		fb.custom_minimum_size = Vector2(0, 50)
		fb.add_theme_font_size_override("font_size", 17)
		fb.pressed.connect(func() -> void:
			Sfx.play(&"ui_click")
			set_category_filter(fid))
		pill_box.add_child(fb)
		_filter_btns[fid] = fb
	set_category_filter("all")

	# Alt bilgi & "🧭 Hedef İşaretle" kartı (ışınlanma kaldırıldı!)
	_confirm = PanelContainer.new()
	_confirm.name = "PlaceInfoPanel"
	_confirm.visible = false
	_confirm.anchor_top = 1.0
	_confirm.anchor_right = 1.0
	_confirm.anchor_bottom = 1.0
	_confirm.offset_left = MARGIN
	_confirm.offset_right = -MARGIN
	_confirm.offset_top = -BOTTOM_BAR + 6.0
	_confirm.offset_bottom = -14.0
	var vb: VBoxContainer = VBoxContainer.new()
	vb.name = "VBox"
	vb.add_theme_constant_override("separation", 4)
	_confirm_label = Label.new()
	_confirm_label.name = "PlaceTitleLabel"
	_confirm_label.add_theme_font_size_override("font_size", 22)
	_confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_confirm_label)

	_confirm_sub_label = Label.new()
	_confirm_sub_label.name = "NearestStopLabel"
	_confirm_sub_label.add_theme_font_size_override("font_size", 18)
	_confirm_sub_label.add_theme_color_override("font_color", Color(0.58, 0.86, 1.0))
	_confirm_sub_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_confirm_sub_label)

	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Row"
	row.add_theme_constant_override("separation", 8)
	var go: Button = Button.new()
	go.name = "Go"
	go.text = "🧭 Hedef İşaretle (Ring ile Git)"
	go.custom_minimum_size = Vector2(0, 72)
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.add_theme_font_size_override("font_size", 22)
	go.pressed.connect(mark_waypoint)
	var cancel: Button = Button.new()
	cancel.text = "Vazgeç"
	cancel.custom_minimum_size = Vector2(136, 72)
	cancel.add_theme_font_size_override("font_size", 22)
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
