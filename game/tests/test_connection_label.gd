extends RefCounted


func test_offline_shows_alone() -> String:
	var L: GDScript = load("res://src/ui/connection_label.gd")
	var l: Label = L.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(l)
	if l.text.is_empty():
		l.call("_ready")
	var t: String = l.text
	l.free()
	if Config.NETWORK_BACKEND == "offline" and t != "Tek başına":
		return "offline'da 'Tek başına' yazmalı: %s" % t
	return ""
