extends Node3D
## Yemekhane önü meydanı, Yıldız Store amfi-oturma merdivenleri ve A101 cephesi.
## Referans: YTÜ Davutpaşa drone ve cephe fotoğrafları (2026-11-24).
## Tüm statik kütleler tek köşe-renkli ArrayMesh'te birleştirilir (~4 çizim çağrısı).

# Yıldız Store (b#40) köşeleri (kampus_greybox.json)
const STORE_P0: Vector2 = Vector2(-104.18, -58.13)  # Doğu (Yemekhane tarafı)
const STORE_P2: Vector2 = Vector2(-151.50, -77.84)  # Batı (A101 yol tarafı)
const STORE_P3: Vector2 = Vector2(-113.01, -47.20)  # Güney (Amfi merdiven köşesi)

# Yemekhane (b#39) ön cephesinin tam ortasındaki giriş bölümü (edge 27+28: [-85.93,-74.82] -> [-81.23,-80.70])
const YEM_FRONT_MID: Vector2 = Vector2(-83.58, -77.76)
const YEM_FRONT_OUT: Vector2 = Vector2(0.781, 0.624)

const COL_PLAZA_LIGHT: Color = Color(0.38, 0.40, 0.42)
const COL_PLAZA_MID: Color = Color(0.32, 0.34, 0.36)
const COL_PLAZA_STRIPE: Color = Color(0.22, 0.24, 0.27)
const COL_WOOD_SLAT: Color = Color(0.54, 0.36, 0.21)
const COL_CONCRETE: Color = Color(0.62, 0.62, 0.60)
const COL_SEAT_STEP: Color = Color(0.46, 0.47, 0.48)
const COL_ANTHRACITE: Color = Color(0.14, 0.16, 0.19)
const COL_OPENING_DARK: Color = Color(0.10, 0.12, 0.15)
const COL_WHITE: Color = Color(0.86, 0.86, 0.84)
const COL_A101_CYAN: Color = Color(0.08, 0.56, 0.82)
const COL_GLASS_DARK: Color = Color(0.10, 0.14, 0.19)
const COL_POSTER_A: Color = Color(0.86, 0.78, 0.32)
const COL_POSTER_B: Color = Color(0.32, 0.66, 0.86)
const COL_GREEN_BED: Color = Color(0.22, 0.38, 0.17)
const COL_SOIL: Color = Color(0.32, 0.23, 0.16)
const COL_GOLD: Color = Color(0.84, 0.64, 0.16)
const COL_METAL: Color = Color(0.26, 0.29, 0.33)


func _ready() -> void:
	build()


func build() -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)

	var gst: SurfaceTool = SurfaceTool.new()
	gst.begin(Mesh.PRIMITIVE_TRIANGLES)
	gst.set_smooth_group(-1)

	var col_body: StaticBody3D = StaticBody3D.new()
	col_body.name = "PlazaCollisions"
	add_child(col_body)

	_build_yildiz_store_front(st, col_body)
	_build_a101_facade(st, gst)
	_build_yemekhane_front(st, gst, col_body)

	st.generate_normals()
	var solid_mesh: ArrayMesh = st.commit()
	var solid_mat: StandardMaterial3D = StandardMaterial3D.new()
	solid_mat.vertex_color_use_as_albedo = true
	solid_mat.roughness = 0.85
	solid_mesh.surface_set_material(0, solid_mat)
	var solid_mi: MeshInstance3D = MeshInstance3D.new()
	solid_mi.name = "PlazaStructures"
	solid_mi.mesh = solid_mesh
	add_child(solid_mi)

	gst.generate_normals()
	var glass_mesh: ArrayMesh = gst.commit()
	if glass_mesh.get_surface_count() > 0:
		var glass_mat: StandardMaterial3D = StandardMaterial3D.new()
		glass_mat.vertex_color_use_as_albedo = true
		glass_mat.albedo_color = Color(0.75, 0.86, 0.92, 0.55)
		glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass_mat.roughness = 0.12
		glass_mat.metallic = 0.15
		glass_mesh.surface_set_material(0, glass_mat)
		var glass_mi: MeshInstance3D = MeshInstance3D.new()
		glass_mi.name = "PlazaGlass"
		glass_mi.mesh = glass_mesh
		glass_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(glass_mi)


