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
const BUSH_MODELS: Dictionary = {
	"bush_common": "res://assets/props/bush_common.glb",
	"bush_berries": "res://assets/props/bush_berries.glb",
}
## Dış paket ağaçları (Quaternius) prop_placer'daki ölçekle aynı boyda görünsün.
const TREE_SCALES: Dictionary = {"tree_birch": 1.4, "tree_common": 1.1}
const CELL_SIZE: float = 100.0
const VISIBILITY_END: float = 240.0
const BUSH_VISIBILITY_END: float = 135.0
const VISIBILITY_MARGIN: float = 20.0
const TREE_RADIUS: float = 0.4
const TREE_COLLIDER_H: float = 4.0
const TREE_ROOT_SINK: float = 0.25
const BED_RADIUS: float = 3.2
const BED_HEIGHT: float = 0.45
const TRACK_Y: float = 0.035
const TRACK_COLOR: Color = Color(0.62, 0.29, 0.23)  # kırmızı tartan (drone: stadyum pisti)
const FLOWERBED_SHADER: Shader = preload("res://assets/shaders/flowerbed.gdshader")

var tree_count: int = 0
var bush_count: int = 0
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
	_build_bushes(data.get("bushes", []))
	_build_beds(data.get("beds", []))
	for t: Variant in data.get("tracks", []):
		_build_track(t as Dictionary)
	var kiosks: Array = data.get("kiosks", [])
	for k: Variant in kiosks:
		var kx: float = float(k[0])
		var kz: float = float(k[1])
		_build_kiosk(Vector3(kx, TerrainHeight.active_height(kx, kz), kz), float(k[2]))
	if not kiosks.is_empty():
		_build_ortabahce_monument(Vector2(-2.1, 5.3))


func _build_trees(trees: Array) -> void:
	var by_cell: Dictionary = {}  # Vector2i -> {kind: {"xforms": [], "colors": []}}
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
		var ty: float = TerrainHeight.active_height(tx, tz)
		var pos: Vector3 = Vector3(tx, ty - TREE_ROOT_SINK, tz)
		var base_s: float = float(a[4]) * float(TREE_SCALES.get(kind, 1.0))
		# Organik çeşitlilik: hafif gövde eğimi (±2.4°) ve bağımsız en/boy oranı
		var h1: float = _pos_hash(tx, tz, 1.0)
		var h2: float = _pos_hash(tx, tz, 2.0)
		var h3: float = _pos_hash(tx, tz, 3.0)
		var h4: float = _pos_hash(tx, tz, 4.0)
		var lean_x: float = (h1 - 0.5) * 0.085
		var lean_z: float = (h2 - 0.5) * 0.085
		var s_xz: float = base_s * lerpf(0.88, 1.14, h3)
		var s_y: float = base_s * lerpf(0.88, 1.16, h4)
		var b: Basis = Basis(Vector3.UP, float(a[3])) * Basis(Vector3.RIGHT, lean_x) * Basis(Vector3.FORWARD, lean_z)
		b = b.scaled(Vector3(s_xz, s_y, s_xz))

		var cell: Vector2i = Vector2i(floori(tx / CELL_SIZE), floori(tz / CELL_SIZE))
		var kinds: Dictionary = by_cell.get_or_add(cell, {})
		var bucket: Dictionary = kinds.get_or_add(kind, {"xforms": [], "colors": []})
		(bucket["xforms"] as Array).append(Transform3D(b, pos))
		(bucket["colors"] as Array).append(tree_tint_for(kind, tx, tz))

		var col: CollisionShape3D = CollisionShape3D.new()
		col.shape = shape
		col.position = Vector3(tx, ty + TREE_COLLIDER_H * 0.5, tz)
		body.add_child(col)
		tree_count += 1
	add_child(body)
	var meshes: Dictionary = {}
	for kind: String in TREE_MODELS:
		meshes[kind] = _load_meshes(TREE_MODELS[kind])
	for cell: Vector2i in by_cell:
		for kind: String in by_cell[cell]:
			var bucket: Dictionary = by_cell[cell][kind]
			for entry: Array in meshes[kind]:
				_add_multimesh(entry[0], entry[1], bucket["xforms"], bucket["colors"], VISIBILITY_END)


