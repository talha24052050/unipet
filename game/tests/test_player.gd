extends RefCounted

const Player := preload("res://src/player/player.gd")
const DT: float = 1.0 / 60.0


func test_gravity_when_airborne() -> String:
	var v: Vector3 = Player.compute_velocity(Vector3.ZERO, Vector3.ZERO, false, 9.8, DT)
	if not v.y < 0.0:
		return "havadayken düşmüyor: %s" % v
	return ""


func test_no_fall_on_floor() -> String:
	var v: Vector3 = Player.compute_velocity(Vector3(0, -5, 0), Vector3.ZERO, true, 9.8, DT)
	if v.y != 0.0:
		return "yerdeyken dikey hız sıfırlanmadı: %s" % v
	return ""


func test_reaches_walk_speed() -> String:
	var v: Vector3 = Vector3.ZERO
	for i: int in 120:
		v = Player.compute_velocity(v, Vector3(1, 0, 0), true, 9.8, DT)
	if not is_equal_approx(v.x, Config.PLAYER_WALK_SPEED):
		return "yürüme hızına ulaşmadı: %s" % v
	return ""


func test_diagonal_not_faster() -> String:
	var v: Vector3 = Vector3.ZERO
	for i: int in 120:
		v = Player.compute_velocity(v, Vector3(1, 0, 1), true, 9.8, DT)
	if Vector2(v.x, v.z).length() > Config.PLAYER_WALK_SPEED + 0.001:
		return "çapraz hareket daha hızlı: %s" % v
	return ""


func test_stops_without_input() -> String:
	var v: Vector3 = Vector3(Config.PLAYER_WALK_SPEED, 0, 0)
	for i: int in 60:
		v = Player.compute_velocity(v, Vector3.ZERO, true, 9.8, DT)
	if v.length() > 0.001:
		return "giriş yokken durmadı: %s" % v
	return ""


func test_resolve_safe_outdoor_evacuates_building_interiors() -> String:
	# Yemekhane (-103.5, -95.2), EEF (47.1, -254.7), Kongre Merkezi (549.2, 305.7), Yeni Kütüphane (-77.2, -182.7)
	# hepsi katı binaların tam ortasıdır; resolve_safe_outdoor_xz hepsini bina dışına (≥3.0 m açıklıkla) çıkarmalı!
	var inside_targets: Array[Vector2] = [
		Vector2(-103.5, -95.2),
		Vector2(47.1, -254.7),
		Vector2(549.2, 305.7),
		Vector2(-77.2, -182.7),
		Vector2(-127.8, -68.0),
	]
	for t: Vector2 in inside_targets:
		if Player.is_safe_outdoor_xz(t, 0.0):
			return "Test noktası (%s) bina içinde olmalıydı" % str(t)
		var out_pt: Vector2 = Player.resolve_safe_outdoor_xz(t, 3.0)
		if not Player.is_safe_outdoor_xz(out_pt, 2.8):
			return "resolve_safe_outdoor_xz (%s -> %s) güvenli bina dışı nokta üretemedi!" % [str(t), str(out_pt)]
	return ""


func test_pet_select_overlay_returns_without_scene_reload() -> String:
	var PetSelectScene := preload("res://scenes/ui/pet_select.tscn")
	var inst: Control = PetSelectScene.instantiate() as Control
	(Engine.get_main_loop() as SceneTree).root.add_child(inst)
	if not inst.is_node_ready():
		inst.call("_ready")
	inst.call("set_overlay_mode", true)
	inst.call("set_active", true)
	var signals: Array = []
	inst.connect("closed", func(saved: bool) -> void: signals.append(saved))
	inst.call("_cancel_overlay")
	var ok_cancel: bool = (signals == [false] and not inst.visible)
	inst.call("set_active", true)
	inst.call("start_game")
	var ok_save: bool = (signals == [false, true] and not inst.visible)
	inst.free()
	if not ok_cancel or not ok_save:
		return "PetSelect overlay_mode anlık dönüş sinyali hatalı: %s" % str(signals)
	return ""
