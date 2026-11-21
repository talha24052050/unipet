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



func test_mock_quick_login_and_remembered_session() -> String:
	var Mock: GDScript = load("res://src/auth/mock_auth_service.gd")
	var path: String = ProjectSettings.globalize_path("user://mock_session.cfg")
	DirAccess.remove_absolute(path)
	var a: Node = Mock.new()
	var got: Array = []
	a.signed_in.connect(func(id: String, _t: String) -> void: got.append(id))
	a.call("quick_sign_in")
	var b: Node = Mock.new()
	b.signed_in.connect(func(id: String, _t: String) -> void: got.append(id))
	var restored: bool = await b.call("restore_session")
	b.call("sign_out")
	var c: Node = Mock.new()
	var after_logout: bool = await c.call("restore_session")
	for n: Node in [a, b, c]:
		n.free()
	if got.size() != 2 or got[0] != got[1] or not str(got[0]).begins_with("mock-dev-"):
		return "hızlı giriş/hatırlama yanlış: %s" % [got]
	if not restored or after_logout:
		return "oturum hatırlama/çıkış yanlış: %s %s" % [restored, after_logout]
	return ""