## Dekoratif çalı alt-katmanı (çarpışmasız, 100 m hücrelerde MultiMesh).
func _build_bushes(bushes: Array) -> void:
	if bushes.is_empty():
		return
	var by_cell: Dictionary = {}
	for b_var: Variant in bushes:
		var a: Array = b_var
		var kind: String = str(a[0])
		if not BUSH_MODELS.has(kind):
			continue
		var bx: float = float(a[1])
		var bz: float = float(a[2])
		var by: float = TerrainHeight.active_height(bx, bz)
		var yaw: float = float(a[3])
		var sc: float = float(a[4])
		var h1: float = _pos_hash(bx, bz, 7.0)
		var basis: Basis = Basis(Vector3.UP, yaw).scaled(Vector3(sc * lerpf(0.9, 1.15, h1), sc * lerpf(0.82, 1.12, 1.0 - h1), sc * lerpf(0.9, 1.15, h1)))
		var cell: Vector2i = Vector2i(floori(bx / CELL_SIZE), floori(bz / CELL_SIZE))
		var kinds: Dictionary = by_cell.get_or_add(cell, {})
		(kinds.get_or_add(kind, []) as Array).append(Transform3D(basis, Vector3(bx, by - 0.08, bz)))
		bush_count += 1
	var meshes: Dictionary = {}
	for kind: String in BUSH_MODELS:
		meshes[kind] = _load_meshes(BUSH_MODELS[kind])
	for cell: Vector2i in by_cell:
		for kind: String in by_cell[cell]:
			for entry: Array in meshes[kind]:
				_add_multimesh(entry[0], entry[1], by_cell[cell][kind], [], BUSH_VISIBILITY_END)


static func _pos_hash(x: float, z: float, salt: float) -> float:
	return fposmod(sin(x * 12.9898 + z * 78.233 + salt * 37.719) * 43758.5453, 1.0)


## Konuma bağlı deterministik ağaç yaprak tonu (klon görünümünü kırar; drone referansındaki zengin yeşil paleti).
static func tree_tint_for(kind: String, x: float, z: float) -> Color:
	var h: float = _pos_hash(x, z, 11.0)
	var v: float = lerpf(0.84, 1.12, _pos_hash(x, z, 19.0))
	if kind == "tree_plane":
		if h > 0.88:
			return Color(1.10 * v, 1.02 * v, 0.76 * v)  # nadir güneşli altın-yeşil çınar
		if h < 0.35:
			return Color(0.86 * v, 0.98 * v, 0.84 * v)  # derin zümrüt çınar
		return Color(0.98 * v, 1.04 * v, 0.88 * v)      # taze ilkbahar yeşili
	if kind == "tree_stonepine" or kind == "tree_cypress":
		if h < 0.45:
			return Color(0.84 * v, 0.96 * v, 0.90 * v)  # serin çam yeşili
		return Color(0.96 * v, 1.02 * v, 0.86 * v)      # sıcak Akdeniz çamı
	return Color(v, v, v)


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


func _add_multimesh(mesh: Mesh, local: Transform3D, xforms: Array, colors: Array = [], vis_end: float = VISIBILITY_END) -> void:
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var use_col: bool = not colors.is_empty() and _mesh_supports_instance_color(mesh)
	if use_col:
		mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i: int in xforms.size():
		mm.set_instance_transform(i, (xforms[i] as Transform3D) * local)
		if use_col:
			mm.set_instance_color(i, colors[i] as Color)
	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.visibility_range_end = vis_end
	mmi.visibility_range_end_margin = VISIBILITY_MARGIN
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(mmi)


static func _mesh_supports_instance_color(mesh: Mesh) -> bool:
	if mesh == null or mesh.get_surface_count() == 0:
		return false
	var mat: BaseMaterial3D = mesh.surface_get_material(0) as BaseMaterial3D
	return mat != null and mat.vertex_color_use_as_albedo


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


