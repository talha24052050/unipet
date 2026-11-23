extends Node3D
## Elektrik-Elektronik Fakültesi (EEF) önü meydanı, giriş tabelası, YTÜ mavi-gümüş totemi,
## sol taş istinat duvarı/bankları ve sağ bisiklet parkı + bordo şemsiyeli kafe terası.
## Referans: YTÜ resmi EEF ön cephe fotoğrafı (elektrik-elektronik-fakultesi.jpg).
## Tüm statik kütleler tek köşe-renkli ArrayMesh'te birleştirilir (mobil dostu düşük çizim çağrısı).

# EEF (b#4) ana giriş girintisi (edge 19..20 orta noktası, path#17 & path#18 bağlantı noktası)
const EEF_ENTRY_MID: Vector2 = Vector2(46.81, -244.64)
const EEF_OUT: Vector2 = Vector2(-0.620, 0.785)  # +Z: binadan dışarı, yaklaşma yoluna doğru

const COL_ALUCOBOND: Color = Color(0.88, 0.90, 0.91)
const COL_WHITE: Color = Color(0.93, 0.94, 0.94)
const COL_DARK_FRAME: Color = Color(0.16, 0.19, 0.22)
const COL_GLASS_TINT: Color = Color(0.24, 0.34, 0.36)
const COL_STONE_LIGHT: Color = Color(0.56, 0.56, 0.54)
const COL_STONE_DARK: Color = Color(0.42, 0.43, 0.41)
const COL_YTU_BLUE: Color = Color(0.06, 0.16, 0.48)
const COL_SILVER: Color = Color(0.84, 0.86, 0.89)
const COL_GOLD: Color = Color(0.86, 0.68, 0.22)
const COL_WOOD: Color = Color(0.42, 0.26, 0.15)
const COL_BURGUNDY: Color = Color(0.26, 0.04, 0.06)
const COL_METAL: Color = Color(0.22, 0.24, 0.27)
const COL_PLAZA_PAVER: Color = Color(0.46, 0.48, 0.50)


func _ready() -> void:
	build()


func build() -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)

	var col_body: StaticBody3D = StaticBody3D.new()
	col_body.name = "EefCollisions"
	add_child(col_body)

	var out: Vector2 = EEF_OUT.normalized()
	# Binaya yüzümüz dönükken: +X = SAĞ (totem/kafe/bisiklet parkı), -X = SOL (istinat duvarı/bank)
	# Yani bina referansında across = (out.y, -out.x) soldan sağa giderken, binaya bakan kişi için tersidir;
	# buradaki across'u binaya bakan kişinin SAĞINA (+X = (out.y, -out.x) mı? Kontrol: out=(-0.62, 0.785) ->
	# (-out.y, out.x) = (-0.785, -0.620) = SOLA (26, -260), (out.y, -out.x) = (0.785, 0.620) = SAĞA (61, -233)!).
	var right_dir: Vector2 = Vector2(out.y, -out.x)

	_build_entrance_facade(st, right_dir, out)
	_build_ytu_totem(st, col_body, right_dir, out)
	_build_retaining_wall_and_benches(st, col_body, right_dir, out)
	_build_bike_racks_and_cafe(st, col_body, right_dir, out)

	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.82
	mesh.surface_set_material(0, mat)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "EefStructures"
	mi.mesh = mesh
	add_child(mi)


