extends CharacterBody3D
## Yerel oyuncu. Hareket kaynağını (joystick, dokun-yürü, klavye) bilmez:
## PlayerController sadece `move_input`u (dünya uzayında, XZ düzleminde, uzunluk 0..1) yazar.

## İstenen hareket yönü ve şiddeti. Kontrolcüler her karede yazar.
var move_input: Vector3 = Vector3.ZERO

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	floor_snap_length = Config.PLAYER_FLOOR_SNAP


func _physics_process(delta: float) -> void:
	velocity = compute_velocity(velocity, move_input, is_on_floor(), _gravity, delta)
	move_and_slide()

	var flat: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	if flat.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(flat.x, flat.z), Config.PLAYER_TURN_SPEED * delta)


## Saf hesap (test edilebilir): yatayda hedef hıza ivmelen, dikeyde yerçekimi uygula.
static func compute_velocity(current: Vector3, input: Vector3, on_floor: bool, gravity: float, delta: float) -> Vector3:
	var dir: Vector3 = Vector3(input.x, 0.0, input.z).limit_length(1.0)
	var target: Vector3 = dir * Config.PLAYER_WALK_SPEED
	var horizontal: Vector3 = Vector3(current.x, 0.0, current.z).move_toward(target, Config.PLAYER_ACCELERATION * delta)
	var vy: float = 0.0 if on_floor else current.y - gravity * delta
	return Vector3(horizontal.x, vy, horizontal.z)