## Stadyum içi gerçekçi detaylar: pistin gerçek ~15° yönüne hizalı saha çizgileri (1 çizim),
## iki kale, 4 aydınlatma direği ve Taşbina tarafında üstü açık tribün (tek birleşik köşe-renkli mesh = 1 çizim).
func _build_stadium_details(inner: Array, outer: Array) -> void:
	var frame: Dictionary = _stadium_frame(inner, outer)
	var center: Vector2 = frame["center"]
	var axis_w: Vector2 = frame["axis_w"]  # +X: Taşbina'ya bakan doğu yönü
	var axis_l: Vector2 = frame["axis_l"]  # +Z: sahanın uzun ekseni
	var in_hw: float = float(frame["in_hw"])
	var in_hl: float = float(frame["in_hl"])
	var out_hw: float = float(frame["out_hw"])
	var out_hl: float = float(frame["out_hl"])

	# Dikdörtgen saha ovalin düz orta bölümüne tam sığsın (çizgiler kırmızı piste taşmasın)
	var half_w: float = clampf(in_hw * 0.84, 16.0, 32.0)
	var half_l: float = clampf(in_hl * 0.68, 28.0, 48.0)
	var base_y: float = TerrainHeight.active_height(center.x, center.y)
	var line_y: float = TRACK_Y + 0.025

	# Yerel (u=doğu, v=uzun eksen) -> sahne XZ dönüşümü: tek ortak kök düğüm
	var root: Node3D = Node3D.new()
	root.name = "StadiumDetails"
	root.basis = Basis(Vector3(axis_w.x, 0.0, axis_w.y), Vector3.UP, Vector3(axis_l.x, 0.0, axis_l.y))
	root.position = Vector3(center.x, base_y, center.y)
	add_child(root)

	# 1) Saha çizgileri (yerel eksende, tek ArrayMesh = 1 çizim)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var lw: float = 0.22
	_line_quad(st, Vector2(-half_w, -half_l), Vector2(half_w, -half_l), lw, line_y)
	_line_quad(st, Vector2(-half_w, half_l), Vector2(half_w, half_l), lw, line_y)
	_line_quad(st, Vector2(-half_w, -half_l), Vector2(-half_w, half_l), lw, line_y)
	_line_quad(st, Vector2(half_w, -half_l), Vector2(half_w, half_l), lw, line_y)
	_line_quad(st, Vector2(-half_w, 0.0), Vector2(half_w, 0.0), lw, line_y)
	var cr: float = minf(9.15, half_w * 0.35)
	for i: int in 24:
		var a0: float = TAU * float(i) / 24.0
		var a1: float = TAU * float(i + 1) / 24.0
		_line_quad(st, Vector2(cos(a0) * cr, sin(a0) * cr), Vector2(cos(a1) * cr, sin(a1) * cr), lw, line_y)
	var box_w: float = minf(18.0, half_w * 0.65)
	var box_d: float = minf(16.5, half_l * 0.32)
	for side: float in [-1.0, 1.0]:
		var z_end: float = side * half_l
		var z_in: float = side * (half_l - box_d)
		_line_quad(st, Vector2(-box_w, z_in), Vector2(box_w, z_in), lw, line_y)
		_line_quad(st, Vector2(-box_w, z_end), Vector2(-box_w, z_in), lw, line_y)
		_line_quad(st, Vector2(box_w, z_end), Vector2(box_w, z_in), lw, line_y)

	var line_mesh: ArrayMesh = st.commit()
	var white_mat: StandardMaterial3D = StandardMaterial3D.new()
	white_mat.albedo_color = Color(0.96, 0.97, 0.96)
	white_mat.roughness = 0.9
	line_mesh.surface_set_material(0, white_mat)
	var lines_mi: MeshInstance3D = MeshInstance3D.new()
	lines_mi.name = "PitchLines"
	lines_mi.mesh = line_mesh
	lines_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(lines_mi)

	# 2) Tüm yapılar (kaleler + 4 projektör direği + doğu tribün) tek köşe-renkli mesh = 1 çizim!
	var mst: SurfaceTool = SurfaceTool.new()
	mst.begin(Mesh.PRIMITIVE_TRIANGLES)
	mst.set_smooth_group(-1)

	# 2a) İki futbol kalesi (7.32 m x 2.44 m)
	var gw: float = 7.32
	var gh: float = 2.44
	var gd: float = 1.6
	var goal_white: Color = Color(0.96, 0.96, 0.96)
	var goal_back: Color = Color(0.84, 0.86, 0.88)
	for side: float in [-1.0, 1.0]:
		var gz: float = side * half_l
		var back_z: float = gz + side * gd
		for sx: float in [-1.0, 1.0]:
			_add_colored_box(mst, Vector3(0.14, gh, 0.14), Vector3(sx * gw * 0.5, gh * 0.5, gz), goal_white)
			_add_colored_box(mst, Vector3(0.1, gh, 0.1), Vector3(sx * gw * 0.5, gh * 0.5, back_z), goal_back)
			_add_colored_box(mst, Vector3(0.1, 0.1, gd), Vector3(sx * gw * 0.5, gh, (gz + back_z) * 0.5), goal_back)
		_add_colored_box(mst, Vector3(gw + 0.14, 0.14, 0.14), Vector3(0.0, gh, gz), goal_white)
		_add_colored_box(mst, Vector3(gw, 0.1, 0.1), Vector3(0.0, gh, back_z), goal_back)

	# 2b) 4 köşe stadyum aydınlatma direği (outer pist dış köşeleri)
	var tower_h: float = 16.0
	var pole_col: Color = Color(0.45, 0.48, 0.52)
	var lamp_head_col: Color = Color(0.92, 0.94, 0.96)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var lx: float = sx * (out_hw + 3.0)
			var lz: float = sz * (out_hl * 0.65)
			var wp: Vector2 = center + axis_w * lx + axis_l * lz
			var dy: float = TerrainHeight.active_height(wp.x, wp.y) - base_y
			_add_colored_box(mst, Vector3(0.55, tower_h, 0.55), Vector3(lx, dy + tower_h * 0.5, lz), pole_col)
			_add_colored_box(mst, Vector3(0.8, 1.1, 2.8), Vector3(lx, dy + tower_h + 0.4, lz), lamp_head_col)

	# 2c) Üstü açık basamaklı tribün — Taşbina'ya bakan doğu kenarı (+axis_w)
	var trib_len: float = clampf(out_hl * 0.95, 48.0, 76.0)
	var rows_n: int = 6
	var step_d: float = 0.95
	var step_h: float = 0.55
	var trib_x0: float = out_hw + 2.2
	var trib_wp: Vector2 = center + axis_w * trib_x0
	var trib_dy: float = TerrainHeight.active_height(trib_wp.x, trib_wp.y) - base_y
	var concrete_col: Color = Color(0.76, 0.75, 0.72)
	var wall_col: Color = Color(0.68, 0.67, 0.64)
	var seat_col: Color = Color(0.14, 0.22, 0.46)
	for r: int in rows_n:
		var rx: float = trib_x0 + float(r) * step_d
		var rh: float = float(r + 1) * step_h
		_add_colored_box(mst, Vector3(step_d, rh, trib_len), Vector3(rx + step_d * 0.5, trib_dy + rh * 0.5, 0.0), concrete_col)
		_add_colored_box(mst, Vector3(0.45, 0.08, trib_len - 1.2), Vector3(rx + step_d * 0.45, trib_dy + rh + 0.04, 0.0), seat_col)
	var total_d: float = float(rows_n) * step_d
	var top_h: float = float(rows_n) * step_h
	_add_colored_box(mst, Vector3(0.35, 1.0, trib_len), Vector3(trib_x0 + total_d + 0.15, trib_dy + top_h + 0.5, 0.0), wall_col)
	for sz: float in [-1.0, 1.0]:
		_add_colored_box(mst, Vector3(total_d + 0.35, top_h * 0.5 + 0.4, 0.3), Vector3(trib_x0 + total_d * 0.5, trib_dy + top_h * 0.25 + 0.2, sz * (trib_len * 0.5 + 0.15)), wall_col)

	mst.generate_normals()
	var struct_mesh: ArrayMesh = mst.commit()
	var struct_mat: StandardMaterial3D = StandardMaterial3D.new()
	struct_mat.vertex_color_use_as_albedo = true
	struct_mat.roughness = 0.85
	struct_mesh.surface_set_material(0, struct_mat)
	var struct_mi: MeshInstance3D = MeshInstance3D.new()
	struct_mi.name = "StadiumStructures"
	struct_mi.mesh = struct_mesh
	root.add_child(struct_mi)

	# Tribün çarpışması
	var bleachers: StaticBody3D = StaticBody3D.new()
	bleachers.name = "StadiumBleachers"
	var col: CollisionShape3D = CollisionShape3D.new()
	var bshape: BoxShape3D = BoxShape3D.new()
	bshape.size = Vector3(total_d + 0.35, top_h + 1.0, trib_len)
	col.shape = bshape
	col.position = Vector3(trib_x0 + total_d * 0.5, trib_dy + (top_h + 1.0) * 0.5, 0.0)
	bleachers.add_child(col)
	root.add_child(bleachers)


