extends Node
## Girişleri oyuncu hareketine çevirir:
## - joystick / debug klavye: kamera yönüne göre dünya yönü
## - dokun-yürü: zemine kısa dokunuş → NavigationAgent3D ile hedefe yürü
## Joystick'e dokunmak veya klavye dokun-yürüyü iptal eder.

signal destination_set(point: Vector3)
signal destination_cleared

@export var player: CharacterBody3D
@export var joystick: Control
@export var camera: Camera3D
@export var agent: NavigationAgent3D
## Hedef işareti (isteğe bağlı).
@export var marker: Node3D
## Pete dokunma (isteğe bağlı): dokunuş bir pete denk gelirse yürüme yerine etkileşim.
@export var interaction: Node

var _navigating: bool = false
var _touch_index: int = -1
var _touch_start_pos: Vector2 = Vector2.ZERO
var _touch_start_time: float = 0.0
var _tap_cancelled: bool = false


func _ready() -> void:
	if joystick != null and joystick.has_signal("touch_started"):
		joystick.connect("touch_started", clear_destination)
	if marker != null:
		marker.visible = false


func _process(_delta: float) -> void:
	if player == null:
		return
	var input: Vector2 = joystick.get("value") if joystick != null else Vector2.ZERO
	if input == Vector2.ZERO and OS.is_debug_build():
		input = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	if input != Vector2.ZERO:
		clear_destination()
		var yaw: float = camera.global_rotation.y if camera != null else 0.0
		player.set("move_input", screen_to_world(input, yaw))
	elif _navigating:
		player.set("move_input", _follow_path())
	else:
		player.set("move_input", Vector3.ZERO)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventScreenTouch:
		return
	var t: InputEventScreenTouch = event
	var now: float = Time.get_ticks_msec() / 1000.0
	if t.pressed:
		if _touch_index == -1:
			_touch_index = t.index
			_touch_start_pos = t.position
			_touch_start_time = now
			_tap_cancelled = false
		else:
			# İkinci parmak = kamera hareketi (sıkıştırma); bu dokunuş artık tıklama değil.
			_tap_cancelled = true
	elif t.index == _touch_index:
		_touch_index = -1
		if not _tap_cancelled and is_tap(_touch_start_pos, t.position, now - _touch_start_time):
			if interaction != null and bool(interaction.call("try_tap", t.position, camera)):
				return
			_try_walk_to_screen_point(t.position)


func set_destination(point: Vector3) -> void:
	if agent == null:
		return
	agent.target_position = point
	_navigating = true
	if marker != null:
		marker.global_position = point
		marker.visible = true
	destination_set.emit(point)


func clear_destination() -> void:
	if not _navigating:
		return
	_navigating = false
	if marker != null:
		marker.visible = false
	destination_cleared.emit()


func is_navigating() -> bool:
	return _navigating


func _follow_path() -> Vector3:
	if agent.is_navigation_finished():
		clear_destination()
		return Vector3.ZERO
	return direction_to(player.global_position, agent.get_next_path_position())


func _try_walk_to_screen_point(screen_pos: Vector2) -> void:
	if camera == null:
		return
	var from: Vector3 = camera.project_ray_origin(screen_pos)
	var to: Vector3 = from + camera.project_ray_normal(screen_pos) * Config.TAP_RAY_LENGTH
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [player.get_rid()]
	var hit: Dictionary = camera.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		set_destination(hit["position"])


## Kısa ve az hareketli dokunuş mu? (Uzun/sürüklenen dokunuş kamera içindir.)
static func is_tap(start: Vector2, end: Vector2, duration: float) -> bool:
	return duration <= Config.TAP_MAX_DURATION_S and start.distance_to(end) <= Config.TAP_MAX_MOVE_PX


## XZ düzleminde hedefe doğru birim yön (yükseklik farkı yok sayılır).
static func direction_to(from: Vector3, to: Vector3) -> Vector3:
	var d: Vector3 = Vector3(to.x - from.x, 0.0, to.z - from.z)
	return d.normalized() if d.length() > 0.01 else Vector3.ZERO


## Ekran yönü (x sağ, y aşağı) → kameranın baktığı yöne göre XZ düzleminde dünya yönü.
static func screen_to_world(input: Vector2, camera_yaw: float) -> Vector3:
	return Basis(Vector3.UP, camera_yaw) * Vector3(input.x, 0.0, input.y)
