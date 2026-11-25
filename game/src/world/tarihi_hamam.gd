extends Node3D
## YTÜ Davutpaşa Kampüsü — Tarihi Hamam Kültür Merkezi (b#49):
## 1) Yol kotundan (0.00 m) 2.00 m aşağıda (-2.00 m) çökük gri taş avlu, yeşil çim şeridi,
##    krem dikey çıtalı yol kenarı korkuluğu ve sarı demir tırabzanlı 2 taş merdiven inişi.
## 2) Gerçek 3 kütleli Osmanlı almaşık (kesme taş + çift sıra kırmızı tuğla) mimari:
##    • Sol (KD / Yeni Merkez Kütüphanesi yönü, s=0..17.6 m): 2 katlı Soğukluk & Kültür Merkezi Giriş Köşkü,
##      kemerli çift sıra pencereler, kesme taş kemerli ana kapı, kırma kiremit çatı, köşe klimalar.
##    • Orta (s=17.6..35.8 m): Yüksek sağır Sıcaklık küpü, sekizgen kasnak ve filgözü tepe camlı,
##      24 kurşun kenet dilimli büyük Osmanlı kubbesi + alem.
##    • Sağ (GB / Büyük Ev yönü, s=35.8..75.45 m): Kiremit çatılı tek katlı galeri kanadı,
##      mermer denizlikli 9 derin yuvarlak kemerli taş pencere ve yağmur iniş boruları.
## 3) YTÜ SKY LAB — ARTLAB Yapay Zeka Zirvesi (2 Gün Sonra) + "UniPet yakında" dev cephe afişi.
## 4) Ana giriş kapısının sol tarafında sponsor Espressolab (ESLAB) gümüş oluklu Citroën Type-H kahve minibüsü.

const HAMAM_ORIGIN: Vector2 = Vector2(44.56, -161.98)
const HAMAM_U: Vector2 = Vector2(-0.630079, 0.776531)
const HAMAM_N: Vector2 = Vector2(-0.776519, -0.630094)
const UPPER_Y: float = 0.00
const SUNK_Y: float = -2.00

const ALMASIK_TEX_PATH: String = "res://assets/textures/hamam_almasik.png"
const ARTLAB_TEX_PATH: String = "res://assets/textures/artlab_banner.png"


func _ready() -> void:
	build()


func build() -> void:
	var hxf: Transform3D = Transform3D(
		Basis(Vector3(HAMAM_U.x, 0.0, HAMAM_U.y), Vector3.UP, Vector3(HAMAM_N.x, 0.0, HAMAM_N.y)),
		Vector3(HAMAM_ORIGIN.x, 0.0, HAMAM_ORIGIN.y)
	)

	var col_body: StaticBody3D = StaticBody3D.new()
	col_body.name = "TarihiHamamCollisions"
	add_child(col_body)

	var st_wall: SurfaceTool = SurfaceTool.new()
	st_wall.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_wall.set_smooth_group(-1)

	var st_det: SurfaceTool = SurfaceTool.new()
	st_det.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_det.set_smooth_group(-1)

	_build_sunken_courtyard_and_stairs(st_wall, st_det, hxf)
	_build_three_ottoman_volumes(st_wall, st_det, col_body, hxf)
	_build_lead_dome(st_det, hxf)
	_build_artlab_banners(st_det, hxf)
	_build_eslab_coffee_van(st_det, col_body, hxf)

	st_wall.generate_normals()
	var wall_mesh: ArrayMesh = st_wall.commit()
	if wall_mesh != null and wall_mesh.get_surface_count() > 0:
		var wall_mat: StandardMaterial3D = StandardMaterial3D.new()
		wall_mat.albedo_texture = _load_tex(ALMASIK_TEX_PATH, true)
		wall_mat.roughness = 0.88
		wall_mesh.surface_set_material(0, wall_mat)
		var wall_mi: MeshInstance3D = MeshInstance3D.new()
		wall_mi.name = "HamamAlmasikWalls"
		wall_mi.mesh = wall_mesh
		add_child(wall_mi)

	st_det.generate_normals()
	var det_mesh: ArrayMesh = st_det.commit()
	if det_mesh != null and det_mesh.get_surface_count() > 0:
		var det_mat: StandardMaterial3D = StandardMaterial3D.new()
		det_mat.vertex_color_use_as_albedo = true
		det_mat.roughness = 0.72
		det_mat.metallic = 0.08
		det_mesh.surface_set_material(0, det_mat)
		var det_mi: MeshInstance3D = MeshInstance3D.new()
		det_mi.name = "HamamArchitecturalDetails"
		det_mi.mesh = det_mesh
		det_mi.visibility_range_end = 180.0  # mobil: uzaktan küçük detaylar (minibüs, afiş çerçeveleri) çizilmesin
		add_child(det_mi)


static func _load_tex(res_path: String, repeat_uv: bool) -> Texture2D:
	if ResourceLoader.exists(res_path):
		var loaded: Resource = load(res_path)
		if loaded is Texture2D:
			return loaded as Texture2D
	var abs_p: String = ProjectSettings.globalize_path(res_path)
	if FileAccess.file_exists(abs_p):
		var img: Image = Image.load_from_file(abs_p)
		if img != null and not img.is_empty():
			if repeat_uv:
				img.generate_mipmaps()
			return ImageTexture.create_from_image(img)
	return null


