extends CharacterBody3D
## Yerel oyuncu. Hareket kaynağını (joystick, dokun-yürü, klavye) bilmez:
## PlayerController sadece `move_input`u (dünya uzayında, XZ düzleminde, uzunluk 0..1) yazar.

const PetVisual := preload("res://src/characters/pet_visual.gd")

## Boşsa Config.DEFAULT_PET_ID.
@export var character_id: StringName = &""

## İstenen hareket yönü ve şiddeti. Kontrolcüler her karede yazar.
var move_input: Vector3 = Vector3.ZERO

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var visual: PetVisual = $PetVisual
@onready var _collision: CollisionShape3D = $Collision


func _ready() -> void:
	floor_snap_length = Config.PLAYER_FLOOR_SNAP
	set_character(character_id if character_id != &"" else Config.DEFAULT_PET_ID)


## Peti değiştirir (seçim ekranı, ağdan gelen profil). Bilinmeyen id → ilk seçilebilir pet.
func set_character(id: StringName) -> void:
	var def: CharacterDef = Services.characters.get_def(id)
	if def == null:
		var all: Array[CharacterDef] = Services.characters.selectable()
		if all.is_empty():
			push_error("Hiç pet tanımı yok (data/characters)")
			return
		push_warning("Pet bulunamadı: %s, %s kullanılıyor" % [id, all[0].id])
		def = all[0]
	character_id = def.id
	visual.set_character(def)
	_fit_collision(visual.footprint())


func _fit_collision(size: Vector2) -> void:
	var shape: CapsuleShape3D = CapsuleShape3D.new()
	shape.radius = size.x
	shape.height = maxf(size.y, size.x * 2.0)
	_collision.shape = shape
	_collision.position = Vector3(0.0, shape.height * 0.5, 0.0)


func _physics_process(delta: float) -> void:
	velocity = compute_velocity(velocity, move_input, is_on_floor(), _gravity, delta)
	move_and_slide()

	var flat: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	visual.set_locomotion(flat.length())
	if flat.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(flat.x, flat.z), Config.PLAYER_TURN_SPEED * delta)


## Saf hesap (test edilebilir): yatayda hedef hıza ivmelen, dikeyde yerçekimi uygula.
static func compute_velocity(current: Vector3, input: Vector3, on_floor: bool, gravity: float, delta: float) -> Vector3:
	var dir: Vector3 = Vector3(input.x, 0.0, input.z).limit_length(1.0)
	var target: Vector3 = dir * Config.PLAYER_WALK_SPEED
	var horizontal: Vector3 = Vector3(current.x, 0.0, current.z).move_toward(target, Config.PLAYER_ACCELERATION * delta)
	var vy: float = 0.0 if on_floor else current.y - gravity * delta
	return Vector3(horizontal.x, vy, horizontal.z)