## Stadyum pistinin gerçek merkezini, ana eksenlerini (~15° dönük) ve yarı-boyutlarını hesaplar.
static func _stadium_frame(inner: Array, outer: Array) -> Dictionary:
	var center: Vector2 = Vector2.ZERO
	for p: Array in inner:
		center += Vector2(float(p[0]), float(p[1]))
	center /= maxf(1.0, float(inner.size()))

	# En uzak iki nokta çifti = ovalin uzun ekseni
	var best_d_sq: float = -1.0
	var axis_l: Vector2 = Vector2(0.0, 1.0)
	for i: int in inner.size():
		var pi: Vector2 = Vector2(float(inner[i][0]), float(inner[i][1]))
		for j: int in range(i + 1, inner.size()):
			var pj: Vector2 = Vector2(float(inner[j][0]), float(inner[j][1]))
			var d_sq: float = pi.distance_squared_to(pj)
			if d_sq > best_d_sq:
				best_d_sq = d_sq
				axis_l = (pj - pi).normalized()

	# Sağ el koordinat sistemi: +axis_w doğuya (Taşbina, +X) baksın
	var axis_w: Vector2 = Vector2(axis_l.y, -axis_l.x)
	if axis_w.x < 0.0:
		axis_w = -axis_w
		axis_l = -axis_l

	var in_hw: float = 0.0
	var in_hl: float = 0.0
	for p: Array in inner:
		var rel: Vector2 = Vector2(float(p[0]), float(p[1])) - center
		in_hw = maxf(in_hw, absf(rel.dot(axis_w)))
		in_hl = maxf(in_hl, absf(rel.dot(axis_l)))
	var out_hw: float = 0.0
	var out_hl: float = 0.0
	for p: Array in outer:
		var rel: Vector2 = Vector2(float(p[0]), float(p[1])) - center
		out_hw = maxf(out_hw, absf(rel.dot(axis_w)))
		out_hl = maxf(out_hl, absf(rel.dot(axis_l)))

	return {
		"center": center,
		"axis_w": axis_w,
		"axis_l": axis_l,
		"in_hw": in_hw,
		"in_hl": in_hl,
		"out_hw": out_hw,
		"out_hl": out_hl,
	}