## 1) -2.00 m çökük gri taş avlu, yeşil çim şeridi, krem dikey çit ve 2 sarı tırabzanlı taş merdiven
func _build_sunken_courtyard_and_stairs(st_wall: SurfaceTool, st: SurfaceTool, hxf: Transform3D) -> void:
	var c_paver: Color = Color(0.49, 0.51, 0.53).srgb_to_linear()
	var c_paver_lt: Color = Color(0.60, 0.61, 0.62).srgb_to_linear()
	var c_curb: Color = Color(0.76, 0.75, 0.71).srgb_to_linear()
	var c_drain: Color = Color(0.24, 0.25, 0.27).srgb_to_linear()
	var c_grass: Color = Color(0.26, 0.45, 0.21).srgb_to_linear()
	var c_step: Color = Color(0.62, 0.62, 0.59).srgb_to_linear()
	var c_step_nose: Color = Color(0.79, 0.78, 0.74).srgb_to_linear()
	var c_rail_yellow: Color = Color(0.86, 0.78, 0.36).srgb_to_linear()
	var c_fence_cream: Color = Color(0.83, 0.79, 0.71).srgb_to_linear()
	var c_fence_post: Color = Color(0.72, 0.68, 0.60).srgb_to_linear()
	var c_dark_metal: Color = Color(0.14, 0.15, 0.17).srgb_to_linear()

	# Çökük avlu gri bazalt/granit taş zemini (s=0.15..75.45, d=-0.45..8.80, üst yüz = -2.00 m)
	_box(st, hxf, Vector3(75.32, 0.36, 9.26), Vector3(37.80, SUNK_Y - 0.18, 4.18), c_paver)
	# Avlu taş derz şeritleri (ölçek hissi için her 4.5 m'de ince açık gri taş bant)
	for si: int in 16:
		var sx: float = 2.5 + float(si) * 4.6
		_box(st, hxf, Vector3(0.10, 0.012, 8.70), Vector3(sx, SUNK_Y + 0.006, 4.35), c_paver_lt)
	# Bina önü yağmur drenaj ızgarası kanalı
	_box(st, hxf, Vector3(74.80, 0.014, 0.18), Vector3(37.75, SUNK_Y + 0.007, 0.72), c_drain)

	# Çökük avludaki uzun dikdörtgen yeşil çim şeridi (uploaded_media_0: s=17.8..72.6, d=5.45..8.15)
	_box(st, hxf, Vector3(55.00, 0.08, 2.86), Vector3(45.20, SUNK_Y + 0.04, 6.80), c_curb)
	_box(st, hxf, Vector3(54.68, 0.095, 2.54), Vector3(45.20, SUNK_Y + 0.048, 6.80), c_grass)

	# Sağ alt köşedeki siyah yuvarlak kokteyl/etkinlik masası (uploaded_media_0 sağ alt!)
	for bistro_s: float in [44.2, 61.5]:
		_cyl(st, hxf, 0.28, 0.04, Vector3(bistro_s, SUNK_Y + 0.02, 2.55), 12, c_dark_metal)
		_cyl(st, hxf, 0.045, 0.96, Vector3(bistro_s, SUNK_Y + 0.50, 2.55), 8, c_dark_metal)
		_cyl(st, hxf, 0.42, 0.045, Vector3(bistro_s, SUNK_Y + 0.99, 2.55), 14, c_dark_metal)

	# Üst yol kenarı yaya kaldırımı ve merdiven başı sahanlığı (d=8.80..11.40, y=0.05 m)
	_box(st, hxf, Vector3(75.50, 0.16, 2.65), Vector3(37.80, UPPER_Y - 0.03, 10.12), c_paver_lt)
	_box(st, hxf, Vector3(75.50, 0.18, 0.24), Vector3(37.80, UPPER_Y + 0.01, 11.42), c_curb)

	# İstinat duvarları (almaşık taş kaplı: d=8.80 merdiven araları + s=75.45 sağ uç + s=0.15 sol uç)
	for seg: Array in [[0.15, 11.20], [15.60, 35.80], [39.80, 75.45]]:
		var s0: float = float(seg[0])
		var s1: float = float(seg[1])
		_wall_box_uv(st_wall, hxf, Vector3(s1 - s0, 2.08, 0.34), Vector3((s0 + s1) * 0.5, SUNK_Y + 1.04, 8.80))
		_box(st, hxf, Vector3(s1 - s0 + 0.08, 0.09, 0.44), Vector3((s0 + s1) * 0.5, UPPER_Y + 0.085, 8.80), c_curb)
		# Yol seviyesinde krem rengi dikey çıtalı korkuluk çiti (uploaded_media_1!)
		_build_picket_fence_span(st, hxf, s0 + 0.10, s1 - 0.10, 8.80, UPPER_Y + 0.13, c_fence_cream, c_fence_post)

	_wall_box_uv(st_wall, hxf, Vector3(0.36, 2.08, 8.95), Vector3(75.45, SUNK_Y + 1.04, 4.32))
	_box(st, hxf, Vector3(0.46, 0.09, 9.05), Vector3(75.45, UPPER_Y + 0.085, 4.32), c_curb)
	_wall_box_uv(st_wall, hxf, Vector3(0.36, 2.08, 3.65), Vector3(0.15, SUNK_Y + 1.04, 6.98))
	_box(st, hxf, Vector3(0.46, 0.09, 3.72), Vector3(0.15, UPPER_Y + 0.085, 6.98), c_curb)

	# İki adet 12 basamaklı taş merdiven + sarı boyalı metal tırabzanlar (uploaded_media_0 & uploaded_media_1!)
	# Merdiven 1 (Ana Kapı & ESLAB önü: s=11.20..15.60) ve Merdiven 2 (Galeri & Kubbe önü: s=35.80..39.80)
	for st_cfg: Array in [[11.20, 15.60], [35.80, 39.80]]:
		var ms0: float = float(st_cfg[0])
		var ms1: float = float(st_cfg[1])
		var mw: float = ms1 - ms0
		var mc: float = (ms0 + ms1) * 0.5
		var n_steps: int = 12
		var dz_step: float = 5.40 / float(n_steps)
		var dy_step: float = 2.00 / float(n_steps)
		# Merdiven yan taş yanak duvarları
		for side_s: float in [ms0 + 0.08, ms1 - 0.08]:
			for si2: int in n_steps:
				var z_c: float = 8.80 - (float(si2) + 0.5) * dz_step
				var top_y: float = UPPER_Y - float(si2) * dy_step + 0.10
				var h_ch: float = top_y - (SUNK_Y - 0.10)
				_box(st, hxf, Vector3(0.16, h_ch, dz_step + 0.02), Vector3(side_s, top_y - h_ch * 0.5, z_c), c_curb)
		for si: int in n_steps:
			var z_c: float = 8.80 - (float(si) + 0.5) * dz_step
			var top_y: float = UPPER_Y - float(si + 1) * (2.00 / float(n_steps + 1))
			var sh: float = top_y - (SUNK_Y - 0.15)
			_box(st, hxf, Vector3(mw - 0.16, sh, dz_step + 0.03), Vector3(mc, top_y - sh * 0.5, z_c), c_step)
			_box(st, hxf, Vector3(mw - 0.16, 0.035, 0.065), Vector3(mc, top_y - 0.012, z_c - dz_step * 0.5 + 0.03), c_step_nose)
		# Sarı demir boru korkuluklar (sol, orta ve sağ kol — tam uploaded_media_0'daki sarı korkuluk!)
		for rail_s: float in [ms0 + 0.10, mc, ms1 - 0.10]:
			_build_stair_handrail(st, hxf, rail_s, 8.80, UPPER_Y, 3.40, SUNK_Y, c_rail_yellow)


func _build_picket_fence_span(st: SurfaceTool, hxf: Transform3D, s0: float, s1: float, d_z: float, y0: float, c_slat: Color, c_post: Color) -> void:
	var length: float = s1 - s0
	if length <= 0.3:
		return
	# Üst ve alt yatay kayıtlar
	_box(st, hxf, Vector3(length, 0.055, 0.06), Vector3((s0 + s1) * 0.5, y0 + 0.92, d_z), c_post)
	_box(st, hxf, Vector3(length, 0.055, 0.06), Vector3((s0 + s1) * 0.5, y0 + 0.18, d_z), c_post)
	# Ana dikmeler (her ~2.4 m'de)
	var n_posts: int = maxi(2, int(round(length / 2.4)) + 1)
	for pi: int in n_posts:
		var ps: float = lerpf(s0, s1, float(pi) / float(n_posts - 1))
		_box(st, hxf, Vector3(0.09, 1.06, 0.09), Vector3(ps, y0 + 0.53, d_z), c_post)
	# Dikey krem çıtalar (her 0.20 m'de — uploaded_media_1!)
	var n_slats: int = int(floor(length / 0.20))
	for ki: int in n_slats:
		var ks: float = s0 + (float(ki) + 0.5) * (length / float(n_slats))
		_box(st, hxf, Vector3(0.065, 1.00, 0.028), Vector3(ks, y0 + 0.50, d_z), c_slat)


func _build_stair_handrail(st: SurfaceTool, hxf: Transform3D, s_x: float, z_top: float, y_top: float, z_bot: float, y_bot: float, col: Color) -> void:
	var rail_h: float = 0.90
	for p_i: int in 5:
		var t: float = float(p_i) / 4.0
		var pz: float = lerpf(z_top, z_bot, t)
		var py: float = lerpf(y_top, y_bot, t)
		_box(st, hxf, Vector3(0.048, rail_h, 0.048), Vector3(s_x, py + rail_h * 0.5, pz), col)
	# Eğimli üst küpeşte ve orta ara boru
	var dz: float = z_bot - z_top
	var dy: float = y_bot - y_top
	var r_len: float = sqrt(dz * dz + dy * dy)
	var z_axis: Vector3 = Vector3(0.0, dy / r_len, dz / r_len)
	var y_axis: Vector3 = z_axis.cross(Vector3.RIGHT).normalized()
	for h_off: float in [rail_h, rail_h * 0.54]:
		var rxf: Transform3D = hxf * Transform3D(
			Basis(Vector3.RIGHT, y_axis, z_axis),
			Vector3(s_x, (y_top + y_bot) * 0.5 + h_off, (z_top + z_bot) * 0.5)
		)
		_box(st, rxf, Vector3(0.055, 0.055, r_len + 0.14), Vector3.ZERO, col)


