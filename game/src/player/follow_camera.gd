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
var _was_riding_bus: bool = false
var _ride_yaw_offset: float = 0.0
const BUS_MIN_CAMERA_DISTANCE: float = 10.8


static func _get_pos(n: Node3D) -> Vector3:
	return n.global_position if n.is_inside_tree() else n.position


static func _set_pos(n: Node3D, p: Vector3) -> void:
	if n.is_inside_tree():
		n.global_position = p
	else:
		n.position = p


func _ready() -> void:
	top_level = true
	if target != null:
		_set_pos(self, _get_pos(target) + Vector3.UP * Config.CAMERA_TARGET_HEIGHT)
		if target is CollisionObject3D:
			_arm.add_excluded_object((target as CollisionObject3D).get_rid())
	_apply()


func exclude_collision_rid(rid: RID) -> void:
	if _arm != null and rid.is_valid():
		_arm.add_excluded_object(rid)


func get_camera() -> Camera3D:
	return _camera


## Işınlanma veya ekran dönüşü sonrası kamerayı gecikmesiz oyuncunun üstüne oturtur.
func snap_to_target() -> void:
	_touches.clear()
	if target != null:
		if bool(target.get("riding_bus")):
			_set_pos(self, target.get("bus_camera_focus"))
		else:
			_set_pos(self, _get_pos(target) + Vector3.UP * Config.CAMERA_TARGET_HEIGHT)
	_apply()


func _process(delta: float) -> void:
	if target == null:
		return
	var riding: bool = bool(target.get("riding_bus"))
	if riding:
		var bus_yaw: float = float(target.get("bus_camera_yaw"))
		if not _was_riding_bus:
			_was_riding_bus = true
			_ride_yaw_offset = deg_to_rad(-16.0)
			yaw = wrapf(bus_yaw + PI + _ride_yaw_offset, -PI, PI)
			pitch = clampf(pitch, deg_to_rad(-34.0), deg_to_rad(-22.0))
		elif _touches.is_empty():
			yaw = lerp_angle(yaw, bus_yaw + PI + _ride_yaw_offset, minf(1.0, delta * 5.5))
		# Otobüs 14.2 m/s hızla giderken lerp gecikmesi kamerayı tavanın içine sokup titretir;
		# otobüs üstü odak noktasına 1:1 kilitlenerek sıfır kayma sağlanır.
		_set_pos(self, target.get("bus_camera_focus"))
		_apply()
		return

	if _was_riding_bus:
		_was_riding_bus = false
		_ride_yaw_offset = 0.0
		snap_to_target()
		return

	var goal: Vector3 = _get_pos(target) + Vector3.UP * Config.CAMERA_TARGET_HEIGHT
	var t: float = 1.0 - exp(-Config.CAMERA_FOLLOW_SHARPNESS * delta)
	_set_pos(self, _get_pos(self).lerp(goal, t))


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
	if target != null and bool(target.get("riding_bus")):
		_ride_yaw_offset = wrapf(yaw - (float(target.get("bus_camera_yaw")) + PI), -PI, PI)
	_apply()


func _apply() -> void:
	rotation = Vector3(0.0, yaw, 0.0)
	if _arm != null:
		_arm.rotation = Vector3(pitch, 0.0, 0.0)
		var riding: bool = target != null and bool(target.get("riding_bus"))
		_arm.spring_length = maxf(distance, BUS_MIN_CAMERA_DISTANCE) if riding else distance


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
