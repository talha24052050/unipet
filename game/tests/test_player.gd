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