## 2) Tarihi Hamam'ın 3 ikonik Osmanlı almaşık kütlesi (Soğukluk + Sıcaklık + Kemerli Kanat)
func _build_three_ottoman_volumes(st_wall: SurfaceTool, st: SurfaceTool, col_body: StaticBody3D, hxf: Transform3D) -> void:
	var c_cornice: Color = Color(0.88, 0.86, 0.80).srgb_to_linear()
	var c_stone_trim: Color = Color(0.84, 0.81, 0.74).srgb_to_linear()
	var c_marble_sill: Color = Color(0.93, 0.93, 0.91).srgb_to_linear()
	var c_brick_quoin: Color = Color(0.66, 0.34, 0.26).srgb_to_linear()
	var c_tile_roof: Color = Color(0.68, 0.31, 0.21).srgb_to_linear()
	var c_tile_ridge: Color = Color(0.76, 0.38, 0.26).srgb_to_linear()
	var c_win_glass: Color = Color(0.10, 0.14, 0.19).srgb_to_linear()
	var c_iron_frame: Color = Color(0.16, 0.17, 0.19).srgb_to_linear()
	var c_door_bronze: Color = Color(0.20, 0.16, 0.13).srgb_to_linear()
	var c_warm_glow: Color = Color(0.88, 0.72, 0.44).srgb_to_linear()
	var c_gutter: Color = Color(0.46, 0.49, 0.52).srgb_to_linear()
	var c_ac_white: Color = Color(0.90, 0.91, 0.90).srgb_to_linear()

	# ------------------------------------------------------------------
	# KÜTLE A — Sol 2 Katlı Soğukluk & Kültür Merkezi Giriş Köşkü (s=0.0..17.6, d=-14.8..0.0, y=-2.0..+6.40)
	# ------------------------------------------------------------------
	_wall_box_uv(st_wall, hxf, Vector3(17.60, 8.40, 14.80), Vector3(8.80, 2.20, -7.40))
	_add_col_box(col_body, hxf, Vector3(17.60, 9.20, 14.80), Vector3(8.80, 2.60, -7.40))
	# Kat silmesi ve saçak kornişi
	_box(st, hxf, Vector3(17.84, 0.18, 15.04), Vector3(8.80, 2.15, -7.40), c_stone_trim)
	_box(st, hxf, Vector3(18.10, 0.30, 15.30), Vector3(8.80, 6.42, -7.40), c_cornice)
	# Kırma alaturka kiremit çatı (Soğukluk)
	_add_hip_roof_local(st, hxf, 8.80, -7.40, 18.30, 15.50, 6.56, 1.85, c_tile_roof, c_tile_ridge)

	# Sol Kışla birleşim yanağı (uploaded_media_0 en sol: s=0.18, d=0.0..5.15 kemerli kapı + üst kemerli pencere + 2 klima!)
	_wall_box_uv(st_wall, hxf, Vector3(0.32, 8.20, 5.15), Vector3(0.16, 2.10, 2.575))
	_box(st, hxf, Vector3(0.44, 0.26, 5.30), Vector3(0.20, 6.22, 2.58), c_cornice)
	_add_side_arch_opening(st, hxf, 0.33, 2.55, SUNK_Y + 0.05, 1.35, 2.55, c_stone_trim, c_win_glass, c_iron_frame)
	_add_side_arch_opening(st, hxf, 0.33, 2.55, 2.45, 1.35, 2.35, c_stone_trim, c_win_glass, c_iron_frame)
	# İki beyaz dış klima ünitesi (uploaded_media_0 sol alt köşe!)
	for ac_i: int in 2:
		var ac_y: float = SUNK_Y + 0.42 + float(ac_i) * 0.82
		_box(st, hxf, Vector3(0.36, 0.72, 0.92), Vector3(0.50, ac_y, 0.92), c_ac_white)
		_cyl_axis_x(st, hxf, 0.25, 0.04, Vector3(0.69, ac_y, 0.82), 12, c_iron_frame)

	# Soğukluk cephesinde 2 sıra × 4 yuvarlak kemerli pencere (s=2.3, 4.6, 6.9, 9.2)
	for wi: int in 4:
		var ws: float = 2.30 + float(wi) * 2.30
		_add_front_arched_window(st, hxf, ws, 0.02, SUNK_Y + 0.95, 1.28, 2.25, c_stone_trim, c_marble_sill, c_win_glass, c_iron_frame)
		_add_front_arched_window(st, hxf, ws, 0.02, 2.65, 1.28, 2.25, c_stone_trim, c_marble_sill, c_win_glass, c_iron_frame)

	# ANA GİRİŞ PORTALİ — TARİHİ HAMAM KÜLTÜR MERKEZİ (s=13.50, d=0.0..0.58, Merdiven 1'in tam karşısı!)
	_box(st, hxf, Vector3(4.30, 5.40, 0.56), Vector3(13.50, SUNK_Y + 2.70, 0.28), c_stone_trim)
	_box(st, hxf, Vector3(4.62, 0.28, 0.72), Vector3(13.50, SUNK_Y + 5.45, 0.34), c_cornice)
	# Kemerli çift kanatlı kültür merkezi giriş kapısı + sıcak iç fuaye aydınlatması
	_add_front_arched_door(st, hxf, 13.50, 0.57, SUNK_Y + 0.04, 2.55, 3.65, c_cornice, c_door_bronze, c_warm_glow)
	# Giriş üstü 2. kat kemerli salon penceresi
	_add_front_arched_window(st, hxf, 13.50, 0.04, 3.85, 1.55, 1.95, c_stone_trim, c_marble_sill, c_win_glass, c_iron_frame)
	# Giriş kapısı alınlık tabelası
	_add_label_xf(
		hxf,
		Vector3(13.50, SUNK_Y + 4.55, 0.62),
		0.0,
		"TarihiHamamPortalSign",
		"TARİHİ HAMAM KÜLTÜR MERKEZİ\nYTÜ Kulüpler & Etkinlik Salonu",
		32,
		0.0046,
		Color(0.98, 0.92, 0.74),
		Color(0.14, 0.10, 0.07, 0.96)
	)

	# ------------------------------------------------------------------
	# KÜTLE B — Orta Yüksek Sıcaklık Küpü (s=17.60..35.80, d=-16.95..+0.48, y=-2.00..+7.30)
	#           uploaded_media_0'da net görülen öne 48 cm taşan sağır taş-tuğla duvar + köşe tuğla dişleri!
	# ------------------------------------------------------------------
	_wall_box_uv(st_wall, hxf, Vector3(18.20, 9.30, 17.43), Vector3(26.70, 2.65, -8.235))
	_add_col_box(col_body, hxf, Vector3(18.20, 10.20, 17.43), Vector3(26.70, 3.10, -8.235))
	# Köşe tuğla kenet dişleri (uploaded_media_0'da Sıcaklık köşelerindeki tuğla kuşaklar!)
	for q_s: float in [17.74, 35.66]:
		for q_i: int in 11:
			var qy: float = SUNK_Y + 0.42 + float(q_i) * 0.82
			_box(st, hxf, Vector3(0.34, 0.34, 0.56), Vector3(q_s, qy, 0.24), c_brick_quoin)
	# Sıcaklık üst taş parapet kornişi
	_box(st, hxf, Vector3(18.52, 0.32, 17.75), Vector3(26.70, 7.34, -8.235), c_cornice)
	# Cephe üstü projektör kolları (uploaded_media_0'da Sıcaklık duvarı üstündeki projektörler!)
	for fl_s: float in [20.4, 26.7, 33.0]:
		_box(st, hxf, Vector3(0.10, 0.08, 0.75), Vector3(fl_s, 7.05, 0.82), c_iron_frame)
		_box(st, hxf, Vector3(0.42, 0.22, 0.28), Vector3(fl_s, 6.96, 1.16), c_iron_frame)

	# ------------------------------------------------------------------
	# KÜTLE C — Sağ Uzun Tek Katlı Kemerli Galeri Kanadı (s=35.80..75.45, d=-16.95..0.0, y=-2.00..+3.45)
	#           uploaded_media_0 sağ + uploaded_media_1: 9 derin yuvarlak kemerli pencere + mermer denizlik + kiremit çatı!
	# ------------------------------------------------------------------
	# Ana gövde (kemer nişlerinin arkasındaki iç duvar d=-16.95..-0.44 + kemerler arası almaşık ayaklar d=-0.44..0.0)
	_wall_box_uv(st_wall, hxf, Vector3(39.65, 5.45, 16.51), Vector3(55.625, 0.725, -8.695))
	_add_col_box(col_body, hxf, Vector3(39.65, 6.40, 16.95), Vector3(55.625, 1.20, -8.475))
	# Ön duvar alt etek (y=-2.00..-0.55) ve üst kemer lentosu (y=+1.95..+3.45)
	_wall_box_uv(st_wall, hxf, Vector3(39.65, 1.45, 0.46), Vector3(55.625, -1.275, -0.22))
	_wall_box_uv(st_wall, hxf, Vector3(39.65, 1.50, 0.46), Vector3(55.625, 2.70, -0.22))

	# 9 adet derin girintili (44 cm!) yuvarlak kemerli taş pencere + aralarındaki almaşık duvar ayakları
	var n_bays: int = 9
	var bay_span: float = 39.65 / float(n_bays)  # 4.405 m
	var win_w: float = 1.62
	var pier_w: float = bay_span - win_w
	for bi: int in n_bays + 1:
		var p_s0: float = 35.80 + float(bi) * bay_span - pier_w * 0.5
		var p_s1: float = p_s0 + pier_w
		p_s0 = maxf(p_s0, 35.80)
		p_s1 = minf(p_s1, 75.45)
		if p_s1 - p_s0 > 0.08:
			_wall_box_uv(st_wall, hxf, Vector3(p_s1 - p_s0, 2.52, 0.46), Vector3((p_s0 + p_s1) * 0.5, 0.70, -0.22))
	for bi: int in n_bays:
		var bc_s: float = 35.80 + (float(bi) + 0.5) * bay_span
		_add_deep_recessed_arch_window(st, hxf, bc_s, 0.0, -0.55, win_w, 2.48, 0.44, c_stone_trim, c_marble_sill, c_win_glass, c_iron_frame)

	# Arka (Ortabahçe'ye bakan d=-16.95) cephesine de simetrik kemerli pencereler ekleyelim (360° bütünlük!)
	for bi_back: int in 7:
		var b_s: float = 39.5 + float(bi_back) * 5.2
		_add_front_arched_window_back(st, hxf, b_s, -16.97, 0.45, 1.50, 2.25, c_stone_trim, c_marble_sill, c_win_glass, c_iron_frame)

	# Galeri saçak kornişi + yatay yağmur oluğu + 4 dikey galvaniz yağmur iniş borusu (uploaded_media_0!)
	_box(st, hxf, Vector3(39.95, 0.24, 17.35), Vector3(55.625, 3.52, -8.475), c_cornice)
	_box(st, hxf, Vector3(39.98, 0.12, 0.16), Vector3(55.625, 3.62, 0.22), c_gutter)
	for dp_s: float in [36.15, 49.02, 62.24, 75.10]:
		_cyl(st, hxf, 0.055, 5.58, Vector3(dp_s, 0.82, 0.09), 8, c_gutter)

	# Uzun kiremit kırma/beşik çatı (Kütle C: s=35.80..75.45, d=-17.25..+0.30, y=3.64..6.35)
	_add_hip_roof_local(st, hxf, 55.625, -8.475, 40.10, 17.55, 3.64, 2.70, c_tile_roof, c_tile_ridge)


