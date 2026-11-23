extends Node3D
## Kampüsün diğer ikonik yapıları: Otağ-ı Hümayun (1483), Şehit Prof. Dr. İlhan Varank Kütüphanesi,
## Yeni Merkez Kütüphanesi ve Fen-Edebiyat Fakültesi giriş cepheleri, meydanları ve YTÜ totemleri.
## Tüm statik kütleler tek köşe-renkli ArrayMesh'te birleştirilir (mobil dostu 1 çizim çağrısı).

const COL_LIMESTONE: Color = Color(0.76, 0.74, 0.69)
const COL_STONE_DARK: Color = Color(0.46, 0.45, 0.42)
const COL_WATER: Color = Color(0.16, 0.44, 0.56)
const COL_BRONZE: Color = Color(0.24, 0.21, 0.17)
const COL_GOLD: Color = Color(0.86, 0.68, 0.22)
const COL_WOOD: Color = Color(0.42, 0.26, 0.15)
const COL_ANTHRACITE: Color = Color(0.15, 0.17, 0.20)
const COL_ALUCOBOND: Color = Color(0.88, 0.90, 0.91)
const COL_WHITE: Color = Color(0.93, 0.94, 0.94)
const COL_GLASS: Color = Color(0.20, 0.30, 0.36)
const COL_YTU_BLUE: Color = Color(0.06, 0.16, 0.48)
const COL_SILVER: Color = Color(0.84, 0.86, 0.89)
const COL_PAVER: Color = Color(0.45, 0.47, 0.49)


func _ready() -> void:
	build()


func build() -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)

	var col_body: StaticBody3D = StaticBody3D.new()
	col_body.name = "LandmarkCollisions"
	add_child(col_body)

	_build_otag_i_humayun(st, col_body)
	_build_ilhan_varank_library(st, col_body)
	_build_merkez_library(st, col_body)
	_build_fen_edebiyat(st, col_body)

	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.82
	mesh.surface_set_material(0, mat)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "LandmarkStructures"
	mi.mesh = mesh
	add_child(mi)


