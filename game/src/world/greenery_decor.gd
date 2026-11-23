extends Node3D
## Kampüs yeşil dokusu (Street View/drone referansı): Ortabahçe'yi dolduran ağaçlar, parklarda yol kenarı ağaç sıraları,
## çimlerde seyrek ağaçlar, Ortabahçe kavşaklarında çiçek tarhları, stadyum koşu pisti.
## Konumlar önceden üretilir (tools/assets/make_greenery.py → kampus_greenery.json); burada sadece kurulur.
## Ağaçlar 100 m hücrelerde MultiMesh (görünürlük mesafesiyle), her ağaç tek yüzey (tek çizim çağrısı).

const PropPlacer := preload("res://src/world/prop_placer.gd")
const TREE_MODELS: Dictionary = {
	"tree_stonepine": "res://assets/props/tree_stonepine.glb",
	"tree_plane": "res://assets/props/tree_plane.glb",
	"tree_cypress": "res://assets/props/tree_cypress.glb",
	"tree_birch": "res://assets/props/tree_birch.glb",
	"tree_common": "res://assets/props/tree_common.glb",
}
## Dış paket ağaçları (Quaternius) prop_placer'daki ölçekle aynı boyda görünsün.
const TREE_SCALES: Dictionary = {"tree_birch": 1.4, "tree_common": 1.1}
const CELL_SIZE: float = 100.0
const VISIBILITY_END: float = 240.0
const VISIBILITY_MARGIN: float = 20.0
const TREE_RADIUS: float = 0.4
const TREE_COLLIDER_H: float = 4.0
const BED_RADIUS: float = 3.2
const BED_HEIGHT: float = 0.45
const TRACK_Y: float = 0.035
const TRACK_COLOR: Color = Color(0.62, 0.29, 0.23)  # kırmızı tartan (drone: stadyum pisti)
const FLOWERBED_SHADER: Shader = preload("res://assets/shaders/flowerbed.gdshader")

var tree_count: int = 0
var bed_count: int = 0
var track_count: int = 0
var kiosk_count: int = 0

## Ortabahçe büfesi (Street View): koyu turkuaz gövde, mavi düz çatı, ahşap direkli saçak, önde iki kırmızı otomat.
const KIOSK_BODY: Vector3 = Vector3(5.0, 2.6, 3.4)
const KIOSK_ROOF: Vector3 = Vector3(7.6, 0.22, 5.6)
const KIOSK_BODY_COLOR: Color = Color(0.16, 0.3, 0.36)
const KIOSK_ROOF_COLOR: Color = Color(0.2, 0.42, 0.68)
const KIOSK_POST_COLOR: Color = Color(0.5, 0.38, 0.27)
const VENDING_COLOR: Color = Color(0.74, 0.12, 0.13)
const VENDING_SIZE: Vector3 = Vector3(0.9, 1.9, 0.75)