## 3) Sıcaklık kütlesi üzerinde sekizgen kasnak + 24 dilimli kurşun kaplı büyük Osmanlı kubbesi + filgözü camlar + alem
func _build_lead_dome(st: SurfaceTool, hxf: Transform3D) -> void:
	var c_drum: Color = Color(0.82, 0.79, 0.72).srgb_to_linear()
	var c_cornice: Color = Color(0.89, 0.87, 0.82).srgb_to_linear()
	var c_lead: Color = Color(0.53, 0.57, 0.62).srgb_to_linear()
	var c_lead_rib: Color = Color(0.66, 0.70, 0.75).srgb_to_linear()
	var c_filgozu_rim: Color = Color(0.74, 0.77, 0.81).srgb_to_linear()
	var c_filgozu_glass: Color = Color(0.32, 0.48, 0.60).srgb_to_linear()
	var c_alem_brass: Color = Color(0.84, 0.69, 0.28).srgb_to_linear()

	var center_s: float = 26.70
	var center_d: float = -6.40
	var drum_y0: float = 7.35
	var drum_h: float = 0.88
	var dome_r: float = 6.85
	var dome_h: float = 4.75

	# Sekizgen taş kasnak
	_cyl(st, hxf, dome_r + 0.38, drum_h, Vector3(center_s, drum_y0 + drum_h * 0.5, center_d), 8, c_drum)
	_cyl(st, hxf, dome_r + 0.54, 0.16, Vector3(center_s, drum_y0 + drum_h + 0.06, center_d), 16, c_cornice)

	# 24 dilimli yarım küre kurşun kubbe kabuğu
	var dome_y0: float = drum_y0 + drum_h + 0.12
	var segs: int = 24
	var rings: int = 10
	for ri: int in rings:
		var p0: float = (PI * 0.5) * float(ri) / float(rings)
		var p1: float = (PI * 0.5) * float(ri + 1) / float(rings)
		var r0: float = cos(p0) * dome_r
		var r1: float = cos(p1) * dome_r
		var y0: float = dome_y0 + sin(p0) * dome_h
		var y1: float = dome_y0 + sin(p1) * dome_h
		for si: int in segs:
			var a0: float = TAU * float(si) / float(segs)
			var a1: float = TAU * float(si + 1) / float(segs)
			var v00: Vector3 = hxf * Vector3(center_s + cos(a0) * r0, y0, center_d + sin(a0) * r0)
			var v10: Vector3 = hxf * Vector3(center_s + cos(a1) * r0, y0, center_d + sin(a1) * r0)
			var v01: Vector3 = hxf * Vector3(center_s + cos(a0) * r1, y1, center_d + sin(a0) * r1)
			var v11: Vector3 = hxf * Vector3(center_s + cos(a1) * r1, y1, center_d + sin(a1) * r1)
			st.set_color(c_lead)
			st.add_vertex(v00)
			st.add_vertex(v10)
			st.add_vertex(v11)
			st.add_vertex(v00)
			st.add_vertex(v11)
			st.add_vertex(v01)

	# 24 kabartma kurşun kenet dilim çıtaları (uploaded_media_0 kubbe dilimleri!)
	for si: int in segs:
		var ang: float = TAU * float(si) / float(segs)
		var ca: float = cos(ang)
		var sa: float = sin(ang)
		for ri: int in rings - 1:
			var pm: float = (PI * 0.5) * (float(ri) + 0.5) / float(rings)
			var seg_len: float = (PI * 0.5 / float(rings)) * dome_r
			var rr: float = cos(pm) * (dome_r + 0.045)
			var yy: float = dome_y0 + sin(pm) * (dome_h + 0.045)
			var rad_out: Vector3 = Vector3(ca * cos(pm), sin(pm), sa * cos(pm)).normalized()
			var tang_up: Vector3 = Vector3(-ca * sin(pm), cos(pm), -sa * sin(pm)).normalized()
			var side_v: Vector3 = tang_up.cross(rad_out).normalized()
			var rxf: Transform3D = hxf * Transform3D(
				Basis(side_v, rad_out, tang_up),
				Vector3(center_s + ca * rr, yy, center_d + sa * rr)
			)
			_box(st, rxf, Vector3(0.065, 0.075, seg_len + 0.05), Vector3.ZERO, c_lead_rib)

	# 3 halka halinde dairesel "filgözü" tepe camları (uploaded_media_0 kubbe üstündeki yuvarlak ışık gözleri!)
	for ring_cfg: Array in [[0.34, 12], [0.62, 10], [0.92, 8]]:
		var phi: float = float(ring_cfg[0])
		var cnt: int = int(ring_cfg[1])
		for fi: int in cnt:
			var fang: float = TAU * (float(fi) + 0.5) / float(cnt) + phi * 0.4
			var ca: float = cos(fang)
			var sa: float = sin(fang)
			var rr: float = cos(phi) * dome_r
			var yy: float = dome_y0 + sin(phi) * dome_h
			var nrm: Vector3 = Vector3(ca * cos(phi), sin(phi), sa * cos(phi)).normalized()
			var ref_up: Vector3 = Vector3.UP if absf(nrm.y) < 0.92 else Vector3.RIGHT
			var tx: Vector3 = ref_up.cross(nrm).normalized()
			var tz: Vector3 = nrm.cross(tx).normalized()
			var fxf: Transform3D = hxf * Transform3D(Basis(tx, nrm, tz), Vector3(center_s + ca * rr, yy, center_d + sa * rr))
			_cyl(st, fxf, 0.25, 0.13, Vector3(0.0, 0.05, 0.0), 10, c_filgozu_rim)
			_cyl(st, fxf, 0.18, 0.05, Vector3(0.0, 0.11, 0.0), 10, c_filgozu_glass)

	# Kubbe tepesi Osmanlı alemi
	var apex_y: float = dome_y0 + dome_h
	_cyl(st, hxf, 0.42, 0.14, Vector3(center_s, apex_y + 0.05, center_d), 12, c_lead_rib)
	_cyl(st, hxf, 0.06, 1.05, Vector3(center_s, apex_y + 0.62, center_d), 8, c_alem_brass)
	for bi_b: Array in [[0.24, 0.18], [0.55, 0.14], [0.84, 0.10]]:
		_cyl(st, hxf, float(bi_b[1]), float(bi_b[1]) * 1.4, Vector3(center_s, apex_y + float(bi_b[0]), center_d), 10, c_alem_brass)