static func _add_colored_box(st: SurfaceTool, size: Vector3, pos: Vector3, color: Color) -> void:
	var h: Vector3 = size * 0.5
	var v000: Vector3 = pos + Vector3(-h.x, -h.y, -h.z)
	var v100: Vector3 = pos + Vector3(h.x, -h.y, -h.z)
	var v110: Vector3 = pos + Vector3(h.x, h.y, -h.z)
	var v010: Vector3 = pos + Vector3(-h.x, h.y, -h.z)
	var v001: Vector3 = pos + Vector3(-h.x, -h.y, h.z)
	var v101: Vector3 = pos + Vector3(h.x, -h.y, h.z)
	var v111: Vector3 = pos + Vector3(h.x, h.y, h.z)
	var v011: Vector3 = pos + Vector3(-h.x, h.y, h.z)
	var faces: Array = [
		[v001, v101, v111, v011],  # +Z
		[v100, v000, v010, v110],  # -Z
		[v101, v100, v110, v111],  # +X
		[v000, v001, v011, v010],  # -X
		[v011, v111, v110, v010],  # +Y
		[v000, v100, v101, v001],  # -Y
	]
	st.set_color(color)
	for f: Array in faces:
		st.add_vertex(f[0])
		st.add_vertex(f[2])
		st.add_vertex(f[1])
		st.add_vertex(f[0])
		st.add_vertex(f[3])
		st.add_vertex(f[2])


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


