extends Control
## Sol alttaki kayan (floating) sanal joystick.
## Bölge içinde ilk dokunan parmağı sahiplenir; diğer parmaklar (kamera, dokun-yürü) etkilenmez.
## Çıktı: `value` (x sağ, y aşağı; uzunluk 0..1).

signal touch_started
signal touch_ended

var value: Vector2 = Vector2.ZERO

var _touch_index: int = -1
var _center: Vector2 = Vector2.ZERO
var _knob: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.0
	anchor_top = 1.0 - Config.JOYSTICK_ZONE_HEIGHT
	anchor_right = Config.JOYSTICK_ZONE_WIDTH
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	_reset()
	resized.connect(_reset)


## Joystick _input'ta (arayüzden önce) çalışır: açık bir panelin (Ayarlar, sohbet) üstündeki dokunuşu almasın.
## Panel kökleri bu gruba katılır.
const BLOCKER_GROUP: StringName = &"joystick_blocker"


func _blocked_at(pos: Vector2) -> bool:
	if not is_inside_tree():
		return false
	for n: Node in get_tree().get_nodes_in_group(BLOCKER_GROUP):
		var c: Control = n as Control
		if c != null and c.is_visible_in_tree() and c.get_global_rect().has_point(pos):
			return true
	return false


func is_active() -> bool:
	return _touch_index != -1


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t: InputEventScreenTouch = event
		if handle_touch(t.index, t.pressed, t.position):
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var d: InputEventScreenDrag = event
		if handle_drag(d.index, d.position):
			get_viewport().set_input_as_handled()


## Dokunuş olayını işler; joystick'e aitse true döner. `pos` ekran koordinatı.
func handle_touch(index: int, pressed: bool, pos: Vector2) -> bool:
	if pressed:
		if _touch_index != -1 or not get_global_rect().has_point(pos) or _blocked_at(pos):
			return false
		_touch_index = index
		_center = pos - global_position
		_knob = _center
		value = Vector2.ZERO
		queue_redraw()
		touch_started.emit()
		return true
	if index != _touch_index:
		return false
	_reset()
	touch_ended.emit()
	return true


func handle_drag(index: int, pos: Vector2) -> bool:
	if index != _touch_index:
		return false
	var local: Vector2 = pos - global_position
	_knob = _center + (local - _center).limit_length(Config.JOYSTICK_RADIUS)
	value = compute_value(_center, local, Config.JOYSTICK_RADIUS, Config.JOYSTICK_DEADZONE)
	queue_redraw()
	return true


## Saf hesap: merkezden uzaklığı 0..1'e çevirir, ölü bölgeyi atıp kalanı yeniden ölçekler.
static func compute_value(center: Vector2, touch: Vector2, radius: float, deadzone: float) -> Vector2:
	var v: Vector2 = ((touch - center) / radius).limit_length(1.0)
	var length: float = v.length()
	if length < deadzone:
		return Vector2.ZERO
	return v / length * ((length - deadzone) / (1.0 - deadzone))


func _reset() -> void:
	_touch_index = -1
	value = Vector2.ZERO
	var margin: float = Config.JOYSTICK_RADIUS * 0.5
	_center = Vector2(margin + Config.JOYSTICK_RADIUS, size.y - margin - Config.JOYSTICK_RADIUS)
	_knob = _center
	queue_redraw()


func _draw() -> void:
	var alpha: float = 0.5 if is_active() else 0.25
	draw_circle(_center, Config.JOYSTICK_RADIUS, Color(1, 1, 1, alpha * 0.5))
	draw_arc(_center, Config.JOYSTICK_RADIUS, 0.0, TAU, 48, Color(1, 1, 1, alpha), 3.0, true)
	draw_circle(_knob, Config.JOYSTICK_RADIUS * 0.45, Color(1, 1, 1, alpha + 0.2))