## 4) YTÜ SKY LAB — ARTLAB Yapay Zeka Zirvesi + "UniPet yakında" Afişleri
##    • Ana Dev Cephe Afişi: Sıcaklık kütlesinin Yeni Merkez Kütüphanesi & ana yola bakan yüksek duvarında (13.6 m × 7.65 m)
##    • Kütüphane Yönü Karşılama Totem-Afişi: Kütüphane & EEF aksından gelenlerin doğrudan gördüğü üst meydan köşesinde
func _build_artlab_banners(st: SurfaceTool, hxf: Transform3D) -> void:
	var c_truss: Color = Color(0.14, 0.16, 0.20).srgb_to_linear()
	var c_cable: Color = Color(0.68, 0.72, 0.76).srgb_to_linear()

	var banner_tex: Texture2D = _load_tex(ARTLAB_TEX_PATH, false)
	var bmat: StandardMaterial3D = StandardMaterial3D.new()
	bmat.albedo_texture = banner_tex
	bmat.roughness = 0.42
	if banner_tex != null:
		bmat.emission_enabled = true
		bmat.emission_texture = banner_tex
		bmat.emission_energy_multiplier = 0.30

	# 4a) Ana Sıcaklık Cephesi Dev Afişi (s=20.45..32.95 -> 12.50 m × 7.00 m, y=+0.18..+7.18:
	#     alt kenarı çit hizasının üstünde kaldığı için karşı yoldan da "UniPet yakında" %100 engelsiz okunur!)
	var bw: float = 12.50
	var bh: float = 7.00
	var bs_mid: float = 26.70
	var by_mid: float = 3.68
	var bd_z: float = 0.60
	# Çelik germe konstrüksiyon çerçevesi + köşe gergi aparatları
	_box(st, hxf, Vector3(bw + 0.36, 0.12, 0.12), Vector3(bs_mid, by_mid + bh * 0.5 + 0.08, bd_z - 0.04), c_truss)
	_box(st, hxf, Vector3(bw + 0.36, 0.12, 0.12), Vector3(bs_mid, by_mid - bh * 0.5 - 0.08, bd_z - 0.04), c_truss)
	_box(st, hxf, Vector3(0.12, bh + 0.36, 0.12), Vector3(bs_mid - bw * 0.5 - 0.08, by_mid, bd_z - 0.04), c_truss)
	_box(st, hxf, Vector3(0.12, bh + 0.36, 0.12), Vector3(bs_mid + bw * 0.5 + 0.08, by_mid, bd_z - 0.04), c_truss)
	for cx_off: float in [-bw * 0.5, 0.0, bw * 0.5]:
		for cy_off: float in [-bh * 0.5, bh * 0.5]:
			_box(st, hxf, Vector3(0.08, 0.08, 0.18), Vector3(bs_mid + cx_off, by_mid + cy_off, bd_z - 0.06), c_cable)

	var main_quad: QuadMesh = QuadMesh.new()
	main_quad.size = Vector2(bw, bh)
	main_quad.material = bmat
	var main_mi: MeshInstance3D = MeshInstance3D.new()
	main_mi.name = "ArtlabMainBanner"
	main_mi.mesh = main_quad
	main_mi.transform = hxf * Transform3D(Basis.IDENTITY, Vector3(bs_mid, by_mid, bd_z))
	main_mi.visibility_range_end = 180.0
	add_child(main_mi)

	# 4b) Yeni Merkez Kütüphanesi & EEF yaklaşım aksına dönük çift yüzlü karşılama afiş panosu (s=2.40, d=9.85, y=0..3.6)
	var k_pos: Vector3 = Vector3(2.40, 0.0, 9.85)
	var k_yaw: float = deg_to_rad(-36.0)  # Doğrudan Yeni Merkez Kütüphanesi (-77, -183) aksına bakar!
	var kxf: Transform3D = hxf * Transform3D(Basis(Vector3.UP, k_yaw), k_pos)
	var kw: float = 4.60
	var kh: float = 2.60
	_box(st, kxf, Vector3(0.14, 3.85, 0.14), Vector3(-kw * 0.5 - 0.10, 1.92, 0.0), c_truss)
	_box(st, kxf, Vector3(0.14, 3.85, 0.14), Vector3(kw * 0.5 + 0.10, 1.92, 0.0), c_truss)
	_box(st, kxf, Vector3(kw + 0.34, 0.12, 0.16), Vector3(0.0, 3.82, 0.0), c_truss)
	_box(st, kxf, Vector3(kw + 0.34, 0.12, 0.16), Vector3(0.0, 1.06, 0.0), c_truss)

	var side_quad: QuadMesh = QuadMesh.new()
	side_quad.size = Vector2(kw, kh)
	side_quad.material = bmat
	for face_i: int in 2:
		var qmi: MeshInstance3D = MeshInstance3D.new()
		qmi.name = "ArtlabLibraryBanner_%d" % face_i
		qmi.mesh = side_quad
		var ry: float = 0.0 if face_i == 0 else PI
		var z_off: float = 0.05 if face_i == 0 else -0.05
		qmi.transform = kxf * Transform3D(Basis(Vector3.UP, ry), Vector3(0.0, 2.44, z_off))
		qmi.visibility_range_end = 140.0
		add_child(qmi)