func build_from_file(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is Dictionary:
		build(data)


func build(data: Dictionary) -> void:
	_build_trees(data.get("trees", []))
	_build_beds(data.get("beds", []))
	for t: Variant in data.get("tracks", []):
		_build_track(t as Dictionary)
	for k: Variant in data.get("kiosks", []):
		var kx: float = float(k[0])
		var kz: float = float(k[1])
		_build_kiosk(Vector3(kx, TerrainHeight.active_height(kx, kz), kz), float(k[2]))


func _build_trees(trees: Array) -> void:
	var by_cell: Dictionary = {}  # Vector2i -> {kind: [Transform3D]}
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "GreeneryTreeColliders"
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = TREE_RADIUS
	shape.height = TREE_COLLIDER_H
	for t: Variant in trees:
		var a: Array = t
		var kind: String = str(a[0])
		if not TREE_MODELS.has(kind):
			continue
		var tx: float = float(a[1])
		var tz: float = float(a[2])
		var pos: Vector3 = Vector3(tx, TerrainHeight.active_height(tx, tz), tz)
		var s: float = float(a[4]) * float(TREE_SCALES.get(kind, 1.0))
		var cell: Vector2i = Vector2i(floori(pos.x / CELL_SIZE), floori(pos.z / CELL_SIZE))
		var kinds: Dictionary = by_cell.get_or_add(cell, {})
		(kinds.get_or_add(kind, []) as Array).append(Transform3D(Basis(Vector3.UP, float(a[3])).scaled(Vector3.ONE * s), pos))
		var col: CollisionShape3D = CollisionShape3D.new()
		col.shape = shape
		col.position = pos + Vector3(0.0, TREE_COLLIDER_H * 0.5, 0.0)
		body.add_child(col)
		tree_count += 1
	add_child(body)
	var meshes: Dictionary = {}
	for kind: String in TREE_MODELS:
		meshes[kind] = _load_meshes(TREE_MODELS[kind])
	for cell: Vector2i in by_cell:
		for kind: String in by_cell[cell]:
			for entry: Array in meshes[kind]:
				_add_multimesh(entry[0], entry[1], by_cell[cell][kind])


## [[mesh, yerel dönüşüm], ...]
func _load_meshes(path: String) -> Array:
	var out: Array = []
	if not ResourceLoader.exists(path):
		return out
	var scene: Node = (load(path) as PackedScene).instantiate()
	for mi: Node in scene.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (mi as MeshInstance3D).mesh
		PropPlacer.use_vertex_colors(m)
		out.append([m, (mi as MeshInstance3D).transform])
	scene.free()
	return out


func _add_multimesh(mesh: Mesh, local: Transform3D, xforms: Array) -> void:
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i: int in xforms.size():
		mm.set_instance_transform(i, (xforms[i] as Transform3D) * local)
	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.visibility_range_end = VISIBILITY_END
	mmi.visibility_range_end_margin = VISIBILITY_MARGIN
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(mmi)


func _build_beds(beds: Array) -> void:
	bed_count = beds.size()
	if beds.is_empty():
		return
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = BED_RADIUS
	cyl.bottom_radius = BED_RADIUS + 0.15
	cyl.height = BED_HEIGHT
	cyl.radial_segments = 14
	cyl.rings = 1
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = FLOWERBED_SHADER
	cyl.material = mat
	var xforms: Array = []
	for b: Variant in beds:
		var bx: float = float(b[0])
		var bz: float = float(b[1])
		var by: float = TerrainHeight.active_height(bx, bz)
		xforms.append(Transform3D(Basis(), Vector3(bx, by + BED_HEIGHT * 0.5, bz)))
	_add_multimesh(cyl, Transform3D.IDENTITY, xforms)


## Pist: iç ve dış çokgen (aynı köşe sayısı) arasında düz halka.
func _build_track(t: Dictionary) -> void:
	var inner: Array = t.get("inner", [])
	var outer: Array = t.get("outer", [])
	if inner.size() < 3 or inner.size() != outer.size():
		return
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var n: int = inner.size()
	for i: int in n:
		var j: int = (i + 1) % n
		var ax: float = float(inner[i][0])
		var az: float = float(inner[i][1])
		var bx: float = float(inner[j][0])
		var bz: float = float(inner[j][1])
		var cx: float = float(outer[j][0])
		var cz: float = float(outer[j][1])
		var dx: float = float(outer[i][0])
		var dz: float = float(outer[i][1])
		var a: Vector3 = Vector3(ax, TerrainHeight.active_height(ax, az) + TRACK_Y, az)
		var b: Vector3 = Vector3(bx, TerrainHeight.active_height(bx, bz) + TRACK_Y, bz)
		var c: Vector3 = Vector3(cx, TerrainHeight.active_height(cx, cz) + TRACK_Y, cz)
		var d: Vector3 = Vector3(dx, TerrainHeight.active_height(dx, dz) + TRACK_Y, dz)
		# Yukarı bakan yüz: sarma yönü çokgen yönüne göre değişir, normali kontrol edip çevir
		var up: bool = (b - a).cross(c - a).y < 0.0
		for v: Vector3 in ([a, b, c, a, c, d] if up else [a, c, b, a, d, c]):
			st.add_vertex(v)
	var mesh: ArrayMesh = st.commit()
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = TRACK_COLOR
	mat.roughness = 0.95
	mesh.surface_set_material(0, mat)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Track"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	track_count += 1
	_build_stadium_details(inner, outer)


## Stadyum içi gerçekçi detaylar: beyaz futbol saha çizgileri (tek çizim), iki kale ve 4 aydınlatma direği.
func _build_stadium_details(inner: Array, outer: Array) -> void:
	var min_x: float = INF
	var max_x: float = -INF
	var min_z: float = INF
	var max_z: float = -INF
	for p: Array in inner:
		min_x = minf(min_x, float(p[0]))
		max_x = maxf(max_x, float(p[0]))
		min_z = minf(min_z, float(p[1]))
		max_z = maxf(max_z, float(p[1]))
	var cx: float = (min_x + max_x) * 0.5
	var cz: float = (min_z + max_z) * 0.5
	var half_w: float = clampf((max_x - min_x) * 0.36, 18.0, 34.0)
	var half_l: float = clampf((max_z - min_z) * 0.36, 30.0, 52.0)
	var y: float = TerrainHeight.active_height(cx, cz) + TRACK_Y + 0.025

	# 1) Saha çizgileri (tek ArrayMesh)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var lw: float = 0.22
	# Dış dikdörtgen + orta çizgi
	_line_quad(st, Vector2(cx - half_w, cz - half_l), Vector2(cx + half_w, cz - half_l), lw, y)
	_line_quad(st, Vector2(cx - half_w, cz + half_l), Vector2(cx + half_w, cz + half_l), lw, y)
	_line_quad(st, Vector2(cx - half_w, cz - half_l), Vector2(cx - half_w, cz + half_l), lw, y)
	_line_quad(st, Vector2(cx + half_w, cz - half_l), Vector2(cx + half_w, cz + half_l), lw, y)
	_line_quad(st, Vector2(cx - half_w, cz), Vector2(cx + half_w, cz), lw, y)
	# Orta daire (r = 9.15 m)
	var cr: float = 9.15
	for i: int in 24:
		var a0: float = TAU * float(i) / 24.0
		var a1: float = TAU * float(i + 1) / 24.0
		_line_quad(st, Vector2(cx + cos(a0) * cr, cz + sin(a0) * cr), Vector2(cx + cos(a1) * cr, cz + sin(a1) * cr), lw, y)
	# İki ceza sahası (16.5 m derinlik, 36 m genişlik)
	var box_w: float = minf(18.0, half_w * 0.65)
	var box_d: float = minf(16.5, half_l * 0.32)
	for side: float in [-1.0, 1.0]:
		var z_end: float = cz + side * half_l
		var z_in: float = cz + side * (half_l - box_d)
		_line_quad(st, Vector2(cx - box_w, z_in), Vector2(cx + box_w, z_in), lw, y)
		_line_quad(st, Vector2(cx - box_w, z_end), Vector2(cx - box_w, z_in), lw, y)
		_line_quad(st, Vector2(cx + box_w, z_end), Vector2(cx + box_w, z_in), lw, y)

	var line_mesh: ArrayMesh = st.commit()
	var white_mat: StandardMaterial3D = StandardMaterial3D.new()
	white_mat.albedo_color = Color(0.96, 0.97, 0.96)
	white_mat.roughness = 0.9
	line_mesh.surface_set_material(0, white_mat)
	var lines_mi: MeshInstance3D = MeshInstance3D.new()
	lines_mi.name = "PitchLines"
	lines_mi.mesh = line_mesh
	lines_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lines_mi)

	# 2) İki futbol kalesi (7.32 m x 2.44 m)
	var goals_root: Node3D = Node3D.new()
	goals_root.name = "StadiumGoals"
	var gw: float = 7.32
	var gh: float = 2.44
	var gd: float = 1.6
	for side: float in [-1.0, 1.0]:
		var gz: float = cz + side * half_l
		var back_z: float = gz + side * gd
		for sx: float in [-1.0, 1.0]:
			_box(goals_root, Vector3(0.14, gh, 0.14), Vector3(cx + sx * gw * 0.5, y + gh * 0.5, gz), Color(0.96, 0.96, 0.96))
			_box(goals_root, Vector3(0.1, gh, 0.1), Vector3(cx + sx * gw * 0.5, y + gh * 0.5, back_z), Color(0.85, 0.87, 0.89))
			_box(goals_root, Vector3(0.1, 0.1, gd), Vector3(cx + sx * gw * 0.5, y + gh, (gz + back_z) * 0.5), Color(0.85, 0.87, 0.89))
		_box(goals_root, Vector3(gw + 0.14, 0.14, 0.14), Vector3(cx, y + gh, gz), Color(0.96, 0.96, 0.96))
		_box(goals_root, Vector3(gw, 0.1, 0.1), Vector3(cx, y + gh, back_z), Color(0.85, 0.87, 0.89))
	add_child(goals_root)

	# 3) 4 köşe stadyum aydınlatma direği (outer track dış köşeleri)
	var omin_x: float = INF
	var omax_x: float = -INF
	var omin_z: float = INF
	var omax_z: float = -INF
	for p: Array in outer:
		omin_x = minf(omin_x, float(p[0]))
		omax_x = maxf(omax_x, float(p[0]))
		omin_z = minf(omin_z, float(p[1]))
		omax_z = maxf(omax_z, float(p[1]))
	var towers: Node3D = Node3D.new()
	towers.name = "StadiumTowers"
	var tower_h: float = 16.0
	for tx: float in [omin_x - 3.0, omax_x + 3.0]:
		for tz: float in [omin_z + 18.0, omax_z - 18.0]:
			var ty: float = TerrainHeight.active_height(tx, tz)
			_box(towers, Vector3(0.55, tower_h, 0.55), Vector3(tx, ty + tower_h * 0.5, tz), Color(0.45, 0.48, 0.52))
			_box(towers, Vector3(2.8, 1.1, 0.8), Vector3(tx, ty + tower_h + 0.4, tz), Color(0.92, 0.94, 0.96))
	add_child(towers)