## 1) EEF Ana Giriş Cephesi: beyaz kompozit alınlık, çift cam kapılar, güvenlik kabini ve 3D tabela.
func _build_entrance_facade(st: SurfaceTool, right_dir: Vector2, out: Vector2) -> void:
	var base_y: float = TerrainHeight.active_height(EEF_ENTRY_MID.x, EEF_ENTRY_MID.y)
	var xf: Transform3D = _frame_xform(EEF_ENTRY_MID, right_dir, out, base_y)

	# Giriş önü taş döşeli karşılama alanı (eef_front.jpg)
	_add_box_xf(st, xf, Vector3(15.0, 0.10, 7.5), Vector3(0.0, 0.05, 3.8), COL_PLAZA_PAVER)
	# Giriş üstü geniş beyaz kompozit alınlık (eef_front.jpg'deki "ELEKTRİK - ELEKTRONİK FAKÜLTESİ" bandı)
	_add_box_xf(st, xf, Vector3(13.6, 1.15, 0.32), Vector3(0.0, 3.45, 0.18), COL_ALUCOBOND)
	# Çift cam giriş kapıları (sol ve sağ kapı grupları + ortada beyaz taşıyıcı kolon)
	_add_box_xf(st, xf, Vector3(1.1, 2.95, 0.36), Vector3(0.0, 1.475, 0.20), COL_WHITE)
	for side_x: float in [-3.4, 3.4]:
		_add_box_xf(st, xf, Vector3(5.2, 2.88, 0.24), Vector3(side_x, 1.44, 0.14), COL_DARK_FRAME)
		_add_box_xf(st, xf, Vector3(4.8, 2.65, 0.12), Vector3(side_x, 1.42, 0.22), COL_GLASS_TINT)
		for mx: float in [-1.5, 0.0, 1.5]:
			_add_box_xf(st, xf, Vector3(0.08, 2.65, 0.16), Vector3(side_x + mx, 1.42, 0.24), COL_WHITE)
	# Sol tarafta küçük beyaz güvenlik/danışma kabini (eef_front.jpg'de sol kapının hemen önünde)
	_add_box_xf(st, xf, Vector3(1.15, 2.25, 1.15), Vector3(-2.6, 1.125, 1.65), COL_WHITE)
	_add_box_xf(st, xf, Vector3(0.85, 0.95, 1.18), Vector3(-2.6, 1.45, 1.65), COL_GLASS_TINT)

	# 3D "ELEKTRİK - ELEKTRONİK FAKÜLTESİ" cephe tabelası
	var sign_root: Node3D = Node3D.new()
	sign_root.name = "EefFacadeSign"
	sign_root.transform = xf * Transform3D(Basis.IDENTITY, Vector3(0.0, 3.48, 0.36))
	add_child(sign_root)
	var tm: TextMesh = TextMesh.new()
	tm.text = "ELEKTRİK - ELEKTRONİK FAKÜLTESİ"
	tm.font_size = 48
	tm.pixel_size = 0.0082
	tm.depth = 0.07
	tm.curve_step = 2.5
	var tmat: StandardMaterial3D = StandardMaterial3D.new()
	tmat.albedo_color = COL_DARK_FRAME
	tmat.roughness = 0.45
	tm.material = tmat
	var tmi: MeshInstance3D = MeshInstance3D.new()
	tmi.mesh = tm
	tmi.visibility_range_end = 110.0
	sign_root.add_child(tmi)