## 1) Otağ-ı Hümayun (b#81, 1483): kesme taş kemerli giriş portali, sekizgen Osmanlı şadırvan/havuzu ve tarihi levha.
func _build_otag_i_humayun(st: SurfaceTool, col_body: StaticBody3D) -> void:
	var mid: Vector2 = Vector2(435.5, 263.1)
	var out: Vector2 = Vector2(-0.24, 0.97).normalized()
	var right_dir: Vector2 = Vector2(out.y, -out.x)
	var base_y: float = TerrainHeight.active_height(mid.x, mid.y)
	var xf: Transform3D = _frame_xform(mid, right_dir, out, base_y)

	# Kesme taş giriş portali + koyu ahşap/demir kapı + 3 taş basamak
	_add_box_xf(st, xf, Vector3(4.6, 4.4, 0.55), Vector3(0.0, 2.2, 0.25), COL_LIMESTONE)
	_add_box_xf(st, xf, Vector3(4.9, 0.28, 0.72), Vector3(0.0, 4.45, 0.28), COL_STONE_DARK)
	_add_box_xf(st, xf, Vector3(2.8, 3.2, 0.22), Vector3(0.0, 1.8, 0.48), COL_BRONZE)
	_add_box_xf(st, xf, Vector3(0.10, 3.2, 0.28), Vector3(0.0, 1.8, 0.52), COL_GOLD)
	for i: int in 3:
		var sh: float = 0.54 - float(i) * 0.18
		_add_box_xf(st, xf, Vector3(5.2 + float(i) * 0.5, sh, 0.45), Vector3(0.0, sh * 0.5, 0.75 + float(i) * 0.45), COL_LIMESTONE)

	# Avlu önü sekizgen Osmanlı süs havuzu (yolun kenarından içeri, avlunun tam önünde)
	var pool_wp: Vector2 = mid + out * 4.8
	var pool_y: float = TerrainHeight.active_height(pool_wp.x, pool_wp.y)
	var pxf: Transform3D = _frame_xform(pool_wp, right_dir, out, pool_y)
	_add_cyl_xf(st, pxf, 3.6, 0.14, Vector3(0.0, 0.07, 0.0), 12, COL_PAVER)
	_add_cyl_xf(st, pxf, 2.35, 0.56, Vector3(0.0, 0.14 + 0.28, 0.0), 8, COL_LIMESTONE)
	_add_cyl_xf(st, pxf, 1.98, 0.06, Vector3(0.0, 0.14 + 0.57, 0.0), 8, COL_WATER)
	# Havuz ortası taş fıskiye çanağı
	_add_cyl_xf(st, pxf, 0.30, 1.05, Vector3(0.0, 0.65, 0.0), 8, COL_LIMESTONE)
	_add_cyl_xf(st, pxf, 0.72, 0.16, Vector3(0.0, 1.20, 0.0), 8, COL_LIMESTONE)
	_add_cyl_xf(st, pxf, 0.18, 0.34, Vector3(0.0, 1.44, 0.0), 8, COL_BRONZE)

	var pcol: CollisionShape3D = CollisionShape3D.new()
	pcol.name = "OtagPoolCollider"
	var psh: CylinderShape3D = CylinderShape3D.new()
	psh.radius = 2.35
	psh.height = 0.8
	pcol.shape = psh
	pcol.position = Vector3(pool_wp.x, pool_y + 0.4, pool_wp.y)
	col_body.add_child(pcol)

	# Tarihi bronz-taş kitabe levhası (sağ köşede)
	var pl_wp: Vector2 = mid + out * 4.5 + right_dir * 4.8
	var pl_y: float = TerrainHeight.active_height(pl_wp.x, pl_wp.y)
	var pl_xf: Transform3D = _frame_xform(pl_wp, right_dir, out, pl_y)
	_add_box_xf(st, pl_xf, Vector3(1.55, 0.20, 0.55), Vector3(0.0, 0.10, 0.0), COL_STONE_DARK)
	_add_box_xf(st, pl_xf, Vector3(1.38, 1.75, 0.22), Vector3(0.0, 0.20 + 0.875, 0.0), COL_BRONZE)
	_add_box_xf(st, pl_xf, Vector3(1.48, 0.12, 0.28), Vector3(0.0, 2.00, 0.0), COL_GOLD)
	_add_label(pl_xf, Vector3(0.0, 1.25, 0.14), "OtagPlaque", "OTAĞ-I HÜMAYUN\n1483\nDavutpaşa Hünkar Kasrı", 30, 0.0028, COL_GOLD, Color(0.1, 0.08, 0.05))
	_add_bench(st, col_body, mid + out * 4.5 - right_dir * 4.8, out, right_dir)


## 2) Şehit Prof. Dr. İlhan Varank Kütüphanesi (b#0): cam giriş kanopisi, 3D tabela ve YTÜ totemi.
func _build_ilhan_varank_library(st: SurfaceTool, col_body: StaticBody3D) -> void:
	var mid: Vector2 = Vector2(385.9, 471.0)
	var out: Vector2 = Vector2(-1.00, -0.03).normalized()
	var right_dir: Vector2 = Vector2(out.y, -out.x)
	var base_y: float = TerrainHeight.active_height(mid.x, mid.y)
	var xf: Transform3D = _frame_xform(mid, right_dir, out, base_y)

	_add_box_xf(st, xf, Vector3(14.0, 0.12, 7.5), Vector3(0.0, 0.06, 3.8), COL_PAVER)
	_add_box_xf(st, xf, Vector3(11.6, 1.10, 0.35), Vector3(0.0, 3.85, 0.20), COL_ALUCOBOND)
	_add_box_xf(st, xf, Vector3(9.6, 0.18, 3.4), Vector3(0.0, 3.45, 1.75), COL_ANTHRACITE)
	for sx: float in [-4.2, 4.2]:
		_add_box_xf(st, xf, Vector3(0.24, 3.45, 0.24), Vector3(sx, 1.725, 3.15), COL_ANTHRACITE)
	_add_box_xf(st, xf, Vector3(7.4, 3.1, 0.20), Vector3(0.0, 1.55, 0.12), COL_ANTHRACITE)
	_add_box_xf(st, xf, Vector3(6.8, 2.85, 0.10), Vector3(0.0, 1.52, 0.20), COL_GLASS)
	for mx: float in [-2.0, 0.0, 2.0]:
		_add_box_xf(st, xf, Vector3(0.09, 2.85, 0.15), Vector3(mx, 1.52, 0.22), COL_WHITE)
	_add_box_xf(st, xf, Vector3(6.8, 0.09, 0.15), Vector3(0.0, 2.25, 0.22), COL_WHITE)
	_add_3d_sign(xf, Vector3(0.0, 3.88, 0.40), "IlhanVarankSign", "İLHAN VARANK KÜTÜPHANESİ", 0.34, COL_ANTHRACITE)
	_build_ytu_totem(st, col_body, mid + out * 10.5 + right_dir * 5.8, right_dir, out, "IlhanVarankTotem", "ŞEHİT PROF. DR.\nİLHAN VARANK\nKÜTÜPHANESİ\n\n7/24 Çalışma Salonu")
	_add_bench(st, col_body, mid + out * 5.5 - right_dir * 5.2, right_dir, out)


