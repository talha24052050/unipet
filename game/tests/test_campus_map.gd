extends RefCounted

const MapScript := preload("res://src/ui/campus_map.gd")


func _make() -> Control:
	var m: Control = (load("res://scenes/ui/campus_map.tscn") as PackedScene).instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(m)
	# Test runner SceneTree._initialize içinde çalışır; orada _ready çağrılmaz.
	if m.get("catalog") == null:
		m.call("_ready")
	# Tam ekran çapalı kontrole doğrudan size vermek Godot uyarısı basıyor: test için sol-üst çapaya al
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


func test_tap_selects_place_and_sets_teleport() -> String:
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
	m.free()
	if hit.get("id") != "yemekhane" or not miss.is_empty() or sel.get("id") != "yemekhane":
		return "dokunma yanlış: %s %s %s" % [hit.get("id"), miss, sel.get("id")]
	return ""


func test_historic_names() -> String:
	if not MapScript.is_historic("Yıldız Teknik Üniversitesi Davutpaşa Kışlası") or MapScript.is_historic("Yemekhane"):
		return "tarihi bina tanıma yanlış"
	return ""


func test_care_spots_loaded_and_drawn() -> String:
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

	# Bir play yerinin harita koordinatı ekran içinde
	var play_spots: Array = loaded.get("play", [])
	if play_spots.is_empty():
		m.free()
		return "play yerleri boş"
	var p0: Dictionary = play_spots[0]
	var w: Vector2 = Vector2(float(p0.get("x", 0.0)), float(p0.get("z", 0.0)))
	var map_pos: Vector2 = m.call("world_to_map", w)
	var screen_rect: Rect2 = Rect2(Vector2.ZERO, m.size)
	if not screen_rect.has_point(map_pos):
		m.free()
		return "play yeri (%s) ekran dışında: %s (ekran: %s)" % [p0.get("name", ""), map_pos, m.size]

	# Çizim hatasız (sahne 2 kare çizilir, hata sayacı 0)
	# 1. kare: onay paneli kapalıyken (açıklama lejantı çizilir)
	m.call("_fit")
	RenderingServer.force_draw(false)

	# 2. kare: bir yere dokunulup onay paneli açıldığında (lejant gizli)
	var places: Array = m.get("_places")
	if not places.is_empty():
		m.call("select_place", places[0])
	RenderingServer.force_draw(false)

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