## 2) İkonik YTÜ Mavi-Gümüş Fakülte Totemi (yaklaşma yolunun sağ kenarında, eef_front.jpg ön plan).
func _build_ytu_totem(st: SurfaceTool, col_body: StaticBody3D, right_dir: Vector2, out: Vector2) -> void:
	var wp: Vector2 = EEF_ENTRY_MID + out * 20.5 + right_dir * 4.8
	var ty: float = TerrainHeight.active_height(wp.x, wp.y)
	var xf: Transform3D = _frame_xform(wp, right_dir, out, ty)

	# Beton zemin kaidesi
	_add_box_xf(st, xf, Vector3(1.65, 0.22, 0.55), Vector3(0.0, 0.11, 0.0), COL_STONE_DARK)
	# Alt YTÜ kraliyet mavisi gövde (2.15 m)
	_add_box_xf(st, xf, Vector3(1.48, 2.15, 0.28), Vector3(0.0, 0.22 + 1.075, 0.0), COL_YTU_BLUE)
	# Üst gümüş-beyaz başlık + kavisli üst taç (1.15 m)
	_add_box_xf(st, xf, Vector3(1.48, 1.08, 0.28), Vector3(0.0, 2.37 + 0.54, 0.0), COL_SILVER)
	_add_box_xf(st, xf, Vector3(1.18, 0.14, 0.28), Vector3(0.0, 3.50, 0.0), COL_SILVER)
	# Altın/mavi 8 köşeli YTÜ arma madalyonu (iki yüzde de görünsün)
	for face_z: float in [0.15, -0.15]:
		for k: int in 4:
			var ang: float = float(k) * PI * 0.25
			var sxf: Transform3D = xf * Transform3D(Basis(Vector3.BACK, ang), Vector3(0.0, 3.10, face_z))
			_add_box_xf(st, sxf, Vector3(0.38, 0.08, 0.03), Vector3.ZERO, COL_GOLD)

	# Totem yazıları (ön yüzde okunaklı Label3D)
	var lbl_top: Label3D = Label3D.new()
	lbl_top.name = "EefTotemTitle"
	lbl_top.text = "YILDIZ TEKNİK ÜNİVERSİTESİ\nYILDIZ TECHNICAL UNIVERSITY"
	lbl_top.font_size = 28
	lbl_top.pixel_size = 0.0026
	lbl_top.modulate = Color(0.12, 0.18, 0.34)
	lbl_top.visibility_range_end = 95.0
	lbl_top.transform = xf * Transform3D(Basis.IDENTITY, Vector3(0.0, 2.68, 0.16))
	add_child(lbl_top)

	var lbl_body: Label3D = Label3D.new()
	lbl_body.name = "EefTotemBody"
	lbl_body.text = "ELEKTRİK - ELEKTRONİK\nFAKÜLTESİ\n\n• Bilgisayar Mühendisliği\n• Elektrik Mühendisliği\n• Elektronik ve Haberleşme\n• Kontrol ve Otomasyon"
	lbl_body.font_size = 30
	lbl_body.pixel_size = 0.0027
	lbl_body.modulate = Color(0.98, 0.94, 0.72)
	lbl_body.outline_size = 4
	lbl_body.outline_modulate = Color(0.08, 0.15, 0.35)
	lbl_body.visibility_range_end = 95.0
	lbl_body.transform = xf * Transform3D(Basis.IDENTITY, Vector3(0.0, 1.48, 0.16))
	add_child(lbl_body)

	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "EefTotemCollider"
	var sh: BoxShape3D = BoxShape3D.new()
	sh.size = Vector3(1.65, 3.6, 0.55)
	col.shape = sh
	col.transform = xf * Transform3D(Basis.IDENTITY, Vector3(0.0, 1.8, 0.0))
	col_body.add_child(col)


## 3) Sol kenar: kademeli taş istinat duvarı + ahşap-demir kampüs bankları (eef_front.jpg sol taraf).
func _build_retaining_wall_and_benches(st: SurfaceTool, col_body: StaticBody3D, right_dir: Vector2, out: Vector2) -> void:
	for i: int in 7:
		var dist_out: float = 7.5 + float(i) * 2.4
		var wp: Vector2 = EEF_ENTRY_MID + out * dist_out - right_dir * 7.8
		var wy: float = TerrainHeight.active_height(wp.x, wp.y)
		var xf: Transform3D = _frame_xform(wp, right_dir, out, wy)
		# 3 sıra kademeli taş blok duvar (eğimli yamaç boyunca)
		var c1: Color = COL_STONE_LIGHT if (i % 2 == 0) else COL_STONE_DARK
		var c2: Color = COL_STONE_DARK if (i % 2 == 0) else COL_STONE_LIGHT
		_add_box_xf(st, xf, Vector3(0.65, 0.42, 2.32), Vector3(-0.35, 0.21, 0.0), c1)
		_add_box_xf(st, xf, Vector3(0.65, 0.42, 2.32), Vector3(-0.55, 0.63, 0.0), c2)
		_add_box_xf(st, xf, Vector3(0.65, 0.36, 2.32), Vector3(-0.75, 1.02, 0.0), c1)

	# İstinat duvarı önünde 2 adet ahşap-demir kampüs bankı
	for d_bench: float in [11.5, 18.5]:
		var bp: Vector2 = EEF_ENTRY_MID + out * d_bench - right_dir * 6.8
		var by: float = TerrainHeight.active_height(bp.x, bp.y)
		# Bank yola (sağa, +right_dir) baksın
		var bxf: Transform3D = _frame_xform(bp, out, right_dir, by)
		_add_box_xf(st, bxf, Vector3(2.1, 0.09, 0.52), Vector3(0.0, 0.46, 0.0), COL_WOOD)
		_add_box_xf(st, bxf, Vector3(2.1, 0.40, 0.08), Vector3(0.0, 0.72, -0.22), COL_WOOD)
		for lx: float in [-0.82, 0.82]:
			_add_box_xf(st, bxf, Vector3(0.08, 0.46, 0.46), Vector3(lx, 0.23, 0.0), COL_METAL)
		var bcol: CollisionShape3D = CollisionShape3D.new()
		var bsh: BoxShape3D = BoxShape3D.new()
		bsh.size = Vector3(2.1, 0.85, 0.6)
		bcol.shape = bsh
		bcol.transform = bxf * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.425, 0.0))
		col_body.add_child(bcol)