## Ortabahçe yuvarlak kafe/büfe pavyonu (dji_0114 drone referansı):
## Geniş dairesel gri saçak çatı, koyu cam + ahşap gövde, 8 ince çelik direk, dairesel taş platform ve 2 otomat.
## Tüm parçalar tek köşe-renkli ArrayMesh'te birleşir (= 1 çizim çağrısı).
func _build_kiosk(pos: Vector3, yaw: float) -> void:
	var root: StaticBody3D = StaticBody3D.new()
	root.name = "Kiosk"
	root.position = pos
	root.rotation.y = yaw

	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)

	var base_col: Color = Color(0.76, 0.74, 0.70)
	var core_dark: Color = Color(0.16, 0.20, 0.24)
	var glass_col: Color = Color(0.14, 0.22, 0.28)
	var wood_col: Color = Color(0.56, 0.34, 0.22)
	var roof_col: Color = Color(0.62, 0.64, 0.66)
	var fascia_col: Color = Color(0.26, 0.28, 0.31)
	var post_col: Color = Color(0.24, 0.26, 0.29)
	var red_accent: Color = Color(0.72, 0.16, 0.16)

	# 1) Dairesel taş pavyon tabanı (r=4.8m, h=0.14m)
	_add_colored_cyl(st, 4.8, 0.14, Vector3(0.0, 0.07, 0.0), 16, base_col)
	# 2) Alt ahşap/kiremit tezgah bandı (r=3.1m, h=0.95m)
	_add_colored_cyl(st, 3.1, 0.95, Vector3(0.0, 0.14 + 0.475, 0.0), 14, wood_col)
	# 3) Üst koyu cam vitrin gövdesi (r=3.02m, h=1.85m)
	_add_colored_cyl(st, 3.02, 1.85, Vector3(0.0, 1.09 + 0.925, 0.0), 14, glass_col)
	# 4) Üst koyu alınlık halkası + geniş dairesel saçak çatı (r=4.7m)
	_add_colored_cyl(st, 3.15, 0.22, Vector3(0.0, 2.94 + 0.11, 0.0), 14, core_dark)
	_add_colored_cyl(st, 4.75, 0.24, Vector3(0.0, 3.16 + 0.12, 0.0), 16, fascia_col)
	_add_colored_cyl(st, 4.65, 0.10, Vector3(0.0, 3.40 + 0.05, 0.0), 16, roof_col)
	# Çatı üstü klima / ışıklık kutusu
	_add_colored_box(st, Vector3(1.8, 0.42, 1.4), Vector3(0.0, 3.68, 0.0), Color(0.72, 0.74, 0.76))
	# 5) 8 adet ince saçak taşıyıcı çelik direk
	for i: int in 8:
		var ang: float = TAU * float(i) / 8.0
		var px: float = cos(ang) * 4.25
		var pz: float = sin(ang) * 4.25
		_add_colored_box(st, Vector3(0.12, 3.05, 0.12), Vector3(px, 0.14 + 1.525, pz), post_col)
	# 6) Kırmızı büfe tabelası / otomat çifti (giriş yanında)
	for sx: float in [-0.55, 0.55]:
		_add_colored_box(st, Vector3(0.85, 1.85, 0.70), Vector3(sx, 0.14 + 0.925, 3.45), red_accent)
		_add_colored_box(st, Vector3(0.62, 1.05, 0.06), Vector3(sx, 0.14 + 1.18, 3.81), Color(0.88, 0.92, 0.96))

	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.78
	mesh.surface_set_material(0, mat)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "KioskMesh"
	mi.mesh = mesh
	root.add_child(mi)

	var col: CollisionShape3D = CollisionShape3D.new()
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = 3.25
	shape.height = 3.4
	col.shape = shape
	col.position = Vector3(0.0, 1.7, 0.0)
	root.add_child(col)
	add_child(root)
	kiosk_count += 1


