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