## 3) Yeni Merkez Kütüphanesi (b#139): modern cam cephe girişi, koyu kanopi ve çalışma bankları.
func _build_merkez_library(st: SurfaceTool, col_body: StaticBody3D) -> void:
	var mid: Vector2 = Vector2(-84.3, -157.8)
	var out: Vector2 = Vector2(-0.59, 0.81).normalized()
	var right_dir: Vector2 = Vector2(out.y, -out.x)
	var base_y: float = TerrainHeight.active_height(mid.x, mid.y)
	var xf: Transform3D = _frame_xform(mid, right_dir, out, base_y)

	_add_box_xf(st, xf, Vector3(16.0, 0.12, 8.0), Vector3(0.0, 0.06, 4.1), COL_PAVER)
	_add_box_xf(st, xf, Vector3(12.2, 1.15, 0.35), Vector3(0.0, 3.95, 0.20), COL_WHITE)
	_add_box_xf(st, xf, Vector3(10.8, 0.22, 3.6), Vector3(0.0, 3.55, 1.85), COL_ANTHRACITE)
	for sx: float in [-4.8, 4.8]:
		_add_box_xf(st, xf, Vector3(0.26, 3.55, 0.26), Vector3(sx, 1.775, 3.35), COL_ANTHRACITE)
	_add_box_xf(st, xf, Vector3(8.2, 3.2, 0.20), Vector3(0.0, 1.60, 0.12), COL_ANTHRACITE)
	_add_box_xf(st, xf, Vector3(7.6, 2.95, 0.10), Vector3(0.0, 1.56, 0.20), COL_GLASS)
	for mx: float in [-2.2, 0.0, 2.2]:
		_add_box_xf(st, xf, Vector3(0.09, 2.95, 0.15), Vector3(mx, 1.56, 0.22), COL_WHITE)
	_add_box_xf(st, xf, Vector3(7.6, 0.09, 0.15), Vector3(0.0, 2.30, 0.22), COL_WHITE)
	_add_3d_sign(xf, Vector3(0.0, 3.98, 0.40), "MerkezKutuphaneSign", "MERKEZ KÜTÜPHANESİ", 0.38, COL_ANTHRACITE)
	_add_bench(st, col_body, mid + out * 6.2 - right_dir * 5.2, right_dir, out)
	_add_bench(st, col_body, mid + out * 6.2 + right_dir * 5.2, right_dir, out)


## 4) Fen-Edebiyat Fakültesi (b#9): giriş alınlığı, çift cam kapı ve YTÜ fakülte totemi.
func _build_fen_edebiyat(st: SurfaceTool, col_body: StaticBody3D) -> void:
	var mid: Vector2 = Vector2(155.7, -176.4)
	var out: Vector2 = Vector2(-0.62, 0.79).normalized()
	var right_dir: Vector2 = Vector2(out.y, -out.x)
	var base_y: float = TerrainHeight.active_height(mid.x, mid.y)
	var xf: Transform3D = _frame_xform(mid, right_dir, out, base_y)

	_add_box_xf(st, xf, Vector3(11.0, 0.10, 5.5), Vector3(0.0, 0.05, 2.8), COL_PAVER)
	_add_box_xf(st, xf, Vector3(10.0, 1.05, 0.30), Vector3(0.0, 3.45, 0.16), COL_ALUCOBOND)
	_add_box_xf(st, xf, Vector3(6.8, 2.85, 0.20), Vector3(0.0, 1.425, 0.12), COL_ANTHRACITE)
	_add_box_xf(st, xf, Vector3(6.2, 2.65, 0.10), Vector3(0.0, 1.40, 0.20), COL_GLASS)
	for mx: float in [-1.8, 0.0, 1.8]:
		_add_box_xf(st, xf, Vector3(0.08, 2.65, 0.15), Vector3(mx, 1.40, 0.22), COL_WHITE)
	_add_box_xf(st, xf, Vector3(6.2, 0.08, 0.15), Vector3(0.0, 2.15, 0.22), COL_WHITE)
	_add_3d_sign(xf, Vector3(0.0, 3.48, 0.34), "FenEdebiyatSign", "FEN-EDEBİYAT FAKÜLTESİ", 0.34, COL_ANTHRACITE)
	_build_ytu_totem(st, col_body, mid + out * 8.5 + right_dir * 5.2, right_dir, out, "FenEdebiyatTotem", "FEN-EDEBİYAT\nFAKÜLTESİ\n\n• Matematik • Fizik\n• Kimya • İstatistik\n• Moleküler Biyoloji")


