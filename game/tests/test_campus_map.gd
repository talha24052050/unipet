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
	var cat: RefCounted = m.get("catalog")
	for id: String in cat.ids():
		var p: Vector2 = m.call("world_to_map", cat.get_zone(id)["center"])
		if not Rect2(Vector2.ZERO, m.size).has_point(p):
			err = "%s işareti ekran dışında: %s" % [id, p]
	m.free()
	return err


func test_tap_selects_zone() -> String:
	var m: Control = _make()
	var cat: RefCounted = m.get("catalog")
	var p: Vector2 = m.call("world_to_map", cat.get_zone("insaat")["center"])
	var hit: String = m.call("zone_at", p + Vector2(10, 5))
	var miss: String = m.call("zone_at", Vector2(5, 5))
	m.call("select_zone", "insaat")
	var sel: String = m.get("selected_zone")
	m.free()
	if hit != "insaat" or miss != "" or sel != "insaat":
		return "dokunma yanlış: %s %s %s" % [hit, miss, sel]
	return ""


func test_historic_names() -> String:
	if not MapScript.is_historic("Yıldız Teknik Üniversitesi Davutpaşa Kışlası") or MapScript.is_historic("Yemekhane"):
		return "tarihi bina tanıma yanlış"
	return ""