## 1) Yıldız Store ön cephesi (edge 3: P3 -> P0): amfi-oturma merdivenleri, teras, tabela, meydan ve yeşil ada.
func _build_yildiz_store_front(st: SurfaceTool, col_body: StaticBody3D) -> void:
	var across: Vector2 = (STORE_P0 - STORE_P3).normalized()   # +X (P3 -> P0, Yemekhane yönü)
	var out: Vector2 = Vector2(-across.y, across.x)            # +Z (Güneydoğu, meydana doğru)
	var mid: Vector2 = (STORE_P3 + STORE_P0) * 0.5
	var w: float = STORE_P3.distance_to(STORE_P0)              # ~14.1 m
	var base_y: float = TerrainHeight.active_height(mid.x, mid.y)
	var xf: Transform3D = _frame_xform(mid, across, out, base_y)

	# Ön cephe temiz beyaz sıvalı alınlık + üstte ince koyu gri harpuşta şeridi
	_add_box_xf(st, xf, Vector3(w + 0.1, 3.65, 0.14), Vector3(0.0, 1.65 + 1.825, 0.04), COL_WHITE)
	_add_box_xf(st, xf, Vector3(w + 0.22, 0.14, 0.26), Vector3(0.0, 5.28, 0.06), COL_ANTHRACITE)
	# Üst beyaz giriş terası (14.1 m x 2.4 m x 1.65 m yükseklik)
	_add_box_xf(st, xf, Vector3(w, 1.65, 2.4), Vector3(0.0, 0.825, 1.2), COL_CONCRETE)
	# 3 giriş açıklığı: y = 1.65..3.85 (tabelanın altında 0.45 m temiz beyaz boşluk kalır!)
	for ox: float in [-4.5, 0.0, 4.5]:
		var ow: float = 4.2 if ox == 0.0 else 3.0
		_add_box_xf(st, xf, Vector3(ow, 2.20, 0.18), Vector3(ox, 1.65 + 1.10, 0.10), COL_OPENING_DARK)

	# 8 basamaklı geniş amfi-oturma merdiveni (oturma sıralarında sıcak ahşap kaplama şeritleri)
	var steps: int = 8
	var step_d: float = 0.65
	var step_h: float = 1.65 / float(steps)
	for i: int in steps:
		var h: float = 1.65 - float(i) * step_h
		var z_c: float = 2.4 + float(i) * step_d + step_d * 0.5
		var col: Color = COL_SEAT_STEP if (i % 2 == 1) else COL_CONCRETE
		_add_box_xf(st, xf, Vector3(w, h, step_d), Vector3(0.0, h * 0.5, z_c), col)
		if i % 2 == 0:
			# Öğrencilerin oturduğu ahşap amfi basamak kaplaması (sağ ve sol oturma kanatları, orta geçiş boş)
			for sx_wood: float in [-4.4, 4.4]:
				_add_box_xf(st, xf, Vector3(4.6, 0.04, step_d * 0.84), Vector3(sx_wood, h + 0.02, z_c), COL_WOOD_SLAT)
	# İki yanda metal korkuluk
	var stair_len: float = float(steps) * step_d
	for sx: float in [-1.0, 1.0]:
		var rx: float = sx * (w * 0.5 - 0.12)
		_add_box_xf(st, xf, Vector3(0.08, 0.95, 0.08), Vector3(rx, 1.65 + 0.48, 2.4), COL_METAL)
		_add_box_xf(st, xf, Vector3(0.08, 0.95, 0.08), Vector3(rx, 0.48, 2.4 + stair_len), COL_METAL)
		_add_box_xf(st, xf, Vector3(0.07, 0.07, stair_len + 0.2), Vector3(rx, 1.3, 2.4 + stair_len * 0.5), COL_METAL)

	# Merdiven önü geniş taş meydan + ortada yeşil peyzaj adası (drone fotoğrafındaki gibi)
	_add_box_xf(st, xf, Vector3(20.0, 0.12, 16.0), Vector3(-1.5, 0.06, 2.4 + stair_len + 8.0), COL_PLAZA_MID)
	_add_box_xf(st, xf, Vector3(6.8, 0.32, 4.6), Vector3(-3.8, 0.22, 2.4 + stair_len + 8.2), COL_SOIL)
	_add_box_xf(st, xf, Vector3(6.2, 0.35, 4.0), Vector3(-3.8, 0.45, 2.4 + stair_len + 8.2), COL_GREEN_BED)
	_add_box_xf(st, xf, Vector3(2.4, 0.28, 2.2), Vector3(-5.2, 0.20, 2.4 + stair_len + 3.2), COL_GREEN_BED)

	# Amfi + teras + yeşil ada çarpışmaları (merdivenden yukarı yürünüp oturulabilir, içine girilmez)
	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "YildizStoreStairs"
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(w, 1.65, 2.4)
	col.shape = shape
	col.transform = xf * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.825, 1.2))
	col_body.add_child(col)

	var ramp_col: CollisionShape3D = CollisionShape3D.new()
	ramp_col.name = "YildizStoreStairRamp"
	ramp_col.shape = _wedge_shape(w, 1.65, stair_len)
	ramp_col.transform = xf * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 2.4))
	col_body.add_child(ramp_col)

	# Yeşil peyzaj adaları çarpışması (içine girilmesin)
	var bed1_col: CollisionShape3D = CollisionShape3D.new()
	bed1_col.name = "StorePlanter1"
	var b1s: BoxShape3D = BoxShape3D.new()
	b1s.size = Vector3(6.8, 0.65, 4.6)
	bed1_col.shape = b1s
	bed1_col.transform = xf * Transform3D(Basis.IDENTITY, Vector3(-3.8, 0.325, 2.4 + stair_len + 8.2))
	col_body.add_child(bed1_col)

	var bed2_col: CollisionShape3D = CollisionShape3D.new()
	bed2_col.name = "StorePlanter2"
	var b2s: BoxShape3D = BoxShape3D.new()
	b2s.size = Vector3(2.4, 0.40, 2.2)
	bed2_col.shape = b2s
	bed2_col.transform = xf * Transform3D(Basis.IDENTITY, Vector3(-5.2, 0.20, 2.4 + stair_len + 3.2))
	col_body.add_child(bed2_col)

	# 3D "★ YTU YILDIZ STORE" cephe tabelası (fotoğraftaki birebir tasarım: solda altın 8 köşeli YTÜ yıldızı,
	# ortada kalın beyaz YTU, sağda üstte altın YILDIZ + altta lacivert STORE, yatay metal raylar üstünde)
	_build_yildiz_store_sign(st, xf)