func _build_ytu_totem(st: SurfaceTool, col_body: StaticBody3D, wp: Vector2, right_dir: Vector2, out: Vector2, node_name: String, body_text: String) -> void:
	var ty: float = TerrainHeight.active_height(wp.x, wp.y)
	var xf: Transform3D = _frame_xform(wp, right_dir, out, ty)
	_add_box_xf(st, xf, Vector3(1.55, 0.22, 0.52), Vector3(0.0, 0.11, 0.0), COL_STONE_DARK)
	_add_box_xf(st, xf, Vector3(1.42, 2.05, 0.26), Vector3(0.0, 0.22 + 1.025, 0.0), COL_YTU_BLUE)
	_add_box_xf(st, xf, Vector3(1.42, 1.02, 0.26), Vector3(0.0, 2.27 + 0.51, 0.0), COL_SILVER)
	_add_box_xf(st, xf, Vector3(1.12, 0.12, 0.26), Vector3(0.0, 3.34, 0.0), COL_SILVER)
	for face_z: float in [0.14, -0.14]:
		for k: int in 4:
			var ang: float = float(k) * PI * 0.25
			var sxf: Transform3D = xf * Transform3D(Basis(Vector3.BACK, ang), Vector3(0.0, 2.98, face_z))
			_add_box_xf(st, sxf, Vector3(0.36, 0.08, 0.03), Vector3.ZERO, COL_GOLD)
	_add_label(xf, Vector3(0.0, 2.58, 0.15), node_name + "Title", "YILDIZ TEKNİK ÜNİVERSİTESİ", 26, 0.0024, Color(0.10, 0.16, 0.34), Color.TRANSPARENT)
	_add_label(xf, Vector3(0.0, 1.42, 0.15), node_name + "Body", body_text, 28, 0.0026, Color(0.98, 0.94, 0.72), Color(0.06, 0.14, 0.35))
	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = node_name + "Collider"
	var sh: BoxShape3D = BoxShape3D.new()
	sh.size = Vector3(1.55, 3.4, 0.52)
	col.shape = sh
	col.transform = xf * Transform3D(Basis.IDENTITY, Vector3(0.0, 1.7, 0.0))
	col_body.add_child(col)


func _add_bench(st: SurfaceTool, col_body: StaticBody3D, wp: Vector2, axis_x: Vector2, axis_z: Vector2) -> void:
	var by: float = TerrainHeight.active_height(wp.x, wp.y)
	var xf: Transform3D = _frame_xform(wp, axis_x, axis_z, by)
	_add_box_xf(st, xf, Vector3(2.1, 0.09, 0.52), Vector3(0.0, 0.46, 0.0), COL_WOOD)
	_add_box_xf(st, xf, Vector3(2.1, 0.40, 0.08), Vector3(0.0, 0.72, -0.22), COL_WOOD)
	for lx: float in [-0.82, 0.82]:
		_add_box_xf(st, xf, Vector3(0.08, 0.46, 0.46), Vector3(lx, 0.23, 0.0), COL_ANTHRACITE)
	var bcol: CollisionShape3D = CollisionShape3D.new()
	var bsh: BoxShape3D = BoxShape3D.new()
	bsh.size = Vector3(2.1, 0.85, 0.6)
	bcol.shape = bsh
	bcol.transform = xf * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.425, 0.0))
	col_body.add_child(bcol)