## 5) Sponsor ESPRESSOLAB (ESLAB) Gümüş Oluklu Citroën Type-H Kahve Minibüsü (eslab_van.jpg birebir!)
##    Ana giriş kapısının (s=13.50) tam SOL TARAFINDA (kapıya bakarken solda: s=5.60, d=3.25, y=-2.00 m)!
func _build_eslab_coffee_van(st: SurfaceTool, col_body: StaticBody3D, hxf: Transform3D) -> void:
	# Minibüs yerel ekseni: +Z = ön burun (Merdiven 1 & Kütüphane yoluna hafif açılı bakar),
	# -X veya +X? eslab_van.jpg'de servis penceresi aracın SOL yanındadır (sürücü tarafı / karşıdan bakınca sağ!).
	# Aracın ön burnunu (+Z_van) Kütüphane/Merdiven yönüne (+s/+d) çevirdiğimizde sol yanı (+X_van veya -X_van?):
	# Godot'ta ileri = +Z_van ise, Basis.x (+X_van) aracın SOL yanına (sürücü tarafı = eslab_van.jpg'deki açılır servis penceresi!) bakar!
	# Kontrol: ileri = +Z, yukarı = +Y -> sağ el kuralında başparmak +X (aracın SOLU!), işaret +Y (yukarı), orta +Z (ileri)!
	# Öyleyse ön burun (+Z_van) s=-0.35, d=+0.94 yönüne (yola/kütüphaneye) baktığında, +X_van (+s yönüne, yani doğrudan
	# Tarihi Hamam ana giriş kapısı s=13.50 ve Merdiven 1 s=13.40 önündeki meydana!) bakar!! Hem yoldan ön burun + açılır
	# servis kapağı aynı anda eslab_van.jpg açısıyla görünür!!
	var van_yaw: float = deg_to_rad(-22.0)
	var vxf: Transform3D = hxf * Transform3D(Basis(Vector3.UP, van_yaw), Vector3(5.65, SUNK_Y, 3.35))

	_add_col_box(col_body, vxf, Vector3(2.22, 2.55, 5.25), Vector3(0.0, 1.28, 0.0))

	var c_silver: Color = Color(0.64, 0.67, 0.70).srgb_to_linear()
	var c_silver_hi: Color = Color(0.77, 0.80, 0.83).srgb_to_linear()
	var c_silver_dk: Color = Color(0.45, 0.48, 0.52).srgb_to_linear()
	var c_chrome: Color = Color(0.89, 0.91, 0.94).srgb_to_linear()
	var c_tire: Color = Color(0.10, 0.11, 0.12).srgb_to_linear()
	var c_glass: Color = Color(0.11, 0.16, 0.20).srgb_to_linear()
	var c_black: Color = Color(0.11, 0.12, 0.14).srgb_to_linear()
	var c_headlight: Color = Color(0.97, 0.96, 0.88).srgb_to_linear()
	var c_eslab_red: Color = Color(0.84, 0.12, 0.15).srgb_to_linear()
	var c_wood_bar: Color = Color(0.56, 0.38, 0.21).srgb_to_linear()
	var c_warm_interior: Color = Color(0.94, 0.82, 0.58).srgb_to_linear()
	var c_plate_white: Color = Color(0.95, 0.96, 0.97).srgb_to_linear()
	var c_plate_blue: Color = Color(0.08, 0.28, 0.68).srgb_to_linear()

	# Şasi altı + ana kargo gövdesi (z = -2.45 .. +1.05, genişlik 2.08 m, yükseklik y = 0.36 .. 2.34 m)
	_box(st, vxf, Vector3(1.94, 0.18, 4.85), Vector3(0.0, 0.34, 0.05), c_black)
	# Kargo sol yan (+X: servis penceresi boşluklu!), sağ yan (-X: kapalı), arka (-Z) ve tavan
	# Alt tezgah duvarı (+X, z=-2.35..+0.45, y=0.38..1.22)
	_box(st, vxf, Vector3(0.10, 0.84, 2.82), Vector3(0.99, 0.80, -0.95), c_silver)
	# Servis penceresi ön ve arka dikmeleri (+X)
	_box(st, vxf, Vector3(0.12, 1.96, 0.58), Vector3(0.98, 1.36, 0.74), c_silver)
	_box(st, vxf, Vector3(0.12, 1.96, 0.42), Vector3(0.98, 1.36, -2.24), c_silver)
	# Sağ yan kapalı duvar (-X) + arka çift kapı (-Z)
	_box(st, vxf, Vector3(0.12, 1.96, 3.48), Vector3(-0.98, 1.36, -0.71), c_silver)
	_box(st, vxf, Vector3(2.04, 1.96, 0.12), Vector3(0.0, 1.36, -2.40), c_silver)
	# Yüksek bombeli Type-H gümüş tavan (z=-2.44..+1.15, y=2.28..2.54)
	_box(st, vxf, Vector3(2.06, 0.16, 3.60), Vector3(0.0, 2.34, -0.64), c_silver_hi)
	_box(st, vxf, Vector3(1.82, 0.14, 3.46), Vector3(0.0, 2.47, -0.64), c_silver_hi)

	# Citroën Type-H ikonik yatay oluklu sac kaburgaları (corrugated ribs — eslab_van.jpg!)
	for ri: int in 9:
		var ry: float = 0.46 + float(ri) * 0.085
		# Sol alt panel (+X, servis penceresi altı)
		_box(st, vxf, Vector3(0.032, 0.036, 2.76), Vector3(1.05, ry, -0.95), c_silver_hi if ri % 2 == 0 else c_silver_dk)
		# Sağ yan panel (-X)
		_box(st, vxf, Vector3(0.032, 0.036, 3.40), Vector3(-1.05, ry, -0.71), c_silver_hi if ri % 2 == 0 else c_silver_dk)
		# Arka kapı (-Z)
		_box(st, vxf, Vector3(1.92, 0.036, 0.032), Vector3(0.0, ry, -2.47), c_silver_hi if ri % 2 == 0 else c_silver_dk)

	# Sürücü kabini (z=+1.00..+1.95) + eğimli ön cam + Type-H alın şapkası + yan aynalar
	_box(st, vxf, Vector3(2.02, 1.05, 0.96), Vector3(0.0, 0.88, 1.48), c_silver)
	# Kabin kapısı yatay olukları
	for cri: int in 6:
		var cry: float = 0.50 + float(cri) * 0.09
		_box(st, vxf, Vector3(0.032, 0.036, 0.88), Vector3(1.025, cry, 1.48), c_silver_hi)
		_box(st, vxf, Vector3(0.032, 0.036, 0.88), Vector3(-1.025, cry, 1.48), c_silver_hi)
	# Yan kabin camları + siyah dikiz aynaları
	_box(st, vxf, Vector3(2.05, 0.66, 0.72), Vector3(0.0, 1.72, 1.36), c_glass)
	_box(st, vxf, Vector3(2.03, 0.24, 0.88), Vector3(0.0, 2.18, 1.38), c_silver_hi)
	for sgn: float in [-1.0, 1.0]:
		_box(st, vxf, Vector3(0.18, 0.28, 0.10), Vector3(sgn * 1.12, 1.62, 1.68), c_black)

	# Eğimli ön cam (z=+1.68..+2.02, y=1.36..2.08)
	var ws_xf: Transform3D = vxf * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-24.0)), Vector3(0.0, 1.72, 1.84))
	_box(st, ws_xf, Vector3(1.86, 0.78, 0.08), Vector3.ZERO, c_silver)
	_box(st, ws_xf, Vector3(1.68, 0.64, 0.10), Vector3(0.0, 0.0, 0.01), c_glass)

	# ÖN BURUN (z=+1.95..+2.60): Oluklu yan çamurluklar + Trapez dikey ızgara + Çift Chevron (/\) + Yuvarlak Far Podları!
	_box(st, vxf, Vector3(1.96, 0.96, 0.68), Vector3(0.0, 0.86, 2.24), c_silver)
	_box(st, vxf, Vector3(1.92, 0.16, 0.62), Vector3(0.0, 1.35, 2.20), c_silver_hi)
	# Ön yan oluklar
	for nri: int in 6:
		var nry: float = 0.54 + float(nri) * 0.095
		_box(st, vxf, Vector3(1.99, 0.032, 0.032), Vector3(0.0, nry, 2.585), c_silver_hi)
	# Trapez Citroën ön panjur çerçevesi + dikey krom çıtalar
	_box(st, vxf, Vector3(0.76, 0.82, 0.08), Vector3(0.0, 0.88, 2.58), c_silver_dk)
	_box(st, vxf, Vector3(0.66, 0.74, 0.09), Vector3(0.0, 0.88, 2.59), c_black)
	for gi: int in 7:
		var gx: float = -0.27 + float(gi) * 0.09
		_box(st, vxf, Vector3(0.022, 0.70, 0.10), Vector3(gx, 0.88, 2.595), c_chrome)
	# İkonik çift krom Citroën Chevron (/\) arması (eslab_van.jpg ön panjur ortası!)
	for ch_y: float in [0.96, 0.79]:
		var l_chev: Transform3D = vxf * Transform3D(Basis(Vector3.FORWARD, deg_to_rad(-38.0)), Vector3(0.11, ch_y, 2.62))
		var r_chev: Transform3D = vxf * Transform3D(Basis(Vector3.FORWARD, deg_to_rad(38.0)), Vector3(-0.11, ch_y, 2.62))
		_box(st, l_chev, Vector3(0.30, 0.042, 0.03), Vector3.ZERO, c_chrome)
		_box(st, r_chev, Vector3(0.30, 0.042, 0.03), Vector3.ZERO, c_chrome)
	# Dışa çıkıntılı yuvarlak Type-H far podları (eslab_van.jpg!)
	for hsgn: float in [-1.0, 1.0]:
		_cyl_axis_z(st, vxf, 0.17, 0.34, Vector3(hsgn * 0.64, 1.06, 2.48), 12, c_silver_hi)
		_cyl_axis_z(st, vxf, 0.13, 0.06, Vector3(hsgn * 0.64, 1.06, 2.65), 12, c_headlight)
	# Ön tampon + gerçek "34 HSK 581" TR plakası!
	_box(st, vxf, Vector3(2.02, 0.14, 0.16), Vector3(0.0, 0.36, 2.58), c_silver_dk)
	_box(st, vxf, Vector3(0.56, 0.13, 0.04), Vector3(0.0, 0.39, 2.67), c_plate_white)
	_box(st, vxf, Vector3(0.07, 0.13, 0.045), Vector3(0.245, 0.39, 2.672), c_plate_blue)
	_add_label_xf(vxf, Vector3(-0.03, 0.39, 2.70), 0.0, "EslabPlate", "34 HSK 581", 22, 0.0022, Color(0.08, 0.09, 0.11), Color(0.95, 0.96, 0.97, 0.0))

	# 4 Tekerlek + Gümüş Çelik Jant + Bombeli Krom Jant Kapağı (eslab_van.jpg!)
	for wz: float in [-1.52, 1.56]:
		# Çamurluk kemerleri
		_box(st, vxf, Vector3(2.16, 0.14, 0.86), Vector3(0.0, 0.82, wz), c_silver_hi)
		for wsgn: float in [-1.0, 1.0]:
			_cyl_axis_x(st, vxf, 0.39, 0.24, Vector3(wsgn * 0.96, 0.39, wz), 16, c_tire)
			_cyl_axis_x(st, vxf, 0.25, 0.26, Vector3(wsgn * 0.97, 0.39, wz), 14, c_silver_hi)
			_cyl_axis_x(st, vxf, 0.15, 0.28, Vector3(wsgn * 0.98, 0.39, wz), 12, c_chrome)

	# YUKARI AÇILIR SERVİS PENCERESİ KANADI (gullwing hatch, +X yönüne açık) + 2 siyah amortisör kolu!
	var hatch_xf: Transform3D = vxf * Transform3D(Basis(Vector3.FORWARD, deg_to_rad(-8.0)), Vector3(1.92, 2.30, -0.78))
	_box(st, hatch_xf, Vector3(1.78, 0.06, 2.52), Vector3.ZERO, c_silver_hi)
	_box(st, hatch_xf, Vector3(1.56, 0.025, 2.26), Vector3(0.0, -0.035, 0.0), c_warm_interior)
	for st_z: float in [-1.92, 0.36]:
		var strut_xf: Transform3D = vxf * Transform3D(Basis(Vector3.FORWARD, deg_to_rad(-36.0)), Vector3(1.32, 1.96, st_z))
		_box(st, strut_xf, Vector3(0.03, 0.78, 0.03), Vector3.ZERO, c_black)

	# İÇ KAHVE BARI & ESPRESSO EKİPMANLARI (eslab_van.jpg iç detay!)
	# İç arka duvar sıcak aydınlatma + raf + ahşap tezgah + gümüş espresso makinesi + karton bardak kuleleri + ahşap vitrin!
	_box(st, vxf, Vector3(1.76, 0.10, 2.56), Vector3(0.18, 1.24, -0.78), c_wood_bar)
	_box(st, vxf, Vector3(0.12, 1.02, 2.48), Vector3(-0.55, 1.74, -0.78), c_warm_interior)
	# Profesyonel çift gruplu krom espresso makinesi
	_box(st, vxf, Vector3(0.46, 0.44, 0.68), Vector3(0.12, 1.50, -0.25), c_chrome)
	_box(st, vxf, Vector3(0.48, 0.08, 0.70), Vector3(0.12, 1.74, -0.25), c_eslab_red)
	# Ahşap kruvasan/tatlı kutusu (eslab_van.jpg sağ kenar!)
	_box(st, vxf, Vector3(0.44, 0.34, 0.64), Vector3(0.48, 1.44, -1.62), c_wood_bar)
	# Kırmızı-beyaz Espressolab karton bardak kuleleri
	for cup_z: float in [-0.78, -0.94, -1.10]:
		_cyl(st, vxf, 0.055, 0.32, Vector3(0.56, 1.45, cup_z), 8, c_plate_white)
		_cyl(st, vxf, 0.058, 0.09, Vector3(0.56, 1.45, cup_z), 8, c_eslab_red)

	# İkonik kırmızı altı çizgili "e_" logosu (servis penceresi sol dikmesinde) + altta beyaz "ESPRESSOLAB" yazısı!
	_box(st, vxf, Vector3(0.02, 0.045, 0.24), Vector3(1.055, 1.58, 0.74), c_eslab_red)
	_add_label_xf(vxf, Vector3(1.065, 1.76, 0.74), PI * 0.5, "EslabMonogram", "e", 52, 0.0048, Color(0.92, 0.14, 0.17), Color(0.1, 0.1, 0.1, 0.0))
	_add_label_xf(vxf, Vector3(1.075, 0.96, -0.82), PI * 0.5, "EslabSideLogo", "ESPRESSOLAB", 38, 0.0044, Color(0.98, 0.98, 0.99), Color(0.10, 0.11, 0.14, 0.88))
	_add_label_xf(vxf, Vector3(1.075, 0.73, -0.82), PI * 0.5, "EslabSponsorTag", "ARTLAB Kahve Sponsoru • Coffee Truck", 22, 0.0030, Color(1.0, 0.86, 0.52), Color(0.10, 0.11, 0.14, 0.88))