## Ortabahçe merkez anıt meydanı (dji_0081 referansı): dairesel basamaklı taş platform + granit kaide + bronz anıt.
func _build_ortabahce_monument(xz: Vector2) -> void:
	var base_y: float = TerrainHeight.active_height(xz.x, xz.y)
	var root: StaticBody3D = StaticBody3D.new()
	root.name = "OrtabahceMonument"
	root.position = Vector3(xz.x, base_y, xz.y)

	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)

	var plaza_stone: Color = Color(0.84, 0.82, 0.78)
	var step_stone: Color = Color(0.74, 0.72, 0.69)
	var granite: Color = Color(0.56, 0.55, 0.53)
	var bronze: Color = Color(0.24, 0.22, 0.19)
	var gold: Color = Color(0.86, 0.68, 0.22)

	# Geniş dairesel taş meydan + 2 basamaklı kaide (yolun üstüne temiz oturur)
	_add_colored_cyl(st, 3.8, 0.14, Vector3(0.0, 0.07, 0.0), 20, plaza_stone)
	_add_colored_cyl(st, 2.2, 0.24, Vector3(0.0, 0.14 + 0.12, 0.0), 16, step_stone)
	_add_colored_box(st, Vector3(1.55, 1.55, 1.55), Vector3(0.0, 0.38 + 0.775, 0.0), granite)
	_add_colored_box(st, Vector3(1.72, 0.16, 1.72), Vector3(0.0, 1.93 + 0.08, 0.0), step_stone)
	# Bronz anıt sütun + üstünde oturan altın YTÜ yıldız tacı
	_add_colored_box(st, Vector3(0.75, 2.05, 0.75), Vector3(0.0, 2.09 + 1.025, 0.0), bronze)
	_add_colored_box(st, Vector3(0.95, 0.16, 0.95), Vector3(0.0, 4.14 + 0.08, 0.0), bronze)
	_add_colored_box(st, Vector3(0.24, 0.35, 0.24), Vector3(0.0, 4.30 + 0.175, 0.0), bronze)
	_add_colored_box(st, Vector3(0.62, 0.62, 0.16), Vector3(0.0, 4.65 + 0.22, 0.0), gold)
	_add_colored_box(st, Vector3(0.16, 0.62, 0.62), Vector3(0.0, 4.65 + 0.22, 0.0), gold)

	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.72
	mesh.surface_set_material(0, mat)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "MonumentMesh"
	mi.mesh = mesh
	root.add_child(mi)

	var col: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(1.8, 3.0, 1.8)
	col.shape = shape
	col.position = Vector3(0.0, 1.5, 0.0)
	root.add_child(col)
	add_child(root)


static func _add_colored_cyl(st: SurfaceTool, radius: float, height: float, pos: Vector3, segs: int, color: Color) -> void:
	var y0: float = pos.y - height * 0.5
	var y1: float = pos.y + height * 0.5
	var top_c: Vector3 = Vector3(pos.x, y1, pos.z)
	var bot_c: Vector3 = Vector3(pos.x, y0, pos.z)
	st.set_color(color)
	for i: int in segs:
		var a0: float = TAU * float(i) / float(segs)
		var a1: float = TAU * float(i + 1) / float(segs)
		var p00: Vector3 = Vector3(pos.x + cos(a0) * radius, y0, pos.z + sin(a0) * radius)
		var p10: Vector3 = Vector3(pos.x + cos(a1) * radius, y0, pos.z + sin(a1) * radius)
		var p01: Vector3 = Vector3(pos.x + cos(a0) * radius, y1, pos.z + sin(a0) * radius)
		var p11: Vector3 = Vector3(pos.x + cos(a1) * radius, y1, pos.z + sin(a1) * radius)
		# Yan yüz (dışarı bakan — Godot sağ el +Y ekseninde a0->a1 saat yönünde döner)
		st.add_vertex(p00)
		st.add_vertex(p11)
		st.add_vertex(p01)
		st.add_vertex(p00)
		st.add_vertex(p10)
		st.add_vertex(p11)
		# Üst kapak (+Y)
		st.add_vertex(top_c)
		st.add_vertex(p01)
		st.add_vertex(p11)
		# Alt kapak (-Y)
		st.add_vertex(bot_c)
		st.add_vertex(p10)
		st.add_vertex(p00)