func _add_3d_sign(xf: Transform3D, local_pos: Vector3, node_name: String, text: String, height_m: float, color: Color) -> void:
	var root: Node3D = Node3D.new()
	root.name = node_name
	root.transform = xf * Transform3D(Basis.IDENTITY, local_pos)
	add_child(root)
	var tm: TextMesh = TextMesh.new()
	tm.text = text
	tm.font_size = 48
	tm.pixel_size = height_m / 44.0
	tm.depth = 0.07
	tm.curve_step = 2.5
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.45
	tm.material = mat
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = tm
	mi.visibility_range_end = 110.0
	root.add_child(mi)


func _add_label(xf: Transform3D, local_pos: Vector3, node_name: String, text: String, font_sz: int, px_sz: float, col: Color, outline: Color) -> void:
	var lbl: Label3D = Label3D.new()
	lbl.name = node_name
	lbl.text = text
	lbl.font_size = font_sz
	lbl.pixel_size = px_sz
	lbl.modulate = col
	if outline.a > 0.01:
		lbl.outline_size = 4
		lbl.outline_modulate = outline
	lbl.visibility_range_end = 95.0
	lbl.transform = xf * Transform3D(Basis.IDENTITY, local_pos)
	add_child(lbl)


static func _frame_xform(origin_xz: Vector2, axis_x: Vector2, axis_z: Vector2, y: float) -> Transform3D:
	var b: Basis = Basis(Vector3(axis_x.x, 0.0, axis_x.y), Vector3.UP, Vector3(axis_z.x, 0.0, axis_z.y))
	return Transform3D(b, Vector3(origin_xz.x, y, origin_xz.y))


static func _add_box_xf(st: SurfaceTool, xf: Transform3D, size: Vector3, local_pos: Vector3, color: Color) -> void:
	var h: Vector3 = size * 0.5
	var pts: Array[Vector3] = [
		xf * (local_pos + Vector3(-h.x, -h.y, -h.z)),
		xf * (local_pos + Vector3(h.x, -h.y, -h.z)),
		xf * (local_pos + Vector3(h.x, h.y, -h.z)),
		xf * (local_pos + Vector3(-h.x, h.y, -h.z)),
		xf * (local_pos + Vector3(-h.x, -h.y, h.z)),
		xf * (local_pos + Vector3(h.x, -h.y, h.z)),
		xf * (local_pos + Vector3(h.x, h.y, h.z)),
		xf * (local_pos + Vector3(-h.x, h.y, h.z)),
	]
	var faces: Array = [
		[4, 5, 6, 7], [1, 0, 3, 2], [5, 1, 2, 6],
		[0, 4, 7, 3], [7, 6, 2, 3], [0, 1, 5, 4],
	]
	st.set_color(color)
	for f: Array in faces:
		st.add_vertex(pts[f[0]])
		st.add_vertex(pts[f[2]])
		st.add_vertex(pts[f[1]])
		st.add_vertex(pts[f[0]])
		st.add_vertex(pts[f[3]])
		st.add_vertex(pts[f[2]])


static func _add_cyl_xf(st: SurfaceTool, xf: Transform3D, radius: float, height: float, local_pos: Vector3, segs: int, color: Color) -> void:
	var y0: float = local_pos.y - height * 0.5
	var y1: float = local_pos.y + height * 0.5
	var top_c: Vector3 = xf * Vector3(local_pos.x, y1, local_pos.z)
	var bot_c: Vector3 = xf * Vector3(local_pos.x, y0, local_pos.z)
	st.set_color(color)
	for i: int in segs:
		var a0: float = TAU * float(i) / float(segs)
		var a1: float = TAU * float(i + 1) / float(segs)
		var p00: Vector3 = xf * Vector3(local_pos.x + cos(a0) * radius, y0, local_pos.z + sin(a0) * radius)
		var p10: Vector3 = xf * Vector3(local_pos.x + cos(a1) * radius, y0, local_pos.z + sin(a1) * radius)
		var p01: Vector3 = xf * Vector3(local_pos.x + cos(a0) * radius, y1, local_pos.z + sin(a0) * radius)
		var p11: Vector3 = xf * Vector3(local_pos.x + cos(a1) * radius, y1, local_pos.z + sin(a1) * radius)
		st.add_vertex(p00)
		st.add_vertex(p11)
		st.add_vertex(p01)
		st.add_vertex(p00)
		st.add_vertex(p10)
		st.add_vertex(p11)
		st.add_vertex(top_c)
		st.add_vertex(p01)
		st.add_vertex(p11)
		st.add_vertex(bot_c)
		st.add_vertex(p10)
		st.add_vertex(p00)
