extends Node3D
## Davutpaşa kedisi: low-poly, koddan kurulan gövde; evinin (home) çevresinde gezer, oturur, uyur.
## Oyuncu yakında durursa yanına gelip etrafında dolanır. Dokununca miyavlar (PetInteraction → pet()).
## Ağda eşitlenmez: her oyuncu kendi kedilerini görür (dekor + etkileşim).

const WALK_SPEED: float = 1.1
const APPROACH_DIST: float = 6.0
const RUB_DIST: float = 1.1
const COLORS: Array = [
	[Color(0.93, 0.55, 0.2), Color(0.98, 0.9, 0.8)],   # sarman
	[Color(0.12, 0.12, 0.14), Color(0.95, 0.95, 0.95)], # siyah-beyaz
	[Color(0.55, 0.55, 0.58), Color(0.85, 0.85, 0.85)], # tekir gri
	[Color(0.96, 0.95, 0.92), Color(0.93, 0.6, 0.3)],   # beyaz, turuncu benek
	[Color(0.35, 0.25, 0.18), Color(0.8, 0.7, 0.55)],   # kahve
]

var home: Vector3 = Vector3.ZERO
var roam: float = 10.0
var player: Node3D
var state: StringName = &"sit"  # sit | walk | sleep | rub
var visual: Node3D  # PetInteraction kalpleri için yükseklik (footprint)

var _timer: float = 2.0
var _path: PackedVector3Array = PackedVector3Array()
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _t: float = 0.0
var _body: Node3D
var _tail: Node3D
var _head: Node3D
var _rub_angle: float = 0.0
var _meow_cd: float = 0.0


func setup(seed_value: int, at: Vector3, radius: float) -> void:
	_rng.seed = seed_value
	home = at
	roam = radius
	_build(COLORS[_rng.randi() % COLORS.size()])
	_timer = _rng.randf_range(0.5, 4.0)
	rotation.y = _rng.randf() * TAU


## Parçalar vertex rengiyle 3 ağa birleştirilir (gövde, baş, kuyruk): kedi başına 3 çizim (mobil).
func _build(cols: Array) -> void:
	var main: Color = cols[0]
	var acc: Color = cols[1]
	var dark: Color = Color(0.08, 0.08, 0.1)
	var pink: Color = Color(0.95, 0.55, 0.6)
	_body = Node3D.new()
	add_child(_body)
	visual = _body
	var body: Array = [
		[_capsule(0.13, 0.5), Vector3(0, 0.2, 0), Vector3(PI / 2, 0, 0), Vector3.ONE, main],
		[_sphere(0.1), Vector3(0, 0.17, 0.13), Vector3.ZERO, Vector3(1, 0.8, 1), acc]]
	for x: float in [-0.07, 0.07]:
		for z: float in [-0.14, 0.14]:
			body.append([_capsule(0.035, 0.18), Vector3(x, 0.08, z), Vector3.ZERO, Vector3.ONE, acc if z > 0 else main])
	_mesh_node(_body, body)
	_head = Node3D.new()
	_head.position = Vector3(0, 0.33, 0.24)
	_body.add_child(_head)
	var head: Array = [
		[_sphere(0.11), Vector3.ZERO, Vector3.ZERO, Vector3(1.1, 0.95, 1), main],
		[_sphere(0.05), Vector3(0, -0.03, 0.08), Vector3.ZERO, Vector3(1.2, 0.8, 0.8), acc],
		[_sphere(0.012), Vector3(0, -0.005, 0.12), Vector3.ZERO, Vector3.ONE, pink]]
	for x: float in [-0.045, 0.045]:
		head.append([_sphere(0.018), Vector3(x, 0.025, 0.095), Vector3.ZERO, Vector3.ONE, dark])
		head.append([_prism(0.07, 0.08), Vector3(x * 1.5, 0.1, 0.0), Vector3(0, 0, -signf(x) * 0.3), Vector3.ONE, main])
	_mesh_node(_head, head)
	_tail = Node3D.new()
	_tail.position = Vector3(0, 0.24, -0.24)
	_body.add_child(_tail)
	_mesh_node(_tail, [[_capsule(0.025, 0.3), Vector3(0, 0.12, -0.04), Vector3(-0.4, 0, 0), Vector3.ONE, main]])


static var _mat: StandardMaterial3D


func _mesh_node(parent: Node3D, parts: Array) -> void:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.vertex_color_use_as_albedo = true
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part: Array in parts:
		var src: Mesh = part[0]
		var xf: Transform3D = Transform3D(Basis.from_euler(part[2]).scaled(part[3]), part[1])
		var arrays: Array = src.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var col: Color = part[4]
		for i: int in idx:
			st.set_color(col)
			st.set_normal((xf.basis * norms[i]).normalized())
			st.add_vertex(xf * verts[i])
	var m: MeshInstance3D = MeshInstance3D.new()
	m.mesh = st.commit()
	m.material_override = _mat
	m.visibility_range_end = 70.0
	parent.add_child(m)


