extends RefCounted

const MapScript := preload("res://src/ui/campus_map.gd")


func _make() -> Control:
	var m: Control = (load("res://scenes/ui/campus_map.tscn") as PackedScene).instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(m)
	# Test runner SceneTree._initialize içinde çalışır; orada _ready çağrılmaz.
	if m.get("catalog") == null:
		m.call("_ready")
	m.set_deferred("size", Vector2(720, 1280))
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