# ==============================================================================
# Yardımcı Geometri Fonksiyonları
# ==============================================================================

static func _add_col_box(col_body: StaticBody3D, xf: Transform3D, size: Vector3, center: Vector3) -> void:
	var cs: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.transform = xf * Transform3D(Basis.IDENTITY, center)
	col_body.add_child(cs)


static func _wall_box_uv(st: SurfaceTool, xf: Transform3D, size: Vector3, center: Vector3) -> void:
	# 1 doku tekrarı = 4.2 m yatay × 4.0 m düşey (4 taş-tuğla almaşık kuşağı = ~1.0 m yüksekliğinde gerçek ölçek!)
	var hs: Vector3 = size * 0.5
	var tile_u: float = 4.20
	var tile_v: float = 4.00
	var faces: Array = [
		# [p00, p10, p11, p01, u_span, v_span, v_base]
		[Vector3(-hs.x, -hs.y, hs.z), Vector3(hs.x, -hs.y, hs.z), Vector3(hs.x, hs.y, hs.z), Vector3(-hs.x, hs.y, hs.z), size.x, size.y, center.y - hs.y],
		[Vector3(hs.x, -hs.y, -hs.z), Vector3(-hs.x, -hs.y, -hs.z), Vector3(-hs.x, hs.y, -hs.z), Vector3(hs.x, hs.y, -hs.z), size.x, size.y, center.y - hs.y],
		[Vector3(hs.x, -hs.y, hs.z), Vector3(hs.x, -hs.y, -hs.z), Vector3(hs.x, hs.y, -hs.z), Vector3(hs.x, hs.y, hs.z), size.z, size.y, center.y - hs.y],
		[Vector3(-hs.x, -hs.y, -hs.z), Vector3(-hs.x, -hs.y, hs.z), Vector3(-hs.x, hs.y, hs.z), Vector3(-hs.x, hs.y, -hs.z), size.z, size.y, center.y - hs.y],
		[Vector3(-hs.x, hs.y, hs.z), Vector3(hs.x, hs.y, hs.z), Vector3(hs.x, hs.y, -hs.z), Vector3(-hs.x, hs.y, -hs.z), size.x, size.z, 0.0],
	]
	for f: Array in faces:
		var v0: Vector3 = xf * (center + (f[0] as Vector3))
		var v1: Vector3 = xf * (center + (f[1] as Vector3))
		var v2: Vector3 = xf * (center + (f[2] as Vector3))
		var v3: Vector3 = xf * (center + (f[3] as Vector3))
		var u1: float = float(f[4]) / tile_u
		var vb0: float = -float(f[6]) / tile_v
		var vb1: float = -(float(f[6]) + float(f[5])) / tile_v
		var uv0: Vector2 = Vector2(0.0, vb0)
		var uv1: Vector2 = Vector2(u1, vb0)
		var uv2: Vector2 = Vector2(u1, vb1)
		var uv3: Vector2 = Vector2(0.0, vb1)
		st.set_uv(uv0); st.add_vertex(v0)
		st.set_uv(uv2); st.add_vertex(v2)
		st.set_uv(uv1); st.add_vertex(v1)
		st.set_uv(uv0); st.add_vertex(v0)
		st.set_uv(uv3); st.add_vertex(v3)
		st.set_uv(uv2); st.add_vertex(v2)


static func _box(st: SurfaceTool, xf: Transform3D, size: Vector3, center: Vector3, col: Color) -> void:
	st.set_color(col)
	var hs: Vector3 = size * 0.5
	var faces: Array = [
		[Vector3(-hs.x, -hs.y, hs.z), Vector3(hs.x, -hs.y, hs.z), Vector3(hs.x, hs.y, hs.z), Vector3(-hs.x, hs.y, hs.z)],
		[Vector3(hs.x, -hs.y, -hs.z), Vector3(-hs.x, -hs.y, -hs.z), Vector3(-hs.x, hs.y, -hs.z), Vector3(hs.x, hs.y, -hs.z)],
		[Vector3(hs.x, -hs.y, hs.z), Vector3(hs.x, -hs.y, -hs.z), Vector3(hs.x, hs.y, -hs.z), Vector3(hs.x, hs.y, hs.z)],
		[Vector3(-hs.x, -hs.y, -hs.z), Vector3(-hs.x, -hs.y, hs.z), Vector3(-hs.x, hs.y, hs.z), Vector3(-hs.x, hs.y, -hs.z)],
		[Vector3(-hs.x, hs.y, hs.z), Vector3(hs.x, hs.y, hs.z), Vector3(hs.x, hs.y, -hs.z), Vector3(-hs.x, hs.y, -hs.z)],
		[Vector3(-hs.x, -hs.y, -hs.z), Vector3(hs.x, -hs.y, -hs.z), Vector3(hs.x, -hs.y, hs.z), Vector3(-hs.x, -hs.y, hs.z)],
	]
	for f: Array in faces:
		var v0: Vector3 = xf * (center + (f[0] as Vector3))
		var v1: Vector3 = xf * (center + (f[1] as Vector3))
		var v2: Vector3 = xf * (center + (f[2] as Vector3))
		var v3: Vector3 = xf * (center + (f[3] as Vector3))
		st.add_vertex(v0); st.add_vertex(v2); st.add_vertex(v1)
		st.add_vertex(v0); st.add_vertex(v3); st.add_vertex(v2)


static func _cyl(st: SurfaceTool, xf: Transform3D, radius: float, height: float, center: Vector3, segs: int, col: Color) -> void:
	st.set_color(col)
	var hy: float = height * 0.5
	var top_c: Vector3 = xf * (center + Vector3(0.0, hy, 0.0))
	var bot_c: Vector3 = xf * (center + Vector3(0.0, -hy, 0.0))
	for i: int in segs:
		var a0: float = TAU * float(i) / float(segs)
		var a1: float = TAU * float(i + 1) / float(segs)
		var t0: Vector3 = xf * (center + Vector3(cos(a0) * radius, hy, sin(a0) * radius))
		var t1: Vector3 = xf * (center + Vector3(cos(a1) * radius, hy, sin(a1) * radius))
		var b0: Vector3 = xf * (center + Vector3(cos(a0) * radius, -hy, sin(a0) * radius))
		var b1: Vector3 = xf * (center + Vector3(cos(a1) * radius, -hy, sin(a1) * radius))
		st.add_vertex(top_c); st.add_vertex(t1); st.add_vertex(t0)
		st.add_vertex(bot_c); st.add_vertex(b0); st.add_vertex(b1)
		st.add_vertex(b0); st.add_vertex(t0); st.add_vertex(t1)
		st.add_vertex(b0); st.add_vertex(t1); st.add_vertex(b1)


static func _cyl_axis_x(st: SurfaceTool, xf: Transform3D, radius: float, width_x: float, center: Vector3, segs: int, col: Color) -> void:
	var rxf: Transform3D = xf * Transform3D(Basis(Vector3.FORWARD, PI * 0.5), center)
	_cyl(st, rxf, radius, width_x, Vector3.ZERO, segs, col)


static func _cyl_axis_z(st: SurfaceTool, xf: Transform3D, radius: float, len_z: float, center: Vector3, segs: int, col: Color) -> void:
	var rxf: Transform3D = xf * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), center)
	_cyl(st, rxf, radius, len_z, Vector3.ZERO, segs, col)


static func _add_hip_roof_local(st: SurfaceTool, hxf: Transform3D, cx: float, cz: float, w_x: float, d_z: float, y_eave: float, roof_h: float, c_tile: Color, c_ridge: Color) -> void:
	var hx: float = w_x * 0.5
	var hz: float = d_z * 0.5
	var inset: float = minf(hx, hz) * 0.88
	var rx0: float = cx - maxf(hx - inset, 0.2)
	var rx1: float = cx + maxf(hx - inset, 0.2)
	var p00: Vector3 = hxf * Vector3(cx - hx, y_eave, cz + hz)
	var p10: Vector3 = hxf * Vector3(cx + hx, y_eave, cz + hz)
	var p11: Vector3 = hxf * Vector3(cx + hx, y_eave, cz - hz)
	var p01: Vector3 = hxf * Vector3(cx - hx, y_eave, cz - hz)
	var r0: Vector3 = hxf * Vector3(rx0, y_eave + roof_h, cz)
	var r1: Vector3 = hxf * Vector3(rx1, y_eave + roof_h, cz)
	st.set_color(c_tile)
	# Ön (+Z) ve arka (-Z) yamuk yüzeyler + sol/sağ üçgen kırma yüzeyler
	st.add_vertex(p00); st.add_vertex(r1); st.add_vertex(p10)
	st.add_vertex(p00); st.add_vertex(r0); st.add_vertex(r1)
	st.add_vertex(p11); st.add_vertex(r0); st.add_vertex(p01)
	st.add_vertex(p11); st.add_vertex(r1); st.add_vertex(r0)
	st.add_vertex(p01); st.add_vertex(r0); st.add_vertex(p00)
	st.add_vertex(p10); st.add_vertex(r1); st.add_vertex(p11)
	if rx1 - rx0 > 0.3:
		_box(st, hxf, Vector3(rx1 - rx0 + 0.16, 0.13, 0.20), Vector3(cx, y_eave + roof_h + 0.04, cz), c_ridge)


