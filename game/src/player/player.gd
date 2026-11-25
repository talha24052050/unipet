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
var display_name: String = ""
var is_ytu_verified: bool = false
var role_tag: String = ""
var bio: String = ""

@onready var visual: PetVisual = $PetVisual
@onready var _collision: CollisionShape3D = $Collision
@onready var name_label: Label3D = get_node_or_null("NameLabel") as Label3D


var _snap_to_navmesh: bool = false
var _unstuck_timer: float = 0.0

static var _solid_buildings_loaded: bool = false
static var _solid_buildings: Array[PackedVector2Array] = []
static var _solid_building_boxes: Array[Rect2] = []
static var _walk_points: PackedVector2Array = PackedVector2Array()
const CAMPUS_GREYBOX_PATH: String = "res://data/zones/kampus_greybox.json"


static func _ensure_building_cache() -> void:
	if _solid_buildings_loaded:
		return
	_solid_buildings_loaded = true
	if not FileAccess.file_exists(CAMPUS_GREYBOX_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CAMPUS_GREYBOX_PATH))
	if not (parsed is Dictionary):
		return
	var d: Dictionary = parsed as Dictionary
	for b: Dictionary in d.get("buildings", []):
		if str(b.get("kind", "")) == "roof":
			continue
		var pts_raw: Array = b.get("points", [])
		if pts_raw.size() < 3:
			continue
		var poly: PackedVector2Array = PackedVector2Array()
		var box: Rect2 = Rect2()
		for i: int in pts_raw.size():
			var v: Vector2 = Vector2(float(pts_raw[i][0]), float(pts_raw[i][1]))
			poly.append(v)
			box = Rect2(v, Vector2.ZERO) if i == 0 else box.expand(v)
		_solid_buildings.append(poly)
		_solid_building_boxes.append(box)
	for p: Dictionary in d.get("paths", []):
		var ppts: Array = p.get("points", [])
		for i: int in ppts.size():
			var a: Vector2 = Vector2(float(ppts[i][0]), float(ppts[i][1]))
			_walk_points.append(a)
			if i + 1 < ppts.size():
				var bpt: Vector2 = Vector2(float(ppts[i + 1][0]), float(ppts[i + 1][1]))
				_walk_points.append((a + bpt) * 0.5)


## Verilen XZ noktası tüm katı binaların dışında ve duvarlardan en az `min_clearance` metre uzakta mı?
static func is_safe_outdoor_xz(pt: Vector2, min_clearance: float = 2.0) -> bool:
	_ensure_building_cache()
	for idx: int in _solid_buildings.size():
		var box: Rect2 = _solid_building_boxes[idx].grow(maxf(min_clearance, 0.2))
		if not box.has_point(pt):
			continue
		var poly: PackedVector2Array = _solid_buildings[idx]
		if Geometry2D.is_point_in_polygon(pt, poly):
			return false
		if min_clearance > 0.0:
			var n: int = poly.size()
			for i: int in n:
				var cp: Vector2 = Geometry2D.get_closest_point_to_segment(pt, poly[i], poly[(i + 1) % n])
				if pt.distance_to(cp) < min_clearance:
					return false
	return true