func _build_yildiz_store_sign(st: SurfaceTool, xf: Transform3D) -> void:
	var sign_y: float = 4.58
	# Arkadaki 3 ince yatay koyu metal montaj rayı (giriş açıklığının tamamen üstünde, temiz beyaz alınlıkta)
	for ry: float in [sign_y - 0.28, sign_y, sign_y + 0.28]:
		_add_box_xf(st, xf, Vector3(4.9, 0.045, 0.05), Vector3(0.05, ry, 0.13), Color(0.32, 0.34, 0.38))

	# Solda 3D 8 köşeli altın YTÜ yıldızı (iki döndürülmüş 4 köşeli yıldız + iç halka)
	var gold_sign: Color = Color(0.84, 0.62, 0.14)
	var navy_sign: Color = Color(0.12, 0.19, 0.32)
	var star_x: float = -1.80
	for k: int in 4:
		var ang: float = float(k) * PI * 0.25
		var rot_xf: Transform3D = xf * Transform3D(Basis(Vector3.BACK, ang), Vector3(star_x, sign_y, 0.20))
		_add_box_xf(st, rot_xf, Vector3(0.96, 0.18, 0.10), Vector3.ZERO, gold_sign)
	_add_box_xf(st, xf, Vector3(0.38, 0.38, 0.12), Vector3(star_x, sign_y, 0.20), COL_WHITE)

	var sign_root: Node3D = Node3D.new()
	sign_root.name = "YildizStoreSign"
	sign_root.transform = xf * Transform3D(Basis.IDENTITY, Vector3(0.0, sign_y, 0.20))
	add_child(sign_root)

	# Ortada kalın 3D "YTU" (beyaz alınlık üstünde net kontrast için açık gümüş/lacivert ton)
	var ytu_mi: MeshInstance3D = _make_3d_text("YTU", 0.80, 0.14, Color(0.18, 0.24, 0.36), 0.35)
	ytu_mi.position = Vector3(-0.22, 0.0, 0.0)
	sign_root.add_child(ytu_mi)

	# Sağda üstte altın "YILDIZ", altta lacivert "STORE"
	var yildiz_mi: MeshInstance3D = _make_3d_text("YILDIZ", 0.34, 0.12, gold_sign, 0.35)
	yildiz_mi.position = Vector3(1.78, 0.20, 0.0)
	sign_root.add_child(yildiz_mi)

	var store_mi: MeshInstance3D = _make_3d_text("STORE", 0.34, 0.12, navy_sign, 0.45)
	store_mi.position = Vector3(1.78, -0.20, 0.0)
	sign_root.add_child(store_mi)


