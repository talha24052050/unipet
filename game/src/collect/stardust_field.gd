extends Node3D
## Kampüse dağılmış yıldız tozları: sunucunun bildirdiği bugünkü noktalarda dönen altın yıldızlar.
## Oyuncu yaklaşınca toplanır (sunucuya bildirilir), sayaç güncellenir.

const Stardust := preload("res://src/collect/stardust_rules.gd")
const PICK_DIST: float = 1.8
const CHECK_S: float = 0.15
const VISIBLE_M: float = 90.0
const COLOR: Color = Color(1.0, 0.82, 0.35)

@export var player: Node3D
## Sayaç (isteğe bağlı): "Yıldız tozu" etiketi.
@export var counter: Label

var points: Array = []
## nokta indeksi -> MeshInstance3D
var stars: Dictionary = {}
var _pending: Dictionary = {}
var _timer: float = 0.0
var _t: float = 0.0
static var _mesh: Mesh


func _ready() -> void:
	points = Stardust.load_points()
	if Services.net != null:
		Services.net.wallet_updated.connect(_on_wallet)
		if not Services.net.wallet.is_empty():
			_on_wallet(Services.net.wallet)


func _on_wallet(w: Dictionary) -> void:
	var want: Dictionary = {}
	for i: Variant in w.get("points", []):
		want[int(i)] = true
	for i: int in stars.keys():
		if not want.has(i):
			(stars[i] as Node).queue_free()
			stars.erase(i)
	for i: int in want:
		if not stars.has(i) and i >= 0 and i < points.size():
			stars[i] = _make_star(i)
	_pending.clear()
	if counter != null:
		counter.text = "Yıldız tozu: %d" % int(w.get("dust", 0))
	if bool(w.get("got", false)):
		Sfx.play(&"care_ok")


func _make_star(i: int) -> MeshInstance3D:
	var m: MeshInstance3D = MeshInstance3D.new()
	m.mesh = star_mesh()
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.visibility_range_end = VISIBLE_M
	add_child(m)
	var pt: Array = points[i]
	m.position = Vector3(float(pt[0]), 0.0, float(pt[1]))
	m.set_meta("ground", false)
	return m


func _process(delta: float) -> void:
	_t += delta
	for i: int in stars:
		var m: MeshInstance3D = stars[i]
		if not bool(m.get_meta("ground")):
			_snap_ground(m)
		m.rotation.y = _t * 2.0 + i
		m.position.y = float(m.get_meta("gy", 0.0)) + 0.7 + sin(_t * 2.5 + i) * 0.12
	_timer += delta
	if _timer < CHECK_S or player == null:
		return
	_timer = 0.0
	var pp: Vector3 = player.global_position
	for i: int in stars:
		if _pending.has(i):
			continue
		var m: MeshInstance3D = stars[i]
		if Vector2(m.position.x - pp.x, m.position.z - pp.z).length() <= PICK_DIST:
			_pending[i] = true
			m.visible = false
			_burst(m.position)
			if Services.net != null:
				Services.net.send_collect(i)


func _snap_ground(m: MeshInstance3D) -> void:
	if not is_inside_tree():
		return
	var p: Vector3 = m.position
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(p.x, 60.0, p.z), Vector3(p.x, -20.0, p.z))
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		m.set_meta("gy", (hit["position"] as Vector3).y)
		m.set_meta("ground", true)


## Toplama parıltısı: küçük yıldız büyüyüp kaybolur.
func _burst(at: Vector3) -> void:
	var f: MeshInstance3D = MeshInstance3D.new()
	f.mesh = star_mesh()
	add_child(f)
	f.position = at
	var tw: Tween = f.create_tween().set_parallel(true)
	tw.tween_property(f, "scale", Vector3.ONE * 2.5, 0.35)
	tw.tween_property(f, "position:y", at.y + 1.2, 0.35)
	tw.chain().tween_callback(f.queue_free)


## Kalın, beş köşeli, kendinden parlayan yıldız (~0.6 m).
static func star_mesh() -> Mesh:
	if _mesh != null:
		return _mesh
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rim: Array[Vector3] = []
	for k: int in 10:
		var a: float = PI / 2 + PI * k / 5.0
		var r: float = 0.3 if k % 2 == 0 else 0.13
		rim.append(Vector3(cos(a) * r, sin(a) * r, 0.0))
	for side: float in [1.0, -1.0]:
		var c: Vector3 = Vector3(0, 0, 0.07 * side)
		for k: int in 10:
			var a: Vector3 = rim[k]
			var b: Vector3 = rim[(k + 1) % 10]
			if side > 0:
				st.add_vertex(c); st.add_vertex(b); st.add_vertex(a)
			else:
				st.add_vertex(c); st.add_vertex(a); st.add_vertex(b)
	st.generate_normals()
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = COLOR
	mat.emission_enabled = true
	mat.emission = COLOR
	mat.emission_energy_multiplier = 1.6
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	st.set_material(mat)
	_mesh = st.commit()
	return _mesh