## Bina içine veya duvar dibine düşen ışınlanma/doğuş noktasını en yakın açık yürüyüş/meydan noktasına taşır.
static func resolve_safe_outdoor_xz(target: Vector2, min_clearance: float = 3.2) -> Vector2:
	_ensure_building_cache()
	if is_safe_outdoor_xz(target, min_clearance):
		return target

	var best: Vector2 = target
	var best_score: float = INF

	# 1) Yakındaki açık yürüyüş/araç yolu noktaları
	for wp: Vector2 in _walk_points:
		if absf(wp.x - target.x) > 85.0 or absf(wp.y - target.y) > 85.0:
			continue
		var d: float = wp.distance_to(target)
		if d < best_score and is_safe_outdoor_xz(wp, min_clearance):
			best_score = d
			best = wp

	# 2) Yakın bina kenarlarının dışa bakan normali yönünde açık noktalar
	for idx: int in _solid_buildings.size():
		if not _solid_building_boxes[idx].grow(80.0).has_point(target):
			continue
		var poly: PackedVector2Array = _solid_buildings[idx]
		var n: int = poly.size()
		for i: int in n:
			var a: Vector2 = poly[i]
			var b: Vector2 = poly[(i + 1) % n]
			var edge: Vector2 = b - a
			var el: float = edge.length()
			if el < 0.5:
				continue
			var cp: Vector2 = Geometry2D.get_closest_point_to_segment(target, a, b)
			var nrm: Vector2 = Vector2(-edge.y / el, edge.x / el)
			for sgn: float in [1.0, -1.0]:
				var cand: Vector2 = cp + nrm * sgn * (min_clearance + 1.2)
				var sc: float = cand.distance_to(target)
				if sc < best_score and is_safe_outdoor_xz(cand, min_clearance):
					best_score = sc
					best = cand

	if best_score < INF:
		return best

	# 3) Radyal spiral yedek arama
	for r_step: int in range(4, 92, 4):
		var rad: float = float(r_step)
		for k: int in 20:
			var ang: float = TAU * float(k) / 20.0
			var cand: Vector2 = target + Vector2(cos(ang), sin(ang)) * rad
			if is_safe_outdoor_xz(cand, min_clearance):
				return cand
	return target


## Navigasyon haritası hazırsa en yakın yürünebilir AÇIK HAVA noktasına taşınır (bina içi navmesh adalarını reddeder!).
func _try_snap_to_navmesh() -> void:
	var map: RID = get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return
	var probe: Vector3 = Vector3(global_position.x, TerrainHeight.active_height(global_position.x, global_position.z), global_position.z)
	var closest: Vector3 = NavigationServer3D.map_get_closest_point(map, probe)
	if closest == Vector3.ZERO and probe.length() > 1.0:
		return  # harita henüz hazır değil
	var closest_xz: Vector2 = Vector2(closest.x, closest.z)
	# Bina içi kapalı navmesh adalarına çekilmeyi kesinlikle engelle!
	if is_safe_outdoor_xz(closest_xz, 1.4) and closest_xz.distance_to(Vector2(probe.x, probe.z)) <= 12.0:
		global_position = closest + Vector3.UP * 0.2
	else:
		var safe_xz: Vector2 = resolve_safe_outdoor_xz(Vector2(global_position.x, global_position.z), 3.0)
		global_position = Vector3(safe_xz.x, TerrainHeight.active_height(safe_xz.x, safe_xz.y) + 0.25, safe_xz.y)
	velocity = Vector3.ZERO
	_snap_to_navmesh = false


## Aynı anda girenler üst üste doğmasın: yalnızca bina dışına taşmayan güvenli rastgele kayma.
const SPAWN_SCATTER: float = 2.4


func _scatter() -> void:
	var base_xz: Vector2 = Vector2(position.x, position.z)
	for _attempt: int in 10:
		var a: float = randf() * TAU
		var r: float = sqrt(randf()) * SPAWN_SCATTER
		var cand: Vector2 = base_xz + Vector2(cos(a) * r, sin(a) * r)
		if is_safe_outdoor_xz(cand, 2.2):
			position.x = cand.x
			position.z = cand.y
			return


