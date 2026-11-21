extends Node3D
## Üçüncü şahıs takip kamerası.
## - Tek parmak sürükleme (joystick dışında): döndür (yaw) + eğ (pitch)
## - İki parmak sıkıştırma: yakınlaştır/uzaklaştır
## - Masaüstü: fare tekerleği yakınlaştırır
## SpringArm3D sayesinde kamera duvarın içine girmez.
## Joystick kendi dokunuşlarını tükettiği için buraya gelmez.

@export var target: Node3D

@onready var _arm: SpringArm3D = $SpringArm3D
@onready var _camera: Camera3D = $SpringArm3D/Camera3D

var yaw: float = 0.0
var pitch: float = deg_to_rad(Config.CAMERA_PITCH_DEFAULT_DEG)
var distance: float = Config.CAMERA_DISTANCE_DEFAULT

## Aktif (joystick'e ait olmayan) dokunuşlar: index → ekran konumu.
var _touches: Dictionary = {}


func _ready() -> void:
	top_level = true
	if target != null:
		global_position = target.global_position + Vector3.UP * Config.CAMERA_TARGET_HEIGHT
		if target is CollisionObject3D:
			_arm.add_excluded_object((target as CollisionObject3D).get_rid())
	_apply()


func get_camera() -> Camera3D:
	return _camera


func _process(delta: float) -> void:
	if target == null:
		return
	var goal: Vector3 = target.global_position + Vector3.UP * Config.CAMERA_TARGET_HEIGHT
	var t: float = 1.0 - exp(-Config.CAMERA_FOLLOW_SHARPNESS * delta)
	global_position = global_position.lerp(goal, t)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t: InputEventScreenTouch = event
		if t.pressed:
			_touches[t.index] = t.position
		else:
			_touches.erase(t.index)
	elif event is InputEventScreenDrag:
		var d: InputEventScreenDrag = event
		if not _touches.has(d.index):
			return
		if _touches.size() == 1:
			rotate_by(d.relative)
		elif _touches.size() == 2:
			var other: Vector2 = _other_touch(d.index)
			var before: float = (_touches[d.index] as Vector2).distance_to(other)
			var after: float = d.position.distance_to(other)
			distance = zoomed_distance(distance, before, after)
			_apply()
		_touches[d.index] = d.position
	elif event is InputEventMouseButton:
		var m: InputEventMouseButton = event
		if m.pressed and m.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = clampf(distance - Config.CAMERA_WHEEL_STEP, Config.CAMERA_DISTANCE_MIN, Config.CAMERA_DISTANCE_MAX)
			_apply()
		elif m.pressed and m.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = clampf(distance + Config.CAMERA_WHEEL_STEP, Config.CAMERA_DISTANCE_MIN, Config.CAMERA_DISTANCE_MAX)
			_apply()


## Ekran piksel kayması kadar döndürür.
func rotate_by(relative: Vector2) -> void:
	yaw -= relative.x * Config.CAMERA_ROTATE_SENSITIVITY
	pitch = clamp_pitch(pitch - relative.y * Config.CAMERA_ROTATE_SENSITIVITY)
	_apply()


func _apply() -> void:
	rotation = Vector3(0.0, yaw, 0.0)
	if _arm != null:
		_arm.rotation = Vector3(pitch, 0.0, 0.0)
		_arm.spring_length = distance


func _other_touch(index: int) -> Vector2:
	for k: int in _touches:
		if k != index:
			return _touches[k]
	return Vector2.ZERO


static func clamp_pitch(p: float) -> float:
	return clampf(p, deg_to_rad(Config.CAMERA_PITCH_MIN_DEG), deg_to_rad(Config.CAMERA_PITCH_MAX_DEG))


## Parmaklar açılınca yakınlaş, kapanınca uzaklaş; sınırlar içinde.
static func zoomed_distance(current: float, finger_dist_before: float, finger_dist_after: float) -> float:
	if finger_dist_after < 1.0 or finger_dist_before < 1.0:
		return current
	return clampf(current * finger_dist_before / finger_dist_after, Config.CAMERA_DISTANCE_MIN, Config.CAMERA_DISTANCE_MAX)