static func _add_deep_recessed_arch_window(st: SurfaceTool, hxf: Transform3D, cx: float, z_front: float, y_sill: float, w: float, h: float, depth: float, c_stone: Color, c_sill: Color, c_glass: Color, c_iron: Color) -> void:
	var r: float = w * 0.5
	var rect_h: float = maxf(h - r, 0.4)
	# Beyaz mermer denizlik (uploaded_media_0 sağ kanat!)
	_box(st, hxf, Vector3(w + 0.26, 0.10, 0.22), Vector3(cx, y_sill - 0.03, z_front + 0.08), c_sill)
	# Derin taş pencere sövesi yanları
	_box(st, hxf, Vector3(0.11, rect_h, depth), Vector3(cx - r + 0.055, y_sill + rect_h * 0.5, z_front - depth * 0.5), c_stone)
	_box(st, hxf, Vector3(0.11, rect_h, depth), Vector3(cx + r - 0.055, y_sill + rect_h * 0.5, z_front - depth * 0.5), c_stone)
	# Geri çekilmiş cam yüzey + demir parmaklık kayıtları
	_box(st, hxf, Vector3(w - 0.16, rect_h + r * 0.92, 0.06), Vector3(cx, y_sill + (rect_h + r * 0.92) * 0.5, z_front - depth + 0.05), c_glass)
	for mx: float in [-w * 0.22, 0.0, w * 0.22]:
		_box(st, hxf, Vector3(0.04, h - 0.14, 0.05), Vector3(cx + mx, y_sill + (h - 0.14) * 0.5, z_front - depth + 0.09), c_iron)
	for my: float in [0.65, 1.30, 1.90]:
		if my < h - 0.18:
			_box(st, hxf, Vector3(w - 0.18, 0.04, 0.05), Vector3(cx, y_sill + my, z_front - depth + 0.09), c_iron)
	# Yuvarlak kemer taş sövesi + kemer tonozu + üst dolgu
	var arch_cy: float = y_sill + rect_h
	var n_seg: int = 10
	for ai: int in n_seg:
		var a0: float = PI * float(ai) / float(n_seg)
		var a1: float = PI * float(ai + 1) / float(n_seg)
		var x0: float = cx + cos(a0) * r
		var y0: float = arch_cy + sin(a0) * r
		var x1: float = cx + cos(a1) * r
		var y1: float = arch_cy + sin(a1) * r
		var xo0: float = cx + cos(a0) * (r + 0.20)
		var yo0: float = arch_cy + sin(a0) * (r + 0.20)
		var xo1: float = cx + cos(a1) * (r + 0.20)
		var yo1: float = arch_cy + sin(a1) * (r + 0.20)
		# Ön kemer taşı dilimi
		st.set_color(c_stone)
		var vf0: Vector3 = hxf * Vector3(x0, y0, z_front + 0.04)
		var vf1: Vector3 = hxf * Vector3(x1, y1, z_front + 0.04)
		var vfo0: Vector3 = hxf * Vector3(xo0, yo0, z_front + 0.04)
		var vfo1: Vector3 = hxf * Vector3(xo1, yo1, z_front + 0.04)
		st.add_vertex(vf0); st.add_vertex(vfo1); st.add_vertex(vf1)
		st.add_vertex(vf0); st.add_vertex(vfo0); st.add_vertex(vfo1)
		# İç kemer tonozu (z_front -> z_front - depth)
		var vb0: Vector3 = hxf * Vector3(x0, y0, z_front - depth)
		var vb1: Vector3 = hxf * Vector3(x1, y1, z_front - depth)
		st.add_vertex(vf0); st.add_vertex(vf1); st.add_vertex(vb1)
		st.add_vertex(vf0); st.add_vertex(vb1); st.add_vertex(vb0)
		# Köşe pandantif dolgusu (dikdörtgen lento altına kadar boşluk kalmasın)
		var yc0: Vector3 = hxf * Vector3(x0, y_sill + h, z_front)
		var yc1: Vector3 = hxf * Vector3(x1, y_sill + h, z_front)
		st.add_vertex(vf0); st.add_vertex(yc1); st.add_vertex(vf1)
		st.add_vertex(vf0); st.add_vertex(yc0); st.add_vertex(yc1)


static func _add_front_arched_window(st: SurfaceTool, hxf: Transform3D, cx: float, z_front: float, y_sill: float, w: float, h: float, c_stone: Color, c_sill: Color, c_glass: Color, c_iron: Color) -> void:
	var r: float = w * 0.5
	var rect_h: float = maxf(h - r, 0.35)
	_box(st, hxf, Vector3(w + 0.22, 0.09, 0.16), Vector3(cx, y_sill - 0.03, z_front + 0.05), c_sill)
	_box(st, hxf, Vector3(w + 0.16, rect_h, 0.08), Vector3(cx, y_sill + rect_h * 0.5, z_front + 0.02), c_stone)
	_box(st, hxf, Vector3(w - 0.10, rect_h, 0.09), Vector3(cx, y_sill + rect_h * 0.5, z_front + 0.04), c_glass)
	_cyl_axis_z(st, hxf, r + 0.08, 0.08, Vector3(cx, y_sill + rect_h, z_front + 0.02), 14, c_stone)
	_cyl_axis_z(st, hxf, r - 0.05, 0.095, Vector3(cx, y_sill + rect_h, z_front + 0.04), 14, c_glass)
	_box(st, hxf, Vector3(0.04, h - 0.10, 0.11), Vector3(cx, y_sill + (h - 0.10) * 0.5, z_front + 0.045), c_iron)
	_box(st, hxf, Vector3(w - 0.12, 0.04, 0.11), Vector3(cx, y_sill + rect_h * 0.55, z_front + 0.045), c_iron)


static func _add_front_arched_window_back(st: SurfaceTool, hxf: Transform3D, cx: float, z_back: float, y_sill: float, w: float, h: float, c_stone: Color, c_sill: Color, c_glass: Color, c_iron: Color) -> void:
	var bxf: Transform3D = hxf * Transform3D(Basis(Vector3.UP, PI), Vector3(cx, 0.0, z_back))
	_add_front_arched_window(st, bxf, 0.0, 0.0, y_sill, w, h, c_stone, c_sill, c_glass, c_iron)


static func _add_side_arch_opening(st: SurfaceTool, hxf: Transform3D, x_face: float, cz: float, y_sill: float, w_z: float, h: float, c_stone: Color, c_glass: Color, c_iron: Color) -> void:
	var sxf: Transform3D = hxf * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(x_face, 0.0, cz))
	_add_front_arched_window(st, sxf, 0.0, 0.0, y_sill, w_z, h, c_stone, c_stone, c_glass, c_iron)


static func _add_front_arched_door(st: SurfaceTool, hxf: Transform3D, cx: float, z_front: float, y_floor: float, w: float, h: float, c_stone: Color, c_bronze: Color, c_glow: Color) -> void:
	var r: float = w * 0.5
	var rect_h: float = maxf(h - r, 0.8)
	_box(st, hxf, Vector3(w + 0.34, rect_h, 0.12), Vector3(cx, y_floor + rect_h * 0.5, z_front + 0.03), c_stone)
	_cyl_axis_z(st, hxf, r + 0.17, 0.12, Vector3(cx, y_floor + rect_h, z_front + 0.03), 16, c_stone)
	_box(st, hxf, Vector3(w - 0.08, rect_h, 0.14), Vector3(cx, y_floor + rect_h * 0.5, z_front + 0.05), c_bronze)
	_cyl_axis_z(st, hxf, r - 0.04, 0.14, Vector3(cx, y_floor + rect_h, z_front + 0.05), 16, c_glow)
	# Çift kanatlı camlı kapı panelleri
	for sgn: float in [-1.0, 1.0]:
		_box(st, hxf, Vector3(w * 0.36, rect_h * 0.78, 0.16), Vector3(cx + sgn * w * 0.22, y_floor + rect_h * 0.46, z_front + 0.055), c_glow)


func _add_label_xf(xf: Transform3D, local_pos: Vector3, local_yaw: float, node_name: String, txt: String, fsize: int, px_size: float, col: Color, out_col: Color) -> void:
	var lbl: Label3D = Label3D.new()
	lbl.name = node_name
	lbl.text = txt
	lbl.font_size = fsize
	lbl.pixel_size = px_size
	lbl.modulate = col
	lbl.outline_size = 8 if out_col.a > 0.1 else 0
	lbl.outline_modulate = out_col
	lbl.visibility_range_end = 110.0
	lbl.transform = xf * Transform3D(Basis(Vector3.UP, local_yaw), local_pos)
	add_child(lbl)