static func _make_3d_text(text: String, height_m: float, depth_m: float, color: Color, roughness: float) -> MeshInstance3D:
	var tm: TextMesh = TextMesh.new()
	tm.text = text
	tm.font_size = 64
	tm.pixel_size = height_m / 48.0
	tm.depth = depth_m
	tm.curve_step = 2.5
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = 0.15 if color.r > 0.7 else 0.05
	tm.material = mat
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = tm
	mi.visibility_range_end = 120.0
	return mi


## 2) A101 cephesi — Yıldız Store binasının sahaya bakan batı yüzü (edge 2: P2 -> P3).
func _build_a101_facade(st: SurfaceTool, gst: SurfaceTool) -> void:
	var along: Vector2 = (STORE_P3 - STORE_P2).normalized()    # +X (P2 -> P3, güneydoğuya)
	var out: Vector2 = Vector2(-along.y, along.x)              # +Z (Güneybatı, sahaya bakan cephe)
	var mid: Vector2 = STORE_P2.lerp(STORE_P3, 0.45)
	var base_y: float = TerrainHeight.active_height(mid.x, mid.y)
	var xf: Transform3D = _frame_xform(mid, along, out, base_y)

	# A101 cephesi temiz beyaz sıva arka duvarı (greybox pencere şeridini örter)
	_add_box_xf(st, xf, Vector3(22.0, 4.95, 0.10), Vector3(2.0, 2.475, 0.05), COL_WHITE)
	# Kalın koyu antrasit U-şekilli portal çerçeve (a101.jpg referansı)
	var pw: float = 9.4
	var ph: float = 4.85
	var thick: float = 0.85
	_add_box_xf(st, xf, Vector3(thick, ph, 0.45), Vector3(-pw * 0.5, ph * 0.5, 0.22), COL_ANTHRACITE)
	_add_box_xf(st, xf, Vector3(thick, ph, 0.45), Vector3(pw * 0.5, ph * 0.5, 0.22), COL_ANTHRACITE)
	_add_box_xf(st, xf, Vector3(pw + thick, thick * 0.85, 0.45), Vector3(0.0, ph - thick * 0.4, 0.22), COL_ANTHRACITE)

	# Portal içi turkuaz A•101 tabelası + 2 koyu cam kapı + parlak kampanya afişleri
	_add_box_xf(st, xf, Vector3(2.3, 1.55, 0.18), Vector3(0.0, 3.25, 0.14), COL_A101_CYAN)
	for dx: float in [-2.1, 2.1]:
		_add_box_xf(st, xf, Vector3(3.4, 2.15, 0.14), Vector3(dx, 1.08, 0.10), COL_ANTHRACITE)
		_add_box_xf(st, xf, Vector3(3.0, 1.9, 0.08), Vector3(dx, 1.08, 0.15), COL_OPENING_DARK)
		_add_box_xf(st, xf, Vector3(0.75, 1.35, 0.05), Vector3(dx - 0.9, 1.05, 0.20), COL_POSTER_A)
		_add_box_xf(st, xf, Vector3(0.75, 1.35, 0.05), Vector3(dx + 0.9, 1.05, 0.20), COL_POSTER_B)

	# Sağdaki beyaz duvarda 8 köşeli YTÜ yıldız kabartması + 3'lü vitrin penceresi
	var rx: float = 7.8
	for k: int in 4:
		var ang: float = float(k) * PI * 0.25
		var sxf: Transform3D = xf * Transform3D(Basis(Vector3.BACK, ang), Vector3(rx, 3.35, 0.14))
		_add_box_xf(st, sxf, Vector3(1.85, 0.28, 0.10), Vector3.ZERO, COL_CONCRETE)
	_add_box_xf(st, xf, Vector3(0.65, 0.65, 0.12), Vector3(rx, 3.35, 0.14), COL_WHITE)
	_add_box_xf(st, xf, Vector3(3.6, 1.7, 0.14), Vector3(rx, 1.25, 0.10), COL_ANTHRACITE)
	_add_box_xf(st, xf, Vector3(3.3, 1.45, 0.08), Vector3(rx, 1.25, 0.15), COL_OPENING_DARK)

	# Ön kaldırım bandı
	_add_box_xf(st, xf, Vector3(24.0, 0.16, 2.8), Vector3(2.0, 0.08, 1.4), COL_PLAZA_LIGHT)

	# "A•101 HARCA HARCA BİTMEZ" yazısı
	var lbl: Label3D = Label3D.new()
	lbl.name = "A101Sign"
	lbl.text = "A•101\nHARCA HARCA\nBİTMEZ"
	lbl.font_size = 56
	lbl.pixel_size = 0.0065
	lbl.modulate = COL_WHITE
	lbl.outline_size = 8
	lbl.outline_modulate = Color(0.05, 0.12, 0.25)
	lbl.visibility_range_end = 110.0
	lbl.transform = xf * Transform3D(Basis.IDENTITY, Vector3(0.0, 3.25, 0.24))
	add_child(lbl)


