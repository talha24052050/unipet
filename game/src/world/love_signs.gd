extends Node3D
## Kampüsteki "I ❤ YTÜ" yazıları (data/love_signs.json): 3D harfler (TextMesh) + kırmızı kalp + alçak kaide.
## Fotoğraf çekilecek yer: çarpışma kutusu var, petler içinden geçmez.

const DATA: String = "res://data/love_signs.json"
const LETTER_H: float = 1.3
const DEPTH: float = 0.35
const WHITE: Color = Color(0.97, 0.97, 0.97)
const NAVY: Color = Color(0.12, 0.18, 0.42)
const RED: Color = Color(0.86, 0.12, 0.17)

var signs: Array[Node3D] = []


static func load_signs() -> Array:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	return (d as Dictionary).get("signs", []) if d is Dictionary else []


func _ready() -> void:
	for s: Dictionary in load_signs():
		var n: Node3D = build_sign(Color.from_string(str(s.get("letters", "")), NAVY))
		add_child(n)
		n.position = Vector3(float(s["x"]), float(s.get("y", 0.0)), float(s["z"]))
		n.rotation.y = deg_to_rad(float(s.get("yaw_deg", 0.0)))
		signs.append(n)


static func _mat(c: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.5
	return m


static func _text(t: String, color: Color) -> MeshInstance3D:
	var tm: TextMesh = TextMesh.new()
	tm.text = t
	tm.font_size = 64
	tm.pixel_size = LETTER_H / 64.0 * 1.35
	tm.depth = DEPTH
	tm.curve_step = 2.0
	tm.material = _mat(color)
	var m: MeshInstance3D = MeshInstance3D.new()
	m.mesh = tm
	return m


## Ekstrüde kalp (kalp eğrisi çokgeni, ön/arka yüz + yan duvarlar).
static func heart_mesh(size: float, depth: float) -> ArrayMesh:
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in 48:
		var t: float = TAU * i / 48.0
		var x: float = 16.0 * pow(sin(t), 3)
		var y: float = 13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t)
		pts.append(Vector2(x, y) * size / 34.0)
	var tris: PackedInt32Array = Geometry2D.triangulate_polygon(pts)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: float in [1.0, -1.0]:
		var z: float = depth * 0.5 * side
		for k: int in range(0, tris.size(), 3):
			var a: Vector2 = pts[tris[k]]
			var b: Vector2 = pts[tris[k + 1]]
			var c: Vector2 = pts[tris[k + 2]]
			var order: Array = [a, c, b] if side > 0 else [a, b, c]
			for p: Vector2 in order:
				st.add_vertex(Vector3(p.x, p.y, z))
	for i: int in pts.size():
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % pts.size()]
		var f: float = depth * 0.5
		for p: Vector3 in [Vector3(a.x, a.y, f), Vector3(b.x, b.y, f), Vector3(b.x, b.y, -f),
				Vector3(a.x, a.y, f), Vector3(b.x, b.y, -f), Vector3(a.x, a.y, -f)]:
			st.add_vertex(p)
	st.generate_normals()
	return st.commit()


## "I ❤ YTÜ": tabelanın önü +Z. Toplam genişlik ~5 m.
static func build_sign(letters: Color = NAVY) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "ILoveYTU"
	var base: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(5.6, 0.3, 1.0)
	bm.material = _mat(Color(0.75, 0.75, 0.73))
	base.mesh = bm
	base.position.y = 0.15
	root.add_child(base)
	# harfleri yüksekliğe göre ölçekle, kalple birlikte ortalayarak diz (aralık 0.25 m)
	var parts: Array[MeshInstance3D] = [_text("I", letters), MeshInstance3D.new(), _text("YTÜ", letters)]
	parts[1].mesh = heart_mesh(LETTER_H * 1.05, DEPTH * 1.2)
	parts[1].material_override = _mat(RED)
	var widths: Array[float] = []
	for m: MeshInstance3D in parts:
		var bb: AABB = m.mesh.get_aabb()
		if m != parts[1]:
			m.scale = Vector3.ONE * (LETTER_H / bb.size.y)
		widths.append(bb.size.x * m.scale.x)
	var gap: float = 0.25
	var total: float = widths[0] + widths[1] + widths[2] + gap * 2.0
	var x: float = -total * 0.5
	for k: int in parts.size():
		var m: MeshInstance3D = parts[k]
		var bb: AABB = m.mesh.get_aabb()
		# AABB'nin sol-alt köşesini (x, taban) noktasına getir
		m.position = Vector3(x - bb.position.x * m.scale.x, 0.3 - bb.position.y * m.scale.y, 0.0)
		x += widths[k] + gap
		root.add_child(m)
	bm.size.x = total + 0.6
	for n: Node in root.get_children():
		(n as GeometryInstance3D).visibility_range_end = 220.0
	var body: StaticBody3D = StaticBody3D.new()
	var col: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(bm.size.x, 1.8, 1.0)
	col.shape = box
	col.position.y = 0.9
	body.add_child(col)
	root.add_child(body)
	return root