static func _line_quad(st: SurfaceTool, a: Vector2, b: Vector2, width: float, y: float) -> void:
	if a.distance_to(b) < 0.01:
		return
	var side: Vector2 = (b - a).normalized().orthogonal() * (width * 0.5)
	var p0: Vector3 = Vector3(a.x + side.x, y, a.y + side.y)
	var p1: Vector3 = Vector3(a.x - side.x, y, a.y - side.y)
	var p2: Vector3 = Vector3(b.x - side.x, y, b.y - side.y)
	var p3: Vector3 = Vector3(b.x + side.x, y, b.y + side.y)
	for v: Vector3 in [p0, p2, p1, p0, p3, p2]:
		st.add_vertex(v)


func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	bm.material = m
	mi.mesh = bm
	mi.position = pos
	parent.add_child(mi)


func _build_kiosk(pos: Vector3, yaw: float) -> void:
	var root: StaticBody3D = StaticBody3D.new()
	root.name = "Kiosk"
	root.position = pos
	root.rotation.y = yaw
	_box(root, KIOSK_BODY, Vector3(0.0, KIOSK_BODY.y * 0.5, -0.6), KIOSK_BODY_COLOR)
	var roof_y: float = KIOSK_BODY.y + 0.25
	_box(root, KIOSK_ROOF, Vector3(0.0, roof_y, 0.0), KIOSK_ROOF_COLOR)
	for sx: float in [-1.0, 1.0]:
		_box(root, Vector3(0.14, roof_y, 0.14), Vector3(sx * (KIOSK_ROOF.x * 0.5 - 0.3), roof_y * 0.5, KIOSK_ROOF.z * 0.5 - 0.3), KIOSK_POST_COLOR)
	for sx: float in [-0.55, 0.55]:
		_box(root, VENDING_SIZE, Vector3(sx, VENDING_SIZE.y * 0.5, KIOSK_BODY.z * 0.5 - 0.6 + VENDING_SIZE.z * 0.5), VENDING_COLOR)
	var col: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = KIOSK_BODY
	col.shape = shape
	col.position = Vector3(0.0, KIOSK_BODY.y * 0.5, -0.6)
	root.add_child(col)
	add_child(root)
	kiosk_count += 1