## Sahneyi yeniden yüklemeden oyuncuyu güvenli açık hava noktasına anında ışınlar (0 ms).
func teleport_to(target_xz: Vector2) -> void:
	var safe_xz: Vector2 = resolve_safe_outdoor_xz(target_xz, 3.2)
	position = Vector3(safe_xz.x, TerrainHeight.active_height(safe_xz.x, safe_xz.y) + 0.35, safe_xz.y)
	_scatter()
	position.y = TerrainHeight.active_height(position.x, position.z) + 0.35
	velocity = Vector3.ZERO
	move_input = Vector3.ZERO
	_snap_to_navmesh = true


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
		var tp: Vector2 = Services.pending_teleport
		Services.pending_teleport = Vector2.INF
		Services.return_position = Vector3.INF
		teleport_to(tp)
	elif Services.return_position != Vector3.INF:
		# Haritadan / pet seçiminden dönüş: tam bıraktığı yer ve yön (çökük avlu vb. özel kotları koru)
		var orig_xz: Vector2 = Vector2(Services.return_position.x, Services.return_position.z)
		var ret_xz: Vector2 = resolve_safe_outdoor_xz(orig_xz, 1.6)
		var ret_y: float = Services.return_position.y if ret_xz.distance_to(orig_xz) < 0.5 else (TerrainHeight.active_height(ret_xz.x, ret_xz.y) + 0.35)
		position = Vector3(ret_xz.x, ret_y, ret_xz.y)
		rotation.y = Services.return_yaw
		Services.return_position = Vector3.INF
	else:
		var sp_xz: Vector2 = Vector2(position.x, position.z)
		if Services.zones != null and Services.zones.has(Services.current_zone):
			sp_xz = Services.zones.get_zone(Services.current_zone)["spawn"]
		teleport_to(sp_xz)
	if character_id != &"":
		set_character(character_id)
	else:
		apply_profile(LocalProfile.load_or_default())


## Kayıtlı seçimi (pet + aksesuarlar + nick) uygular; çıkarılmış slotları da temizler.
func apply_profile(profile: LocalProfile) -> void:
	is_ytu_verified = profile.is_ytu_verified
	role_tag = profile.role_tag
	bio = profile.bio
	set_character(profile.pet_id)
	set_display_name(profile.display_name)
	for slot: StringName in CharacterDef.ACCESSORY_SLOTS:
		var acc_id: StringName = profile.accessories.get(slot, &"")
		if acc_id != &"":
			var acc: AccessoryDef = Services.accessories.get_def(acc_id)
			if acc != null:
				visual.equip(acc)
			else:
				visual.unequip(slot)
		else:
			visual.unequip(slot)
	_update_name_label()


func set_display_name(raw_name: String) -> void:
	display_name = raw_name.strip_edges()
	_update_name_label()


func _update_name_label() -> void:
	if name_label == null:
		name_label = get_node_or_null("NameLabel") as Label3D
	if name_label == null:
		return
	var base_nm: String = display_name if not display_name.is_empty() else "Oyuncu"
	name_label.text = ("✓ %s" % base_nm) if is_ytu_verified else base_nm
	name_label.modulate = Color(0.84, 0.95, 1.0, 1.0) if is_ytu_verified else Color(0.96, 0.98, 1.0, 1.0)
	if visual != null and visual.has_method("footprint"):
		name_label.position.y = visual.footprint().y + 0.16


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
	_update_name_label()


func _fit_collision(size: Vector2) -> void:
	var shape: CapsuleShape3D = CapsuleShape3D.new()
	shape.radius = size.x
	shape.height = maxf(size.y, size.x * 2.0)
	_collision.shape = shape
	_collision.position = Vector3(0.0, shape.height * 0.5, 0.0)


func _physics_process(delta: float) -> void:
	if _snap_to_navmesh:
		_try_snap_to_navmesh()
	# Güvenlik ağı: oyuncu herhangi bir nedenle kapalı bir katı binanın içinde sıkışırsa dışarı çıkar
	_unstuck_timer += delta
	if _unstuck_timer >= 0.65 and is_inside_tree():
		_unstuck_timer = 0.0
		var cur_xz: Vector2 = Vector2(global_position.x, global_position.z)
		if not is_safe_outdoor_xz(cur_xz, 0.0) and not _is_near_gate_path(cur_xz, 2.8):
			teleport_to(cur_xz)
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


static func _is_near_gate_path(pt: Vector2, tol: float) -> bool:
	for wp: Vector2 in _walk_points:
		if absf(wp.x - pt.x) <= tol and absf(wp.y - pt.y) <= tol and wp.distance_to(pt) <= tol:
			return true
	return false

