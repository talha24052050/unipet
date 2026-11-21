extends Node
## Girişleri (joystick, debug klavye) kamera yönüne göre dünya yönüne çevirip oyuncuya verir.

@export var player: CharacterBody3D
@export var joystick: Control
@export var camera: Camera3D


func _process(_delta: float) -> void:
	if player == null:
		return
	var input: Vector2 = joystick.get("value") if joystick != null else Vector2.ZERO
	if input == Vector2.ZERO and OS.is_debug_build():
		input = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var yaw: float = camera.global_rotation.y if camera != null else 0.0
	player.set("move_input", screen_to_world(input, yaw))


## Ekran yönü (x sağ, y aşağı) → kameranın baktığı yöne göre XZ düzleminde dünya yönü.
static func screen_to_world(input: Vector2, camera_yaw: float) -> Vector3:
	return Basis(Vector3.UP, camera_yaw) * Vector3(input.x, 0.0, input.y)
