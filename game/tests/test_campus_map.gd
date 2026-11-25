extends RefCounted

const MapScript := preload("res://src/ui/campus_map.gd")


func _make() -> Control:
	var m: Control = (load("res://scenes/ui/campus_map.tscn") as PackedScene).instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(m)
	if m.get("catalog") == null:
		m.call("_ready")
	m.set_anchors_preset(Control.PRESET_TOP_LEFT)
	m.size = Vector2(720, 1280)
	m.call("_fit")
	return m


func test_map_fits_and_roundtrips() -> String:
	var m: Control = _make()
	var w: Vector2 = Vector2(-103.5, -95.2)
	var back: Vector2 = m.call("map_to_world", m.call("world_to_map", w))
	var err: String = ""
	if not back.is_equal_approx(w):
		err = "dönüşüm geri dönmüyor: %s" % back
	var places: Array = m.get("_places")
	for p: Dictionary in places:
		var pos: Array = p["pos"]
		if not Rect2(Vector2.ZERO, m.size).has_point(m.call("world_to_map", Vector2(float(pos[0]), float(pos[1])))):
			err = "%s ekran dışında" % p["id"]
	m.free()
	return err


func test_tap_selects_place_and_shows_nearest_ring_stop() -> String:
	var m: Control = _make()
	var places: Array = m.get("_places")
	var target: Dictionary = {}
	for p: Dictionary in places:
		if p["id"] == "yemekhane":
			target = p
	var pos: Array = target["pos"]
	var hit: Dictionary = m.call("place_at", m.call("world_to_map", Vector2(float(pos[0]), float(pos[1]))) + Vector2(3, 2))
	var miss: Dictionary = m.call("place_at", Vector2(2, 2))
	m.call("select_place", hit)
	var sel: Dictionary = m.get("selected_place")
	var stop_lbl: Label = m.find_child("NearestStopLabel", true, false) as Label
	var has_stop_hint: bool = stop_lbl != null and stop_lbl.text.contains("En Yakın Ring Durağı")
	m.free()
	if hit.get("id") != "yemekhane" or not miss.is_empty() or sel.get("id") != "yemekhane" or not has_stop_hint:
		return "yer seçimi veya en yakın Ring durağı bilgisi hatalı: %s %s" % [hit.get("id"), stop_lbl.text if stop_lbl != null else "null"]
	return ""


func test_historic_names() -> String:
	if not MapScript.is_historic("Yıldız Teknik Üniversitesi Davutpaşa Kışlası") or MapScript.is_historic("Yemekhane"):
		return "tarihi bina tanıma yanlış"
	return ""


func test_care_spots_filters_and_transit_stops_drawn() -> String:
	var raw: String = FileAccess.get_file_as_string("res://data/care_spots.json")
	var json_data: Dictionary = JSON.parse_string(raw) as Dictionary
	var expected_count: int = 0
	for k: String in ["eat", "rest", "play"]:
		expected_count += (json_data.get(k, []) as Array).size()

	var m: Control = _make()
	var loaded: Dictionary = m.get("_care_spots")
	var actual_count: int = 0
	for k: String in ["eat", "rest", "play"]:
		actual_count += (loaded.get(k, []) as Array).size()
	if actual_count != expected_count or actual_count == 0:
		m.free()
		return "care_spots yer sayısı JSON ile uyuşmuyor: %d != %d" % [actual_count, expected_count]

	var t_stops: Array = m.get("_transit_stops")
	if t_stops.size() < 10:
		m.free()
		return "haritada en az 10 Ring/41AT durağı olmalıydı: %d" % t_stops.size()

	for filt: String in ["all", "stops", "cafes", "faculty", "landmark", "players"]:
		m.call("set_category_filter", filt)
		RenderingServer.force_draw(false)
	m.call("set_category_filter", "all")
	m.call("set_search_query", "kütüphane")
	RenderingServer.force_draw(false)
	m.call("set_search_query", "")
	m.free()
	return ""


func test_short_names_for_landmarks() -> String:
	var M: GDScript = load("res://src/ui/campus_map.gd")
	var cases: Dictionary = {"Davutpaşa Kışlası Mesciti": "Kışla Mescidi", "Elektrik Elektronik Fakültesi": "EEF",
		"Yıldız Teknik Üniversitesi Davutpaşa Kışlası": "Tarihi Kışla", "Yemekhane": "Yemekhane"}
	for k: String in cases:
		if M.short_name(k) != cases[k]:
			return "%s → %s (beklenen %s)" % [k, M.short_name(k), cases[k]]
	return ""


func test_overlay_marks_waypoint_without_teleporting() -> String:
	Services.clear_waypoint()
	Services.pending_teleport = Vector2.INF
	var m: Control = _make()
	m.call("open_overlay", Vector3(-10.0, 0.0, 15.0))
	if not bool(m.get("overlay_mode")) or not m.visible:
		m.free()
		return "open_overlay haritayı görünür overlay yapmadı"
	m.call("_zoom_at", Vector2(360.0, 640.0), 2.4)
	if float(m.get("_zoom")) < 2.3:
		m.free()
		return "harita yakınlaştırma çalışmadı"
	m.call("reset_view")
	if not is_equal_approx(float(m.get("_zoom")), 1.0):
		m.free()
		return "reset_view yakınlaştırmayı 1.0'a döndürmedi"

	var places: Array = m.get("_places")
	var lib_place: Dictionary = {}
	for p: Dictionary in places:
		if str(p.get("id", "")) == "yeni_kutuphane":
			lib_place = p
	if lib_place.is_empty():
		m.free()
		return "yeni_kutuphane places listesinde yok"
	var got_wp: Array = []
	m.connect("waypoint_requested", func(xz: Vector2, _pl: Dictionary) -> void: got_wp.append(xz))
	m.call("select_place", lib_place)
	m.call("mark_waypoint")
	var was_hidden: bool = not m.visible
	var no_tp: bool = Services.pending_teleport == Vector2.INF
	var has_active_wp: bool = not Services.active_waypoint.is_empty()
	Services.clear_waypoint()
	m.free()
	if got_wp.size() != 1 or not was_hidden or not no_tp or not has_active_wp:
		return "mark_waypoint ışınlama yapmadan hedef işaretlemeliydi"
	return ""
