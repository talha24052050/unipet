extends RefCounted

const Joystick := preload("res://src/player/virtual_joystick.gd")
const Controller := preload("res://src/player/player_controller.gd")
const R: float = 100.0


func test_value_deadzone() -> String:
	var v: Vector2 = Joystick.compute_value(Vector2.ZERO, Vector2(5, 0), R, 0.15)
	if v != Vector2.ZERO:
		return "ölü bölgede sıfır değil: %s" % v
	return ""


func test_value_clamped_full() -> String:
	var v: Vector2 = Joystick.compute_value(Vector2.ZERO, Vector2(500, 0), R, 0.15)
	if not v.is_equal_approx(Vector2(1, 0)):
		return "uçta 1 olmalı: %s" % v
	return ""


func test_value_half() -> String:
	var v: Vector2 = Joystick.compute_value(Vector2.ZERO, Vector2(0, -50), R, 0.0)
	if not v.is_equal_approx(Vector2(0, -0.5)):
		return "yarım itiş 0.5 olmalı: %s" % v
	return ""


func test_multitouch_ownership() -> String:
	var tree: SceneTree = Engine.get_main_loop()
	var j: Control = Joystick.new()
	tree.root.add_child(j)
	j.position = Vector2.ZERO
	j.size = Vector2(360, 500)
	var err: String = ""
	if j.handle_touch(0, true, Vector2(600, 100)):
		err = "bölge dışı dokunuş alındı"
	elif not j.handle_touch(1, true, Vector2(150, 300)):
		err = "bölge içi dokunuş alınmadı"
	elif j.handle_touch(2, true, Vector2(160, 310)):
		err = "ikinci parmak joystick'i çaldı"
	elif j.handle_drag(2, Vector2(400, 300)):
		err = "başka parmağın sürüklemesi işlendi"
	elif not j.handle_drag(1, Vector2(150 + R * 2, 300)) or j.value.x < 0.99:
		err = "sahip parmak sağa itti ama değer: %s" % j.value
	elif j.handle_touch(2, false, Vector2.ZERO):
		err = "başka parmağın bırakması joystick'i bıraktı"
	elif not j.handle_touch(1, false, Vector2.ZERO) or j.value != Vector2.ZERO:
		err = "bırakınca sıfırlanmadı"
	j.free()
	return err


func test_screen_to_world_camera_yaw() -> String:
	# Kamera varsayılan yönde (-Z'ye bakıyor): joystick yukarı → -Z.
	var fwd: Vector3 = Controller.screen_to_world(Vector2(0, -1), 0.0)
	if not fwd.is_equal_approx(Vector3(0, 0, -1)):
		return "ileri yanlış: %s" % fwd
	# Kamera 90° sola dönmüş (-X'e bakıyor): joystick yukarı → -X.
	var turned: Vector3 = Controller.screen_to_world(Vector2(0, -1), PI / 2.0)
	if not turned.is_equal_approx(Vector3(-1, 0, 0)):
		return "dönük kamerada ileri yanlış: %s" % turned
	return ""


func test_tap_vs_drag() -> String:
	if not Controller.is_tap(Vector2(100, 100), Vector2(105, 102), 0.1):
		return "kısa dokunuş tıklama sayılmadı"
	if Controller.is_tap(Vector2(100, 100), Vector2(200, 100), 0.1):
		return "sürükleme tıklama sayıldı"
	if Controller.is_tap(Vector2(100, 100), Vector2(100, 100), 1.0):
		return "uzun basma tıklama sayıldı"
	return ""


func test_direction_to_ignores_height() -> String:
	var d: Vector3 = Controller.direction_to(Vector3(0, 0, 0), Vector3(3, 5, 4))
	if not d.is_equal_approx(Vector3(0.6, 0, 0.8)):
		return "yön yanlış: %s" % d
	if Controller.direction_to(Vector3.ONE, Vector3.ONE) != Vector3.ZERO:
		return "hedefteyken sıfır olmalı"
	return ""