func _capsule(r: float, h: float) -> Mesh:
	var c: CapsuleMesh = CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 8
	c.rings = 2
	return c


func _sphere(r: float) -> Mesh:
	var sp: SphereMesh = SphereMesh.new()
	sp.radius = r
	sp.height = r * 2
	sp.radial_segments = 8
	sp.rings = 4
	return sp


func _prism(w: float, h: float) -> Mesh:
	var pr: PrismMesh = PrismMesh.new()
	pr.size = Vector3(w, h, 0.03)
	return pr


## Kalp yüksekliği için (PetInteraction footprint okur).
func footprint() -> Vector2:
	return Vector2(0.3, 0.45)


## Dokunulunca: miyavla, otur ve kuyruk salla.
func pet() -> void:
	if _meow_cd > 0.0:
		return
	_meow_cd = 1.2
	Sfx.play(&"meow")
	state = &"sit"
	_timer = 3.0
	_path.clear()
	if player != null:
		_face(player.global_position)


func _face(p: Vector3) -> void:
	var d: Vector3 = p - global_position
	if Vector2(d.x, d.z).length() > 0.05:
		rotation.y = atan2(d.x, d.z)


func _process(delta: float) -> void:
	_t += delta
	_meow_cd = maxf(_meow_cd - delta, 0.0)
	_tail.rotation.z = sin(_t * (6.0 if state == &"rub" else 2.0)) * 0.5
	_body.scale = Vector3(1, 0.75 + 0.02 * sin(_t * 1.5), 1) if state == &"sleep" else Vector3.ONE
	_head.rotation.x = 0.4 if state == &"sleep" else 0.0
	var near_player: bool = player != null and _flat(player.global_position - global_position) < APPROACH_DIST \
		and _flat(player.global_position - home) < roam + APPROACH_DIST
	var player_still: bool = near_player and Vector2(player.get("velocity").x, player.get("velocity").z).length() < 0.2 \
		if player != null and "velocity" in player else false
	match state:
		&"sit", &"sleep":
			_timer -= delta
			if player_still and state == &"sit" and _rng.randf() < delta * 0.5:
				_go_to(player.global_position)
				state = &"rub"
			elif _timer <= 0.0:
				_choose_next()
		&"walk", &"rub":
			_walk(delta)
			if state == &"rub" and player != null and _flat(player.global_position - global_position) < RUB_DIST + 0.3:
				# oyuncunun etrafında dolan
				_rub_angle += delta * 1.4
				var target: Vector3 = player.global_position + Vector3(cos(_rub_angle), 0, sin(_rub_angle)) * RUB_DIST
				var d: Vector3 = target - global_position
				d.y = 0.0
				global_position += d.limit_length(WALK_SPEED * delta)
				if d.length() > 0.05:
					rotation.y = lerp_angle(rotation.y, atan2(d.x, d.z), delta * 6.0)
				if not player_still or _rng.randf() < delta * 0.08:
					state = &"sit"
					_timer = _rng.randf_range(2.0, 5.0)


func _choose_next() -> void:
	var r: float = _rng.randf()
	if r < 0.55:
		var a: float = _rng.randf() * TAU
		var d: float = _rng.randf_range(2.0, roam)
		_go_to(home + Vector3(cos(a) * d, 0, sin(a) * d))
		state = &"walk"
	elif r < 0.75:
		state = &"sleep"
		_timer = _rng.randf_range(8.0, 20.0)
	else:
		state = &"sit"
		_timer = _rng.randf_range(3.0, 8.0)


func _go_to(target: Vector3) -> void:
	_path.clear()
	if is_inside_tree():
		var map: RID = get_world_3d().navigation_map
		if NavigationServer3D.map_get_iteration_id(map) > 0:
			_path = NavigationServer3D.map_get_path(map, global_position, target, true)
	if _path.is_empty():
		_path = PackedVector3Array([target])


func _walk(delta: float) -> void:
	if _path.is_empty():
		if state == &"walk":
			state = &"sit"
			_timer = _rng.randf_range(2.0, 6.0)
		return
	var next: Vector3 = _path[0]
	var d: Vector3 = next - global_position
	var flat: Vector3 = Vector3(d.x, 0, d.z)
	if flat.length() < 0.15:
		global_position.y = next.y
		_path.remove_at(0)
		return
	var step: Vector3 = flat.limit_length(WALK_SPEED * delta)
	global_position += step
	global_position.y = lerpf(global_position.y, next.y, clampf(delta * 4.0, 0.0, 1.0))
	rotation.y = lerp_angle(rotation.y, atan2(flat.x, flat.z), delta * 8.0)
	_body.position.y = absf(sin(_t * 10.0)) * 0.015


static func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()
