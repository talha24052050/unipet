extends CharacterBody3D
## Yerel oyuncu. Hareket kaynağını (joystick, dokun-yürü, klavye) bilmez:
## PlayerController sadece `move_input`u (dünya uzayında, XZ düzleminde, uzunluk 0..1) yazar.

const PetVisual := preload("res://src/characters/pet_visual.gd")
const LocalProfile := preload("res://src/core/local_profile.gd")

## Boşsa Config.DEFAULT_PET_ID.
@export var character_id: StringName = &""

## İstenen hareket yönü ve şiddeti. Kontrolcüler her karede yazar.
var move_input: Vector3 = Vector3.ZERO
## Yarış geri sayımı gibi anlarda hareket kilidi.
var frozen: bool = false

const STEP_INTERVAL: float = 0.38
var _step_accum: float = 0.0

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var visual: PetVisual = $PetVisual
@onready var _collision: CollisionShape3D = $Collision


var _snap_to_navmesh: bool = false


## Navigasyon haritası hazırsa en yakın yürünebilir noktaya taşınır (hazır değilse sonraki kare dener).
func _try_snap_to_navmesh() -> void:
	var map: RID = get_world_3d().navigation_map
	# İlk senkrondan önce sorgu hata basıyor (telefonda log kirliliği): harita hazır olana kadar bekle
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return
	var probe: Vector3 = Vector3(global_position.x, TerrainHeight.active_height(global_position.x, global_position.z), global_position.z)
	var closest: Vector3 = NavigationServer3D.map_get_closest_point(map, probe)
	if closest == Vector3.ZERO and probe.length() > 1.0:
		return  # harita henüz hazır değil
	global_position = closest + Vector3.UP * 0.2
	velocity = Vector3.ZERO
	_snap_to_navmesh = false


## Aynı anda girenler üst üste doğmasın: doğuş noktası etrafında bu yarıçapta rastgele kayma (metre).
const SPAWN_SCATTER: float = 3.0


func _scatter() -> void:
	var a: float = randf() * TAU
	var r: float = sqrt(randf()) * SPAWN_SCATTER
	position += Vector3(cos(a) * r, 0.0, sin(a) * r)


## Sahne değişirken yeri sakla (ışınlanma hedefi verilmişse o öncelikli).
func _exit_tree() -> void:
	if is_inside_tree() and Services.pending_teleport == Vector2.INF:
		Services.return_position = global_position
		Services.return_yaw = rotation.y


func _ready() -> void:
	floor_snap_length = Config.PLAYER_FLOOR_SNAP
	floor_stop_on_slope = true
	floor_constant_speed = true
	floor_max_angle = deg_to_rad(45.0)
	# Bölgenin doğuş noktası (harita ekranından gelindiyse farklı bölge).
	if Services.pending_teleport != Vector2.INF:
		position = Vector3(Services.pending_teleport.x, position.y, Services.pending_teleport.y)
		Services.pending_teleport = Vector2.INF
		Services.return_position = Vector3.INF
		_snap_to_navmesh = true  # yer bina ortası olabilir: harita hazır olunca yürünebilir en yakın noktaya
		_scatter()
		position.y = TerrainHeight.active_height(position.x, position.z) + 1.5
	elif Services.return_position != Vector3.INF:
		# Haritadan / pet seçiminden dönüş: tam bıraktığı yer ve yön
		position = Services.return_position
		rotation.y = Services.return_yaw
		Services.return_position = Vector3.INF
	else:
		if Services.zones != null and Services.zones.has(Services.current_zone):
			var sp: Vector2 = Services.zones.get_zone(Services.current_zone)["spawn"]
			position = Vector3(sp.x, position.y, sp.y)
		_scatter()
		position.y = TerrainHeight.active_height(position.x, position.z) + 1.5
	if character_id != &"":
		set_character(character_id)
	else:
		apply_profile(LocalProfile.load_or_default())


## Kayıtlı seçimi (pet + aksesuarlar) uygular.
func apply_profile(profile: LocalProfile) -> void:
	set_character(profile.pet_id)
	for slot: StringName in profile.accessories:
		var acc: AccessoryDef = Services.accessories.get_def(profile.accessories[slot])
		if acc != null:
			visual.equip(acc)


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
	if _snap_to_navmesh:
		_try_snap_to_navmesh()
	velocity = compute_velocity(velocity, Vector3.ZERO if frozen else move_input, is_on_floor(), _gravity, delta)
	move_and_slide()

	var flat: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	visual.set_locomotion(flat.length())
	_update_footsteps(flat.length(), delta)
	if flat.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(flat.x, flat.z), Config.PLAYER_TURN_SPEED * delta)


func _update_footsteps(speed: float, delta: float) -> void:
	if speed < 0.1 or not is_on_floor():
		_step_accum = 0.0
		return
	var rate: float = clampf(speed / maxf(Config.PLAYER_WALK_SPEED, 0.1), 0.5, 2.0)
	_step_accum += delta * rate
	if _step_accum >= STEP_INTERVAL:
		_step_accum = fmod(_step_accum, STEP_INTERVAL)
		Sfx.play(&"step")


## Saf hesap (test edilebilir): yatayda hedef hıza ivmelen, dikeyde yerçekimi uygula.
static func compute_velocity(current: Vector3, input: Vector3, on_floor: bool, gravity: float, delta: float) -> Vector3:
	var dir: Vector3 = Vector3(input.x, 0.0, input.z).limit_length(1.0)
	var target: Vector3 = dir * Config.PLAYER_WALK_SPEED
	var horizontal: Vector3 = Vector3(current.x, 0.0, current.z).move_toward(target, Config.PLAYER_ACCELERATION * delta)
	var vy: float = 0.0 if on_floor else current.y - gravity * delta
	return Vector3(horizontal.x, vy, horizontal.z)