## 4) Sağ kenar: kavisli metal bisiklet park demirleri + bordo şemsiyeli açık hava kafe terası.
func _build_bike_racks_and_cafe(st: SurfaceTool, col_body: StaticBody3D, right_dir: Vector2, out: Vector2) -> void:
	# 5 adet bisiklet park kemeri (yolun sağ şeridi boyunca)
	for i: int in 5:
		var rp: Vector2 = EEF_ENTRY_MID + out * (11.0 + float(i) * 1.45) + right_dir * 4.4
		var ry: float = TerrainHeight.active_height(rp.x, rp.y)
		var rxf: Transform3D = _frame_xform(rp, right_dir, out, ry)
		_add_box_xf(st, rxf, Vector3(1.15, 0.07, 0.07), Vector3(0.0, 0.78, 0.0), COL_METAL)
		for sx: float in [-0.54, 0.54]:
			_add_box_xf(st, rxf, Vector3(0.07, 0.78, 0.07), Vector3(sx, 0.39, 0.0), COL_METAL)

	# Sağ tarafta bordo şemsiyeli açık hava kafe masaları (yolun sağındaki açık cephe terasında, yolu kapatmaz)
	var cafe_offsets: Array[Vector2] = [
		Vector2(14.5, 4.8),
		Vector2(18.2, 6.2),
		Vector2(15.2, 9.6),
	]
	for off: Vector2 in cafe_offsets:
		var cp: Vector2 = EEF_ENTRY_MID + right_dir * off.x + out * off.y
		var cy: float = TerrainHeight.active_height(cp.x, cp.y)
		var cxf: Transform3D = _frame_xform(cp, right_dir, out, cy)
		# Ahşap piknik/kafe masası + iki yanında oturak
		_add_box_xf(st, cxf, Vector3(1.45, 0.08, 0.95), Vector3(0.0, 0.76, 0.0), COL_WOOD)
		_add_box_xf(st, cxf, Vector3(0.14, 0.74, 0.14), Vector3(0.0, 0.37, 0.0), COL_METAL)
		for sz: float in [-0.72, 0.72]:
			_add_box_xf(st, cxf, Vector3(1.35, 0.07, 0.34), Vector3(0.0, 0.44, sz), COL_WOOD)
		# Koyu bordo şemsiye (direk + geniş 2 katmanlı çatı)
		_add_box_xf(st, cxf, Vector3(0.08, 2.55, 0.08), Vector3(0.0, 1.275, 0.0), COL_METAL)
		_add_box_xf(st, cxf, Vector3(2.45, 0.22, 2.45), Vector3(0.0, 2.52, 0.0), COL_BURGUNDY)
		_add_box_xf(st, cxf, Vector3(1.35, 0.18, 1.35), Vector3(0.0, 2.70, 0.0), COL_BURGUNDY)
		var ccol: CollisionShape3D = CollisionShape3D.new()
		var csh: BoxShape3D = BoxShape3D.new()
		csh.size = Vector3(1.5, 1.2, 1.6)
		ccol.shape = csh
		ccol.transform = cxf * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.6, 0.0))
		col_body.add_child(ccol)


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