## 3) Yemekhane önü (yemekhane_1.jpg & yemekhane_2.jpg): geniş açık gri meydan, giriş merdiveni,
## engelli rampası, cam-metal sundurma ve beyaz çerçeveli cam kapı.
func _build_yemekhane_front(st: SurfaceTool, gst: SurfaceTool, col_body: StaticBody3D) -> void:
	var out: Vector2 = YEM_FRONT_OUT.normalized()
	var across: Vector2 = Vector2(out.y, -out.x)
	var base_y: float = TerrainHeight.active_height(YEM_FRONT_MID.x, YEM_FRONT_MID.y)
	var xf: Transform3D = _frame_xform(YEM_FRONT_MID, across, out, base_y)

	# Geniş gri taş meydan + koyu antrasit mimari taş şerit ızgarası + giriş ekseni bordürü
	_add_box_xf(st, xf, Vector3(44.0, 0.12, 22.0), Vector3(-4.0, 0.06, 11.2), COL_PLAZA_LIGHT)
	for sz: float in [4.5, 9.5, 14.5, 19.5]:
		_add_box_xf(st, xf, Vector3(44.0, 0.02, 0.35), Vector3(-4.0, 0.13, sz), COL_PLAZA_STRIPE)
	for sx: float in [-22.0, -14.0, -6.0, 6.0, 14.0]:
		_add_box_xf(st, xf, Vector3(0.35, 0.02, 22.0), Vector3(sx, 0.13, 11.2), COL_PLAZA_STRIPE)
	# Giriş ekseni vurgulu taş yürüyüş halısı
	_add_box_xf(st, xf, Vector3(7.8, 0.025, 18.0), Vector3(0.0, 0.132, 12.8), COL_PLAZA_MID)
	for bx_edge: float in [-4.05, 4.05]:
		_add_box_xf(st, xf, Vector3(0.28, 0.03, 18.0), Vector3(bx_edge, 0.135, 12.8), COL_PLAZA_STRIPE)

	# Meydanda modern ahşap-çelik kampüs bankları (giriş yolunun iki yanında, oturma/dinlenme alanı)
	for bx_bench: float in [-7.5, -13.5, 7.5]:
		for bz_bench: float in [7.2, 13.8]:
			_add_box_xf(st, xf, Vector3(2.2, 0.10, 0.55), Vector3(bx_bench, 0.52, bz_bench), COL_WOOD_SLAT)
			_add_box_xf(st, xf, Vector3(2.2, 0.42, 0.08), Vector3(bx_bench, 0.78, bz_bench - 0.24), COL_WOOD_SLAT)
			for lx: float in [-0.85, 0.85]:
				_add_box_xf(st, xf, Vector3(0.08, 0.46, 0.48), Vector3(bx_bench + lx, 0.28, bz_bench), COL_ANTHRACITE)
			var bcol: CollisionShape3D = CollisionShape3D.new()
			var bsh: BoxShape3D = BoxShape3D.new()
			bsh.size = Vector3(2.2, 0.9, 0.65)
			bcol.shape = bsh
			bcol.transform = xf * Transform3D(Basis.IDENTITY, Vector3(bx_bench, 0.45, bz_bench))
			col_body.add_child(bcol)

	# Giriş sundurması üstünde temiz 3D "YEMEKHANE" tabelası
	_add_box_xf(st, xf, Vector3(6.8, 0.82, 0.16), Vector3(0.0, 5.55, 0.12), COL_WHITE)
	var yem_sign_root: Node3D = Node3D.new()
	yem_sign_root.name = "YemekhaneSign"
	yem_sign_root.transform = xf * Transform3D(Basis.IDENTITY, Vector3(0.0, 5.55, 0.22))
	add_child(yem_sign_root)
	var yem_sign: MeshInstance3D = _make_3d_text("YEMEKHANE", 0.44, 0.10, COL_ANTHRACITE, 0.4)
	yem_sign_root.add_child(yem_sign)

	# Giriş cam kapısı + beyaz çerçeve + alüminyum dikey kayıtlar + iki yandaki dikey cam merdiven boşlukları
	_add_box_xf(st, xf, Vector3(7.4, 3.5, 0.24), Vector3(0.0, 1.15 + 1.75, 0.12), COL_WHITE)
	_add_box_xf(st, xf, Vector3(6.8, 3.1, 0.10), Vector3(0.0, 1.15 + 1.55, 0.22), COL_OPENING_DARK)
	for mx: float in [-2.2, -0.8, 0.8, 2.2]:
		_add_box_xf(st, xf, Vector3(0.08, 3.1, 0.14), Vector3(mx, 1.15 + 1.55, 0.24), COL_CONCRETE)
	_add_box_xf(st, xf, Vector3(6.8, 0.08, 0.14), Vector3(0.0, 1.15 + 2.35, 0.24), COL_CONCRETE)
	for gx: float in [-4.8, 4.8]:
		_add_box_xf(gst, xf, Vector3(1.6, 12.5, 0.12), Vector3(gx, 6.25, 0.14), COL_GLASS_DARK)

	# 6 basamaklı geniş giriş merdiveni (7.6 m genişlik) + sağda metal korkuluklu engelli rampası
	var steps: int = 6
	var step_h: float = 1.15 / float(steps)
	var step_d: float = 0.42
	for i: int in steps:
		var h: float = 1.15 - float(i) * step_h
		var z_c: float = 0.9 + float(i) * step_d + step_d * 0.5
		_add_box_xf(st, xf, Vector3(7.6, h, step_d), Vector3(0.0, h * 0.5, z_c), COL_SEAT_STEP)
	# Giriş sahanlığı
	_add_box_xf(st, xf, Vector3(8.0, 1.15, 0.9), Vector3(0.0, 0.575, 0.45), COL_CONCRETE)
	# Sağ tarafta engelli rampası + metal korkuluk
	_add_box_xf(st, xf, Vector3(7.5, 0.55, 1.5), Vector3(7.6, 0.275, 1.2), COL_CONCRETE)
	_add_box_xf(st, xf, Vector3(7.6, 0.08, 0.08), Vector3(7.6, 1.35, 1.95), COL_METAL)
	for px: float in [4.0, 7.6, 11.2]:
		_add_box_xf(st, xf, Vector3(0.08, 0.85, 0.08), Vector3(px, 0.92, 1.95), COL_METAL)

	# Cam-metal giriş sundurması (kanopi — yemekhane_1/2.jpg'deki metal kirişli şeffaf çatı)
	_add_box_xf(gst, xf, Vector3(8.6, 0.08, 3.2), Vector3(0.0, 4.95, 1.65), COL_WHITE)
	for bx: float in [-4.0, -2.0, 0.0, 2.0, 4.0]:
		_add_box_xf(st, xf, Vector3(0.12, 0.14, 3.25), Vector3(bx, 4.86, 1.65), COL_METAL)
	_add_box_xf(st, xf, Vector3(8.7, 0.14, 0.14), Vector3(0.0, 4.92, 3.25), COL_METAL)

	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "YemekhaneEntrance"
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(8.0, 1.15, 0.9)
	col.shape = shape
	col.transform = xf * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.575, 0.45))
	col_body.add_child(col)

	var yem_ramp: CollisionShape3D = CollisionShape3D.new()
	yem_ramp.name = "YemekhaneStairRamp"
	yem_ramp.shape = _wedge_shape(7.6, 1.15, float(steps) * step_d)
	yem_ramp.transform = xf * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 0.9))
	col_body.add_child(yem_ramp)


## Yerel Z=0'da height yüksekliğinde, Z=depth'te Y=0'a inen yürünebilir merdiven rampası çarpışması.
static func _wedge_shape(width: float, height: float, depth: float) -> ConvexPolygonShape3D:
	var hw: float = width * 0.5
	var s: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
	s.points = PackedVector3Array([
		Vector3(-hw, 0.0, 0.0), Vector3(hw, 0.0, 0.0),
		Vector3(-hw, height, 0.0), Vector3(hw, height, 0.0),
		Vector3(-hw, 0.0, depth), Vector3(hw, 0.0, depth),
	])
	return s


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
		[4, 5, 6, 7],  # +Z
		[1, 0, 3, 2],  # -Z
		[5, 1, 2, 6],  # +X
		[0, 4, 7, 3],  # -X
		[7, 6, 2, 3],  # +Y
		[0, 1, 5, 4],  # -Y
	]
	st.set_color(color)
	for f: Array in faces:
		st.add_vertex(pts[f[0]])
		st.add_vertex(pts[f[2]])
		st.add_vertex(pts[f[1]])
		st.add_vertex(pts[f[0]])
		st.add_vertex(pts[f[3]])
		st.add_vertex(pts[f[2]])
