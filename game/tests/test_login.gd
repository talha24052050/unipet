extends RefCounted

const Login := preload("res://src/ui/login.gd")


func test_code_validation() -> String:
	if not Login.is_valid_code("123456"):
		return "geçerli kod reddedildi"
	for bad: String in ["12345", "1234567", "12a456", ""]:
		if Login.is_valid_code(bad):
			return "geçersiz kod kabul edildi: %s" % bad
	return ""


func test_next_scene_after_login() -> String:
	if Login.next_scene_after_login(false) != Login.PET_SELECT_SCENE:
		return "ilk girişte pet seçimine gitmeli"
	if Login.next_scene_after_login(true) != Login.GAME_SCENE:
		return "kayıtlı seçim varsa oyuna gitmeli"
	return ""


func test_login_scene_loads() -> String:
	var scene: PackedScene = load("res://scenes/ui/login.tscn")
	if scene == null:
		return "login.tscn yüklenemedi"
	var n: Node = scene.instantiate()
	var ok: bool = n.has_node("%EmailInput") and n.has_node("%CodeInput") and n.has_node("%StatusLabel")
	n.free()
	return "" if ok else "beklenen düğümler yok"
