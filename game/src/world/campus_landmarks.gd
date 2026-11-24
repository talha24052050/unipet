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
const COL_CEREMONY_RED: Color = Color(0.56, 0.12, 0.14)
const COL_TURQUOISE: Color = Color(0.08, 0.48, 0.56)
const COL_CANOPY_GREEN: Color = Color(0.14, 0.34, 0.20)
const COL_PLANT_GREEN: Color = Color(0.24, 0.44, 0.19)


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
	_build_egitim_fakultesi(st, col_body)
	_build_yabanci_diller(st, col_body)
	_build_ring_bus_stop(st, col_body)
	_build_metro_gate_b(st, col_body)
	_build_kongre_merkezi(st, col_body)
	_build_insaat_fakultesi(st, col_body)
	_build_kimya_metalurji(st, col_body)
	_build_merkez_laboratuvari(st, col_body)
	_build_yildiz_teknopark(st, col_body)
	_build_spor_kompleksi(st, col_body)
	_build_buyuk_ev_terrace(st, col_body)
	_build_lojmanlar(st, col_body)

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

	_add_paver_xf(st, xf, 14.0, 7.5, 3.8)
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


## 3) Yeni Merkez Kütüphanesi (b#139 — TEB Mimarlık 2024, yildiz.edu.tr & mimarizm.com referansları):
## 3) Yeni Merkez Kütüphanesi (b#139 — TEB Mimarlık 2024, yildiz.edu.tr & mimarizm.com referansları):
##    - Ana kütüphane girişi yerin tam 1 kat altında (-3.50 m çökük avlu / -1. kat — lib_ytu_1.jpg & lib_ytu_4.jpg):
##      çift beyaz saçaklı siyah çerçeveli cam rüzgarlık kapıları + iç turnike parıltısı + "MERKEZ KÜTÜPHANESİ" tabelası.
##    - Kampüs kotundan (-0.42 m) 1 kat aşağı (-3.92 m) inerken:
##      • SOLDA (v = 24.95..31.25): 6 kademeli geniş sıcak ahşap amfi oturma basamakları (lib_gal_18.jpg & lib_ytu_2.jpg!)
##      • SAĞDA (v = 18.12..24.95): 20 basamaklı koyu bazalt taş yürüyüş merdiveni (lib_gal_11.jpg & lib_gal_18.jpg!)
##    - Siyah cam küp önünde üst gezinti terası + mermer bordürlü siyah metal korkuluk + -1. kat cam bağlantı galerisi.
func _build_merkez_library(st: SurfaceTool, col_body: StaticBody3D) -> void:
	var lo: Vector2 = Vector2(-74.33, -236.71)
	var lu: Vector2 = Vector2(0.809885, 0.586589)
	var lv: Vector2 = Vector2(-0.586589, 0.809885)
	var y_top: float = -0.42
	var y_sunk: float = -3.92  # Yerin tam 1 kat (3.50 m) altı!
	var lxf: Transform3D = _frame_xform(lo, lu, lv, 0.0)

	var col_stone_plaza: Color = Color(0.78, 0.77, 0.74).srgb_to_linear()
	var col_stone_edge: Color = Color(0.68, 0.67, 0.64).srgb_to_linear()
	var col_drain: Color = Color(0.22, 0.23, 0.24).srgb_to_linear()
	var col_basalt: Color = Color(0.27, 0.29, 0.32).srgb_to_linear()
	var col_step_nosing: Color = Color(0.56, 0.58, 0.60).srgb_to_linear()
	var col_amphi_wood: Color = Color(0.58, 0.39, 0.23).srgb_to_linear()
	var col_amphi_wood_dk: Color = Color(0.42, 0.27, 0.15).srgb_to_linear()
	var col_marble_curb: Color = Color(0.24, 0.26, 0.29).srgb_to_linear()
	var col_black_metal: Color = Color(0.10, 0.11, 0.13).srgb_to_linear()
	var col_gallery_glass: Color = Color(0.14, 0.21, 0.28).srgb_to_linear()
	var col_lobby_glow: Color = Color(0.76, 0.68, 0.52).srgb_to_linear()
	var col_turnstile: Color = Color(0.70, 0.74, 0.78).srgb_to_linear()
	var col_planter_leaf: Color = Color(0.18, 0.36, 0.16).srgb_to_linear()
	var col_planter_hi: Color = Color(0.25, 0.46, 0.21).srgb_to_linear()
	var col_lamp_glow: Color = Color(0.95, 0.96, 0.92).srgb_to_linear()
	var col_white_lin: Color = Color(0.94, 0.94, 0.93).srgb_to_linear()

	# 3a) Üst zemin kotu gezinti terası (siyah cam küp önü: u=18.42..58.20, v=31.25..35.60) + merdiven başı sahanlığı
	_add_box_xf(st, lxf, Vector3(39.78, 0.90, 4.35), Vector3(38.31, y_top - 0.45, 33.425), col_stone_plaza)
	_add_box_xf(st, lxf, Vector3(4.40, 0.90, 17.48), Vector3(60.40, y_top - 0.45, 26.86), col_stone_plaza)
	# Dış taş meydan bölgeleri: iç sınırda y_top (-0.42) ile sıfır basamaklı birleşir, dış kenarda doğal araziye iner
	var outer_zones: Array = [
		[62.60, 69.20, 18.12, 71.20, 4, 14],
		[50.25, 62.60, 35.60, 71.20, 4, 10],
		[18.42, 62.60, 70.00, 81.50, 11, 4],
		[18.42, 25.45, 35.60, 56.20, 2, 6],
	]
	for tz: Array in outer_zones:
		var u0: float = float(tz[0])
		var u1: float = float(tz[1])
		var v0: float = float(tz[2])
		var v1: float = float(tz[3])
		var nu: int = int(tz[4])
		var nv: int = int(tz[5])
		var du: float = (u1 - u0) / float(nu)
		var dv: float = (v1 - v0) / float(nv)
		for iu: int in nu:
			for iv: int in nv:
				var ua: float = u0 + float(iu) * du
				var ub: float = ua + du
				var va: float = v0 + float(iv) * dv
				var vb: float = va + dv
				_add_merkez_plaza_quad(st, lo, lu, lv, y_top, Vector2(ua, va), Vector2(ub, va), Vector2(ub, vb), Vector2(ua, vb), col_stone_plaza)
	# Merdiven başı sahanlığının KD dış kenarında ince taş etek (v=18.12, u=58.20..67.53 zaten Arm A duvarı; u=62.6..69.2 ince bordür)
	_add_box_xf(st, lxf, Vector3(6.60, 0.45, 0.28), Vector3(65.90, y_top - 0.35, 18.18), col_stone_edge)

	# 3b) -1. KAT ÇÖKÜK AVLU TABANI (yerin 3.50 m altında: u = 18.42..50.20, v = 18.12..31.25)
	_add_box_xf(st, lxf, Vector3(31.82, 0.50, 13.16), Vector3(34.31, y_sunk - 0.25, 24.685), col_stone_plaza)
	# Çökük avlu dikdörtgen drenaj ızgara kanalı (lib_ytu_2.jpg & lib_gal_11.jpg!)
	_add_box_xf(st, lxf, Vector3(25.80, 0.02, 0.22), Vector3(34.80, y_sunk + 0.012, 19.75), col_drain)
	_add_box_xf(st, lxf, Vector3(25.80, 0.02, 0.22), Vector3(34.80, y_sunk + 0.012, 29.65), col_drain)
	_add_box_xf(st, lxf, Vector3(0.22, 0.02, 10.12), Vector3(21.90, y_sunk + 0.012, 24.70), col_drain)
	_add_box_xf(st, lxf, Vector3(0.22, 0.02, 10.12), Vector3(47.70, y_sunk + 0.012, 24.70), col_drain)

	# 3c) 1 KAT AŞAĞI İNİŞ (u = 58.20 -> 50.20, y_top = -0.42 -> y_sunk = -3.92):
	#     • SAĞ TARAF (aşağı inerken sağda: v = 18.12..24.95): 20 koyu bazalt yürüyüş basamağı!
	var n_steps: int = 20
	var step_du: float = 8.0 / float(n_steps)
	for si: int in n_steps:
		var su: float = 58.20 - (float(si) + 0.5) * step_du
		var sy_top: float = y_top - float(si + 1) * (3.50 / float(n_steps + 1))
		var sh: float = sy_top - (y_sunk - 0.25)
		_add_box_xf(st, lxf, Vector3(step_du + 0.02, sh, 6.83), Vector3(su, sy_top - sh * 0.5, 21.535), col_basalt)
		# Basamak burunlarında ince açık granit çizgi (lib_gal_18.jpg net basamak okunurluğu!)
		_add_box_xf(st, lxf, Vector3(0.06, 0.035, 6.81), Vector3(su - step_du * 0.5 + 0.03, sy_top - 0.012, 21.535), col_step_nosing)

	#     • SOL TARAF (1 kat aşağı inerken TAM SOLDA kalan yerler: v = 24.95..31.25):
	#       6 kademeli geniş sıcak AHŞAP OTURMA AMFİSİ (lib_gal_18.jpg & lib_ytu_2.jpg!)
	var n_tiers: int = 6
	var tier_du: float = 8.0 / float(n_tiers)
	for ti: int in n_tiers:
		var tu: float = 58.20 - (float(ti) + 0.5) * tier_du
		var ty_seat: float = y_top - float(ti + 1) * 0.50  # Her kademe ergonomik 50 cm oturma yüksekliğinde!
		var th_seat: float = ty_seat - (y_sunk - 0.25)
		_add_box_xf(st, lxf, Vector3(tier_du + 0.02, th_seat, 6.30), Vector3(tu, ty_seat - th_seat * 0.5, 28.10), col_basalt)
		# Üst ahşap oturma kaplaması (3 yatay latalı sıcak ahşap bank — lib_gal_18.jpg & lib_ytu_2.jpg!)
		_add_box_xf(st, lxf, Vector3(tier_du - 0.08, 0.065, 6.18), Vector3(tu - 0.02, ty_seat + 0.032, 28.10), col_amphi_wood_dk)
		for sl: int in 3:
			var sl_u: float = tu - 0.42 + float(sl) * 0.40
			_add_box_xf(st, lxf, Vector3(0.34, 0.082, 6.14), Vector3(sl_u, ty_seat + 0.041, 28.10), col_amphi_wood)

	# 3d) Sol kenar istinat duvarı + -1. kat yeraltı cam bağlantı galerisi (v = 31.25, u = 18.42..58.20 — lib_gal_11.jpg sağ!)
	#     Amfi yan duvarı (u = 50.20..58.20): üst terası taşıyan temiz beyaz prekast yan duvar
	_add_box_xf(st, lxf, Vector3(8.02, 3.70, 0.32), Vector3(54.20, y_sunk + 1.65, 31.25), col_white_lin)
	#     Avlu boyunca (u = 18.42..50.20): üst beyaz kiriş + 6 beyaz dikey kolon + siyah kayıtlı -1. kat cam cephe!
	_add_box_xf(st, lxf, Vector3(31.80, 0.42, 0.34), Vector3(34.31, y_top - 0.21, 31.25), col_white_lin)
	_add_box_xf(st, lxf, Vector3(31.76, 3.10, 0.16), Vector3(34.31, y_sunk + 1.54, 31.28), col_gallery_glass)
	for gi: int in 6:
		var gu: float = 18.70 + float(gi) * 6.28
		_add_box_xf(st, lxf, Vector3(0.62, 3.52, 0.34), Vector3(gu, y_sunk + 1.75, 31.25), col_white_lin)
	for mi_g: int in 19:
		var mu_g: float = 19.80 + float(mi_g) * 1.62
		_add_box_xf(st, lxf, Vector3(0.07, 3.08, 0.22), Vector3(mu_g, y_sunk + 1.54, 31.24), col_black_metal)
	_add_box_xf(st, lxf, Vector3(31.76, 0.07, 0.22), Vector3(34.31, y_sunk + 1.62, 31.24), col_black_metal)

	# Üst teras kenarı boyunca (u = 18.45..58.20, v = 31.25, y = y_top) KESİNTİSİZ YATAY koyu mermer bordür + siyah korkuluk (lib_gal_18/19.jpg!)
	_add_box_xf(st, lxf, Vector3(39.80, 0.34, 0.38), Vector3(38.32, y_top + 0.17, 31.25), col_marble_curb)
	_add_box_xf(st, lxf, Vector3(39.80, 0.055, 0.055), Vector3(38.32, y_top + 1.16, 31.25), col_black_metal)
	_add_box_xf(st, lxf, Vector3(39.80, 0.035, 0.035), Vector3(38.32, y_top + 0.85, 31.25), col_black_metal)
	_add_box_xf(st, lxf, Vector3(39.80, 0.035, 0.035), Vector3(38.32, y_top + 0.56, 31.25), col_black_metal)
	for ri: int in 15:
		var ru_p: float = 18.60 + float(ri) * 2.82
		_add_box_xf(st, lxf, Vector3(0.065, 0.86, 0.065), Vector3(ru_p, y_top + 0.75, 31.25), col_black_metal)

	# 3e) YERİN 1 KAT ALTINDAKİ ANA KÜTÜPHANE GİRİŞİ (u = 18.42, v = 18.12..31.25, y = y_sunk — lib_ytu_1.jpg & lib_ytu_4.jpg!)
	#     Ortada beyaz taşıyıcı kolon (v = 24.68) + iki yanda beyaz düz saçaklı, siyah çerçeveli cam rüzgarlık giriş kapıları!
	_add_box_xf(st, lxf, Vector3(0.42, 3.92, 0.96), Vector3(18.55, y_sunk + 1.96, 24.68), col_white_lin)
	for vc_door: float in [21.55, 27.80]:
		# Beyaz düz rüzgarlık tavan tablası (lib_ytu_1.jpg alt orta & lib_ytu_4.jpg!)
		_add_box_xf(st, lxf, Vector3(1.38, 0.24, 4.45), Vector3(19.08, y_sunk + 2.62, vc_door), col_white_lin)
		# Sıcak aydınlatmalı iç giriş holü arka düzlemi + gümüş turnike kanatları ipucu
		_add_box_xf(st, lxf, Vector3(0.10, 2.48, 4.10), Vector3(18.50, y_sunk + 1.25, vc_door), col_lobby_glow)
		for ts_z: float in [-1.10, 0.0, 1.10]:
			_add_box_xf(st, lxf, Vector3(0.45, 0.96, 0.09), Vector3(18.78, y_sunk + 0.48, vc_door + ts_z), col_turnstile)
		# Siyah alüminyum çerçeveli cam rüzgarlık yan + ön yüzeyleri ve kayar kapı kayıtları
		_add_box_xf(st, lxf, Vector3(1.22, 2.50, 4.26), Vector3(19.04, y_sunk + 1.25, vc_door), col_gallery_glass)
		for dz_f: float in [-2.14, -0.92, 0.0, 0.92, 2.14]:
			_add_box_xf(st, lxf, Vector3(0.10, 2.52, 0.09), Vector3(19.66, y_sunk + 1.26, vc_door + dz_f), col_black_metal)
		_add_box_xf(st, lxf, Vector3(0.10, 0.09, 4.34), Vector3(19.66, y_sunk + 2.18, vc_door), col_black_metal)
		_add_box_xf(st, lxf, Vector3(0.10, 0.10, 4.36), Vector3(19.66, y_sunk + 2.48, vc_door), col_black_metal)
		for side_z: float in [-2.14, 2.14]:
			_add_box_xf(st, lxf, Vector3(1.26, 2.52, 0.08), Vector3(19.04, y_sunk + 1.26, vc_door + side_z), col_black_metal)

	# -1. kat giriş kapılarının tam üstündeki beyaz alınlık bandında "MERKEZ KÜTÜPHANESİ" ana giriş tabelası (+lu merdivene bakar!)
	var ent_xf: Transform3D = _frame_xform(lo + lu * 18.68 + lv * 24.68, -lv, lu, y_top)
	_add_box_xf(st, ent_xf, Vector3(7.60, 0.86, 0.12), Vector3(0.0, 0.02, 0.02), col_black_metal)
	_add_3d_sign(ent_xf, Vector3(0.0, 0.16, 0.10), "MerkezKutuphaneSign", "MERKEZ KÜTÜPHANESİ", 0.34, COL_WHITE)
	_add_label(ent_xf, Vector3(0.0, -0.22, 0.11), "MerkezKutuphaneGirisBadge", "ANA GİRİŞ  •  -1. KAT", 32, 0.0052, Color(0.85, 0.90, 0.96), Color(0.04, 0.06, 0.10))

	# 3f) Çökük avlu ekseninde (-3.92 m) ve üst terasta (-0.42 m) siyah modern YTÜ lale lambaları (lib_ytu_2.jpg & lib_gal_11.jpg!)
	var sunk_lamp_us: Array = [24.0, 31.5, 39.0, 46.5]
	for lu_l: float in sunk_lamp_us:
		var sl_xf: Transform3D = _frame_xform(lo + lu * lu_l + lv * 24.70, lu, lv, y_sunk)
		_add_cyl_xf(st, sl_xf, 0.075, 3.6, Vector3(0.0, 1.8, 0.0), 6, col_black_metal)
		for fork: float in [-1.0, 1.0]:
			_add_box_xf(st, sl_xf, Vector3(0.055, 0.72, 0.055), Vector3(fork * 0.22, 3.85, 0.0), col_black_metal)
		_add_cyl_xf(st, sl_xf, 0.34, 0.08, Vector3(0.0, 4.24, 0.0), 10, col_black_metal)
		_add_cyl_xf(st, sl_xf, 0.26, 0.04, Vector3(0.0, 4.19, 0.0), 10, col_lamp_glow)
	for ul_uv: Array in [[36.0, 33.4], [52.5, 33.4], [59.8, 33.4]]:
		var ul_xf: Transform3D = _frame_xform(lo + lu * float(ul_uv[0]) + lv * float(ul_uv[1]), lu, lv, y_top)
		_add_cyl_xf(st, ul_xf, 0.075, 3.6, Vector3(0.0, 1.8, 0.0), 6, col_black_metal)
		for fork: float in [-1.0, 1.0]:
			_add_box_xf(st, ul_xf, Vector3(0.055, 0.72, 0.055), Vector3(fork * 0.22, 3.85, 0.0), col_black_metal)
		_add_cyl_xf(st, ul_xf, 0.34, 0.08, Vector3(0.0, 4.24, 0.0), 10, col_black_metal)
		_add_cyl_xf(st, ul_xf, 0.26, 0.04, Vector3(0.0, 4.19, 0.0), 10, col_lamp_glow)

	# 3g) Çökük avlu bitkilendirmesi: sağda L-kanat boyunca 6 dikdörtgen defne saksısı + solda galeri camı önünde 3 yuvarlak palmiye saksısı (lib_gal_11.jpg!)
	for pi: int in 6:
		var pu: float = 22.8 + float(pi) * 4.9
		var pxf: Transform3D = _frame_xform(lo + lu * pu + lv * 19.05, lu, lv, y_sunk)
		_add_box_xf(st, pxf, Vector3(1.15, 0.52, 0.55), Vector3(0.0, 0.26, 0.0), col_black_metal)
		_add_foliage_blob_xf(st, pxf, Vector3(0.0, 1.25, 0.0), 0.52, 0.85, col_planter_leaf)
		_add_foliage_blob_xf(st, pxf, Vector3(0.18, 1.55, 0.05), 0.36, 0.52, col_planter_hi)
	for palm_u: float in [23.5, 34.5, 45.5]:
		var m_pxf: Transform3D = _frame_xform(lo + lu * palm_u + lv * 30.35, lu, lv, y_sunk)
		_add_cyl_xf(st, m_pxf, 0.34, 0.54, Vector3(0.0, 0.27, 0.0), 8, col_black_metal)
		_add_foliage_blob_xf(st, m_pxf, Vector3(0.0, 1.05, 0.0), 0.58, 0.62, col_planter_leaf)
		_add_foliage_blob_xf(st, m_pxf, Vector3(-0.15, 1.38, 0.08), 0.42, 0.44, col_planter_hi)

	# 3h) Üst merdiven başında yönlendirme monoliti + çarpıştırıcılar
	var m_wp: Vector2 = lo + lu * 60.4 + lv * 33.4
	var m_out: Vector2 = (lu * 0.85 + lv * 0.52).normalized()
	var m_right: Vector2 = Vector2(m_out.y, -m_out.x)
	var mxf: Transform3D = _frame_xform(m_wp, m_right, m_out, y_top)
	_add_box_xf(st, mxf, Vector3(3.8, 0.24, 0.64), Vector3(0.0, 0.12, 0.0), col_basalt)
	_add_box_xf(st, mxf, Vector3(3.5, 2.05, 0.32), Vector3(0.0, 0.24 + 1.025, 0.0), col_black_metal)
	_add_box_xf(st, mxf, Vector3(3.5, 0.24, 0.34), Vector3(0.0, 2.38, 0.0), col_white_lin)
	_add_label(mxf, Vector3(0.0, 1.32, 0.18), "MerkezKutuphaneUpperTotem", "MERKEZ KÜTÜPHANESİ\n↓ Giriş -1. Kat (Çökük Avlu)", 28, 0.0028, COL_WHITE, Color(0.06, 0.08, 0.12))
	var mcol: CollisionShape3D = CollisionShape3D.new()
	mcol.name = "MerkezKutuphaneMonolithCollider"
	var msh: BoxShape3D = BoxShape3D.new()
	msh.size = Vector3(3.8, 2.5, 0.64)
	mcol.shape = msh
	mcol.transform = mxf * Transform3D(Basis.IDENTITY, Vector3(0.0, 1.25, 0.0))
	col_body.add_child(mcol)

	# Çökük avlu tabanı çarpıştırıcısı (tekil testlerde de doğrulansın)
	var scol: CollisionShape3D = CollisionShape3D.new()
	scol.name = "MerkezKutuphaneSunkFloorCollider"
	var ssh: BoxShape3D = BoxShape3D.new()
	ssh.size = Vector3(31.8, 0.5, 13.15)
	scol.shape = ssh
	scol.transform = lxf * Transform3D(Basis.IDENTITY, Vector3(34.31, y_sunk - 0.25, 24.685))
	col_body.add_child(scol)
	_add_bench(st, col_body, lo + lu * 55.5 + lv * 42.0, lv, lu)
	_add_bench(st, col_body, lo + lu * 55.5 + lv * 52.0, lv, lu)


## 4) Fen-Edebiyat Fakültesi (b#9): giriş alınlığı, çift cam kapı ve YTÜ fakülte totemi.
func _build_fen_edebiyat(st: SurfaceTool, col_body: StaticBody3D) -> void:
	var mid: Vector2 = Vector2(155.7, -176.4)
	var out: Vector2 = Vector2(-0.62, 0.79).normalized()
	var right_dir: Vector2 = Vector2(out.y, -out.x)
	var base_y: float = TerrainHeight.active_height(mid.x, mid.y)
	var xf: Transform3D = _frame_xform(mid, right_dir, out, base_y)

	_add_paver_xf(st, xf, 11.0, 5.5, 2.8)
	_add_box_xf(st, xf, Vector3(10.0, 1.05, 0.30), Vector3(0.0, 3.45, 0.16), COL_ALUCOBOND)
	_add_box_xf(st, xf, Vector3(6.8, 2.85, 0.20), Vector3(0.0, 1.425, 0.12), COL_ANTHRACITE)
	_add_box_xf(st, xf, Vector3(6.2, 2.65, 0.10), Vector3(0.0, 1.40, 0.20), COL_GLASS)
	for mx: float in [-1.8, 0.0, 1.8]:
		_add_box_xf(st, xf, Vector3(0.08, 2.65, 0.15), Vector3(mx, 1.40, 0.22), COL_WHITE)
	_add_box_xf(st, xf, Vector3(6.2, 0.08, 0.15), Vector3(0.0, 2.15, 0.22), COL_WHITE)
	_add_3d_sign(xf, Vector3(0.0, 3.48, 0.34), "FenEdebiyatSign", "FEN-EDEBİYAT FAKÜLTESİ", 0.34, COL_ANTHRACITE)
	_build_ytu_totem(st, col_body, mid + out * 8.5 + right_dir * 5.2, right_dir, out, "FenEdebiyatTotem", "FEN-EDEBİYAT\nFAKÜLTESİ\n\n• Matematik • Fizik\n• Kimya • İstatistik\n• Moleküler Biyoloji")


## 5) Eğitim Fakültesi (b#94): giriş cephesi, çift cam kapı, 3D tabela ve YTÜ fakülte totemi.
func _build_egitim_fakultesi(st: SurfaceTool, col_body: StaticBody3D) -> void:
	var mid: Vector2 = Vector2(-239.0, -269.9)
	var out: Vector2 = Vector2(0.38, 0.92).normalized()
	var right_dir: Vector2 = Vector2(out.y, -out.x)
	var base_y: float = TerrainHeight.active_height(mid.x, mid.y)
	var xf: Transform3D = _frame_xform(mid, right_dir, out, base_y)

	_add_paver_xf(st, xf, 11.5, 6.0, 3.0)
	_add_box_xf(st, xf, Vector3(10.2, 1.05, 0.30), Vector3(0.0, 3.45, 0.16), COL_ALUCOBOND)
	_add_box_xf(st, xf, Vector3(7.0, 2.85, 0.20), Vector3(0.0, 1.425, 0.12), COL_ANTHRACITE)
	_add_box_xf(st, xf, Vector3(6.4, 2.65, 0.10), Vector3(0.0, 1.40, 0.20), COL_GLASS)
	for mx: float in [-1.8, 0.0, 1.8]:
		_add_box_xf(st, xf, Vector3(0.08, 2.65, 0.15), Vector3(mx, 1.40, 0.22), COL_WHITE)
	_add_box_xf(st, xf, Vector3(6.4, 0.08, 0.15), Vector3(0.0, 2.15, 0.22), COL_WHITE)
	_add_3d_sign(xf, Vector3(0.0, 3.48, 0.34), "EgitimFakSign", "EĞİTİM FAKÜLTESİ", 0.36, COL_ANTHRACITE)
	_build_ytu_totem(st, col_body, mid + out * 9.0 + right_dir * 5.4, right_dir, out, "EgitimFakTotem", "EĞİTİM FAKÜLTESİ\n\n• Bilgisayar ve Öğretim\n• Matematik ve Fen\n• Yabancı Diller Eğitimi")
	_add_bench(st, col_body, mid + out * 5.2 - right_dir * 4.5, right_dir, out)


## 6) Yabancı Diller Yüksekokulu (b#80): giriş kanopisi, 3D tabela ve YTÜ totemi.
func _build_yabanci_diller(st: SurfaceTool, col_body: StaticBody3D) -> void:
	var mid: Vector2 = Vector2(177.3, 470.2)
	var out: Vector2 = Vector2(-0.78, -0.63).normalized()
	var right_dir: Vector2 = Vector2(out.y, -out.x)
	var base_y: float = TerrainHeight.active_height(mid.x, mid.y)
	var xf: Transform3D = _frame_xform(mid, right_dir, out, base_y)

	_add_paver_xf(st, xf, 12.0, 6.5, 3.3)
	_add_box_xf(st, xf, Vector3(11.0, 1.05, 0.32), Vector3(0.0, 3.65, 0.18), COL_ALUCOBOND)
	_add_box_xf(st, xf, Vector3(8.8, 0.18, 2.8), Vector3(0.0, 3.25, 1.45), COL_ANTHRACITE)
	for sx: float in [-3.8, 3.8]:
		_add_box_xf(st, xf, Vector3(0.22, 3.25, 0.22), Vector3(sx, 1.625, 2.65), COL_ANTHRACITE)
	_add_box_xf(st, xf, Vector3(7.0, 2.95, 0.20), Vector3(0.0, 1.475, 0.12), COL_ANTHRACITE)
	_add_box_xf(st, xf, Vector3(6.4, 2.75, 0.10), Vector3(0.0, 1.45, 0.20), COL_GLASS)
	for mx: float in [-1.8, 0.0, 1.8]:
		_add_box_xf(st, xf, Vector3(0.08, 2.75, 0.15), Vector3(mx, 1.45, 0.22), COL_WHITE)
	_add_3d_sign(xf, Vector3(0.0, 3.68, 0.36), "YabanciDillerSign", "YABANCI DİLLER YÜKSEKOKULU", 0.32, COL_ANTHRACITE)
	_build_ytu_totem(st, col_body, mid + out * 9.5 + right_dir * 5.2, right_dir, out, "YabanciDillerTotem", "YABANCI DİLLER\nYÜKSEKOKULU\n\n• İngilizce Hazırlık\n• Modern Diller")


## 7) Ring ve Otobüs Peronu (210.0, -95.0): modern cam-çelik durak kabini, bekleme bankı ve ring tabelası.
func _build_ring_bus_stop(st: SurfaceTool, col_body: StaticBody3D) -> void:
	var wp: Vector2 = Vector2(210.0, -95.0)
	var out: Vector2 = Vector2(-0.70, 0.71).normalized()
	var right_dir: Vector2 = Vector2(out.y, -out.x)
	var by: float = TerrainHeight.active_height(wp.x, wp.y)
	var xf: Transform3D = _frame_xform(wp, right_dir, out, by)

	# Beton peron tabanı + modern koyu çelik durak çatısı + arka cam panel
	_add_box_xf(st, xf, Vector3(8.5, 0.16, 3.4), Vector3(0.0, 0.08, 0.0), COL_PAVER)
	_add_box_xf(st, xf, Vector3(6.6, 0.14, 2.2), Vector3(0.0, 2.75, 0.0), COL_ANTHRACITE)
	_add_box_xf(st, xf, Vector3(6.4, 2.35, 0.10), Vector3(0.0, 1.38, -0.95), COL_GLASS)
	for px: float in [-3.1, 0.0, 3.1]:
		_add_box_xf(st, xf, Vector3(0.14, 2.65, 0.14), Vector3(px, 1.42, -0.95), COL_ANTHRACITE)
	# Durak içi uzun ahşap bekleme bankı
	_add_box_xf(st, xf, Vector3(4.8, 0.10, 0.50), Vector3(0.0, 0.56, -0.55), COL_WOOD)
	for lx: float in [-1.8, 0.0, 1.8]:
		_add_box_xf(st, xf, Vector3(0.10, 0.42, 0.42), Vector3(lx, 0.34, -0.55), COL_ANTHRACITE)
	# Sarı-mavi Ring Durağı direği + levha
	_add_box_xf(st, xf, Vector3(0.12, 3.1, 0.12), Vector3(3.8, 1.65, 0.6), COL_ANTHRACITE)
	_add_box_xf(st, xf, Vector3(0.95, 1.15, 0.14), Vector3(3.8, 2.55, 0.6), COL_YTU_BLUE)
	_add_box_xf(st, xf, Vector3(0.95, 0.28, 0.16), Vector3(3.8, 3.18, 0.6), COL_GOLD)
	_add_label(xf, Vector3(3.8, 2.58, 0.69), "RingStopSign", "RİNG DURAĞI\nDavutpaşa\nMetro ↔ Kampüs", 26, 0.0028, COL_WHITE, Color(0.05, 0.10, 0.25))

	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "RingStopCollider"
	var sh: BoxShape3D = BoxShape3D.new()
	sh.size = Vector3(6.6, 2.8, 1.1)
	col.shape = sh
	col.transform = xf * Transform3D(Basis.IDENTITY, Vector3(0.0, 1.4, -0.6))
	col_body.add_child(col)


## 8) B Girişi — Metro Kapısı karşılama totemi (mevcut kapı takının sağ yanında, çakışmadan konumlanır).
func _build_metro_gate_b(st: SurfaceTool, col_body: StaticBody3D) -> void:
	var wp: Vector2 = Vector2(-58.5, -458.0)
	var out: Vector2 = Vector2(-0.35, 0.94).normalized()
	var right_dir: Vector2 = Vector2(out.y, -out.x)
	_build_ytu_totem(st, col_body, wp, right_dir, out, "MetroGateBSign", "DAVUTPAŞA KAMPÜSÜ\nB KAPISI (METRO)\n\nHoş Geldiniz")


## 9) Kongre ve Kültür Merkezi (b#82): e9 köşesine (7.4m) tam oturan protokol kanopisi, tören halısı, bayrak direkleri ve totem.
func _build_kongre_merkezi(st: SurfaceTool, col_body: StaticBody3D) -> void:
	var mid: Vector2 = Vector2(544.5, 247.1)
	var out: Vector2 = Vector2(0.85, -0.53).normalized()
	var right_dir: Vector2 = Vector2(out.y, -out.x)
	var base_y: float = TerrainHeight.active_height(mid.x, mid.y)
	var xf: Transform3D = _frame_xform(mid, right_dir, out, base_y)

	_add_paver_xf(st, xf, 7.6, 3.8, 1.95)
	# Protokol yürüyüş halısı (bordo-kiremit)
	_add_box_xf(st, xf, Vector3(3.4, 0.04, 3.5), Vector3(0.0, 0.12, 1.85), COL_CEREMONY_RED)
	_add_box_xf(st, xf, Vector3(7.4, 1.05, 0.34), Vector3(0.0, 3.95, 0.18), COL_ALUCOBOND)
	_add_box_xf(st, xf, Vector3(7.0, 0.20, 2.5), Vector3(0.0, 3.55, 1.30), COL_ANTHRACITE)
	for sx: float in [-3.1, 3.1]:
		_add_box_xf(st, xf, Vector3(0.24, 3.55, 0.24), Vector3(sx, 1.775, 2.35), COL_ANTHRACITE)
	_add_box_xf(st, xf, Vector3(5.8, 3.2, 0.20), Vector3(0.0, 1.60, 0.12), COL_ANTHRACITE)
	_add_box_xf(st, xf, Vector3(5.2, 2.95, 0.10), Vector3(0.0, 1.56, 0.20), COL_GLASS)
	for mx: float in [-1.6, 0.0, 1.6]:
		_add_box_xf(st, xf, Vector3(0.08, 2.95, 0.15), Vector3(mx, 1.56, 0.22), COL_WHITE)
	_add_box_xf(st, xf, Vector3(5.2, 0.08, 0.15), Vector3(0.0, 2.32, 0.22), COL_WHITE)
	_add_3d_sign(xf, Vector3(0.0, 3.98, 0.38), "KongreMerkeziSign", "KONGRE VE KÜLTÜR MERKEZİ", 0.28, COL_ANTHRACITE)

	# 3 tören bayrak direği (e8 önü çim şeridinde, yol ve ağaçlardan açık)
	var flag_cols: Array[Color] = [COL_CEREMONY_RED, COL_YTU_BLUE, COL_GOLD]
	for idx: int in 3:
		var fp: Vector2 = Vector2(540.0 - float(idx) * 2.2, 240.0)
		var fy: float = TerrainHeight.active_height(fp.x, fp.y)
		var fxf: Transform3D = _frame_xform(fp, right_dir, out, fy)
		_add_cyl_xf(st, fxf, 0.22, 0.30, Vector3(0.0, 0.10, 0.0), 8, COL_STONE_DARK)
		_add_cyl_xf(st, fxf, 0.07, 6.4, Vector3(0.0, 3.3, 0.0), 8, COL_SILVER)
		_add_box_xf(st, fxf, Vector3(1.55, 0.96, 0.05), Vector3(0.80, 5.95, 0.0), flag_cols[idx])

	# Protokol totemi (giriş sağı e10 önünde, ağaçtan ve döner kavşaktan tamamen açık)
	_build_ytu_totem(st, col_body, Vector2(548.2, 253.8), right_dir, out, "KongreTotem", "DAVUTPAŞA\nKONGRE VE KÜLTÜR\nMERKEZİ\n\n• Ana Oditoryum\n• Seminer Salonları")
	_add_bench(st, col_body, Vector2(547.0, 257.5), Vector2(0.24, 0.97), Vector2(0.97, -0.24))


## 10) İnşaat Fakültesi (b#55, E Blok): modern Alucobond giriş alınlığı, çift cam kapı, 3D tabela ve YTÜ totemi.
func _build_insaat_fakultesi(st: SurfaceTool, col_body: StaticBody3D) -> void:
	var mid: Vector2 = Vector2(-87.9, 297.5)
	var out: Vector2 = Vector2(0.78, 0.63).normalized()
	var right_dir: Vector2 = Vector2(out.y, -out.x)
	var base_y: float = TerrainHeight.active_height(mid.x, mid.y)
	var xf: Transform3D = _frame_xform(mid, right_dir, out, base_y)

	_add_paver_xf(st, xf, 12.0, 6.0, 3.0)
	_add_box_xf(st, xf, Vector3(10.6, 1.05, 0.32), Vector3(0.0, 3.55, 0.18), COL_ALUCOBOND)
	_add_box_xf(st, xf, Vector3(7.2, 2.95, 0.20), Vector3(0.0, 1.475, 0.12), COL_ANTHRACITE)
	_add_box_xf(st, xf, Vector3(6.6, 2.75, 0.10), Vector3(0.0, 1.45, 0.20), COL_GLASS)
	for mx: float in [-1.9, 0.0, 1.9]:
		_add_box_xf(st, xf, Vector3(0.08, 2.75, 0.15), Vector3(mx, 1.45, 0.22), COL_WHITE)
	_add_box_xf(st, xf, Vector3(6.6, 0.08, 0.15), Vector3(0.0, 2.20, 0.22), COL_WHITE)
	_add_3d_sign(xf, Vector3(0.0, 3.58, 0.36), "InsaatFakSign", "İNŞAAT FAKÜLTESİ", 0.36, COL_ANTHRACITE)
	_build_ytu_totem(st, col_body, mid + out * 9.0 + right_dir * 5.2, right_dir, out, "InsaatFakTotem", "İNŞAAT FAKÜLTESİ\n\n• İnşaat Mühendisliği\n• Harita Mühendisliği\n• Çevre Mühendisliği")
	_add_bench(st, col_body, mid + out * 4.8 - right_dir * 4.6, right_dir, out)


## 11) Kimya-Metalurji Fakültesi (b#14, D Blok): giriş alınlığı, çift cam kapı, 3D tabela ve YTÜ totemi.
func _build_kimya_metalurji(st: SurfaceTool, col_body: StaticBody3D) -> void:
	var mid: Vector2 = Vector2(242.8, -233.2)
	var out: Vector2 = Vector2(-0.78, -0.62).normalized()
	var right_dir: Vector2 = Vector2(out.y, -out.x)
	var base_y: float = TerrainHeight.active_height(mid.x, mid.y)
	var xf: Transform3D = _frame_xform(mid, right_dir, out, base_y)

	_add_paver_xf(st, xf, 12.0, 6.0, 3.0)
	_add_box_xf(st, xf, Vector3(11.4, 1.05, 0.32), Vector3(0.0, 3.55, 0.18), COL_ALUCOBOND)
	_add_box_xf(st, xf, Vector3(7.2, 2.95, 0.20), Vector3(0.0, 1.475, 0.12), COL_ANTHRACITE)
	_add_box_xf(st, xf, Vector3(6.6, 2.75, 0.10), Vector3(0.0, 1.45, 0.20), COL_GLASS)
	for mx: float in [-1.9, 0.0, 1.9]:
		_add_box_xf(st, xf, Vector3(0.08, 2.75, 0.15), Vector3(mx, 1.45, 0.22), COL_WHITE)
	_add_box_xf(st, xf, Vector3(6.6, 0.08, 0.15), Vector3(0.0, 2.20, 0.22), COL_WHITE)
	_add_3d_sign(xf, Vector3(0.0, 3.58, 0.36), "KimyaMetalurjiSign", "KİMYA - METALURJİ FAKÜLTESİ", 0.31, COL_ANTHRACITE)
	_build_ytu_totem(st, col_body, mid + out * 9.0 + right_dir * 5.4, right_dir, out, "KimyaMetalurjiTotem", "KİMYA - METALURJİ\nFAKÜLTESİ\n\n• Kimya Müh. • Metalurji\n• Biyomühendislik\n• Gıda Mühendisliği")
	_add_bench(st, col_body, mid + out * 4.8 - right_dir * 4.6, right_dir, out)


## 12) YTÜ Merkez Laboratuvarı (b#103): koyu çelik kanopi, cam giriş ve laboratuvar totemi.
func _build_merkez_laboratuvari(st: SurfaceTool, col_body: StaticBody3D) -> void:
	var mid: Vector2 = Vector2(-25.3, 538.7)
	var out: Vector2 = Vector2(0.86, 0.51).normalized()
	var right_dir: Vector2 = Vector2(out.y, -out.x)
	var base_y: float = TerrainHeight.active_height(mid.x, mid.y)
	var xf: Transform3D = _frame_xform(mid, right_dir, out, base_y)

	_add_paver_xf(st, xf, 11.5, 6.2, 3.1)
	_add_box_xf(st, xf, Vector3(10.8, 1.05, 0.32), Vector3(0.0, 3.70, 0.18), COL_ALUCOBOND)
	_add_box_xf(st, xf, Vector3(8.6, 0.18, 2.6), Vector3(0.0, 3.30, 1.35), COL_ANTHRACITE)
	for sx: float in [-3.7, 3.7]:
		_add_box_xf(st, xf, Vector3(0.22, 3.30, 0.22), Vector3(sx, 1.65, 2.45), COL_ANTHRACITE)
	_add_box_xf(st, xf, Vector3(6.8, 2.95, 0.20), Vector3(0.0, 1.475, 0.12), COL_ANTHRACITE)
	_add_box_xf(st, xf, Vector3(6.2, 2.75, 0.10), Vector3(0.0, 1.45, 0.20), COL_GLASS)
	for mx: float in [-1.8, 0.0, 1.8]:
		_add_box_xf(st, xf, Vector3(0.08, 2.75, 0.15), Vector3(mx, 1.45, 0.22), COL_WHITE)
	_add_3d_sign(xf, Vector3(0.0, 3.72, 0.36), "MerkezLabSign", "YTÜ MERKEZ LABORATUVARI", 0.32, COL_ANTHRACITE)
	_build_ytu_totem(st, col_body, mid + out * 9.0 + right_dir * 5.0, right_dir, out, "MerkezLabTotem", "YTÜ MERKEZ\nLABORATUVARI\n\n• Bilim ve Teknoloji\n• İleri Araştırma")


## 13) Yıldız Teknopark Yönetim Binası (b#93): teknoloji portali, 3D tabela ve turkuaz-antrasit Teknopark totemi.
func _build_yildiz_teknopark(st: SurfaceTool, col_body: StaticBody3D) -> void:
	var mid: Vector2 = Vector2(-157.6, 533.9)
	var out: Vector2 = Vector2(-0.69, -0.72).normalized()
	var right_dir: Vector2 = Vector2(out.y, -out.x)
	var base_y: float = TerrainHeight.active_height(mid.x, mid.y)
	var xf: Transform3D = _frame_xform(mid, right_dir, out, base_y)

	_add_paver_xf(st, xf, 13.0, 7.0, 3.5)
	# Modern koyu antrasit-gümüş teknoloji portali
	_add_box_xf(st, xf, Vector3(10.6, 1.15, 0.42), Vector3(0.0, 3.95, 0.24), COL_ANTHRACITE)
	_add_box_xf(st, xf, Vector3(10.6, 0.12, 0.46), Vector3(0.0, 4.55, 0.26), COL_TURQUOISE)
	for sx: float in [-4.8, 4.8]:
		_add_box_xf(st, xf, Vector3(0.55, 3.65, 0.42), Vector3(sx, 1.825, 0.24), COL_ANTHRACITE)
	_add_box_xf(st, xf, Vector3(8.4, 3.25, 0.14), Vector3(0.0, 1.625, 0.18), COL_GLASS)
	for mx: float in [-2.6, 0.0, 2.6]:
		_add_box_xf(st, xf, Vector3(0.09, 3.25, 0.18), Vector3(mx, 1.625, 0.20), COL_SILVER)
	_add_3d_sign(xf, Vector3(0.0, 3.98, 0.48), "TeknoparkSign", "YILDIZ TEKNOPARK", 0.38, COL_SILVER)

	# Teknopark özel turkuaz-antrasit totemi
	var tp: Vector2 = mid + out * 9.5 + right_dir * 5.6
	var ty: float = TerrainHeight.active_height(tp.x, tp.y)
	var txf: Transform3D = _frame_xform(tp, right_dir, out, ty)
	_add_box_xf(st, txf, Vector3(1.55, 0.22, 0.52), Vector3(0.0, 0.11, 0.0), COL_STONE_DARK)
	_add_box_xf(st, txf, Vector3(1.42, 2.05, 0.26), Vector3(0.0, 0.22 + 1.025, 0.0), COL_ANTHRACITE)
	_add_box_xf(st, txf, Vector3(1.42, 1.02, 0.26), Vector3(0.0, 2.27 + 0.51, 0.0), COL_TURQUOISE)
	_add_label(txf, Vector3(0.0, 2.75, 0.15), "TeknoparkTotemTitle", "YILDIZ TEKNOPARK", 28, 0.0028, COL_WHITE, Color(0.05, 0.14, 0.18))
	_add_label(txf, Vector3(0.0, 1.38, 0.15), "TeknoparkTotemBody", "YÖNETİM BİNASI\n\n• Ar-Ge Merkezleri\n• Kuluçka & İnovasyon", 28, 0.0026, COL_SILVER, Color.TRANSPARENT)
	var tcol: CollisionShape3D = CollisionShape3D.new()
	var tsh: BoxShape3D = BoxShape3D.new()
	tsh.size = Vector3(1.55, 3.4, 0.52)
	tcol.shape = tsh
	tcol.transform = txf * Transform3D(Basis.IDENTITY, Vector3(0.0, 1.7, 0.0))
	col_body.add_child(tcol)
	_add_bench(st, col_body, mid + out * 5.4 - right_dir * 4.8, right_dir, out)


## 14) Spor Kompleksi & Kapalı Yüzme Havuzu (b#95): giriş kanopisi, cam kapı, 3D tabela, YTÜ totemi ve bisiklet parkı.
func _build_spor_kompleksi(st: SurfaceTool, col_body: StaticBody3D) -> void:
	var mid: Vector2 = Vector2(-282.1, -232.9)
	var out: Vector2 = Vector2(0.65, -0.76).normalized()
	var right_dir: Vector2 = Vector2(out.y, -out.x)
	var base_y: float = TerrainHeight.active_height(mid.x, mid.y)
	var xf: Transform3D = _frame_xform(mid, right_dir, out, base_y)

	_add_paver_xf(st, xf, 14.0, 7.0, 3.5)
	_add_box_xf(st, xf, Vector3(12.4, 1.08, 0.34), Vector3(0.0, 3.65, 0.18), COL_ALUCOBOND)
	_add_box_xf(st, xf, Vector3(9.6, 0.18, 2.8), Vector3(0.0, 3.25, 1.45), COL_YTU_BLUE)
	for sx: float in [-4.2, 4.2]:
		_add_box_xf(st, xf, Vector3(0.24, 3.25, 0.24), Vector3(sx, 1.625, 2.65), COL_ANTHRACITE)
	_add_box_xf(st, xf, Vector3(7.4, 2.95, 0.20), Vector3(0.0, 1.475, 0.12), COL_ANTHRACITE)
	_add_box_xf(st, xf, Vector3(6.8, 2.75, 0.10), Vector3(0.0, 1.45, 0.20), COL_GLASS)
	for mx: float in [-2.0, 0.0, 2.0]:
		_add_box_xf(st, xf, Vector3(0.08, 2.75, 0.15), Vector3(mx, 1.45, 0.22), COL_WHITE)
	_add_3d_sign(xf, Vector3(0.0, 3.68, 0.38), "SporKompleksiSign", "SPOR KOMPLEKSİ • YÜZME HAVUZU", 0.30, COL_ANTHRACITE)
	_build_ytu_totem(st, col_body, mid + out * 9.5 + right_dir * 5.6, right_dir, out, "SporKompleksiTotem", "SPOR KOMPLEKSİ\n\n• Kapalı Yüzme Havuzu\n• Fitness & Basketbol")
	# Giriş sol yanında 4 bisiklet park kemeri
	for i: int in 4:
		var rx: float = -4.2 - float(i) * 0.9
		_add_box_xf(st, xf, Vector3(0.07, 0.07, 1.05), Vector3(rx, 0.78, 5.2), COL_SILVER)
		for sz: float in [-0.48, 0.48]:
			_add_box_xf(st, xf, Vector3(0.07, 0.78, 0.07), Vector3(rx, 0.39, 5.2 + sz), COL_SILVER)


## 15) Büyük Ev & Yemekhane–Büyük Ev Bulvarı (Google Haritalar 4 fotoğraf referansı):
## - Ön alınlıkta kırmızı çatı ikonuyla ışıklı "BÜYÜK EV — RESTAURANT • CAFE —" tabelası
## - Sundurma altında kafe masa/sandalyeleri + siyah ayaklı menü panosu
## - Bulvar boyunca pembe beton kaldırım, pembe çiçekli erguvan/süs eriği ağaçları, siyah lale başlı YTÜ lambaları,
##   yeşil YTÜ çöp kutuları ve Yemekhane–Büyük Ev arası beyaz yaya geçitleri (zebra crosswalk).
func _build_buyuk_ev_terrace(st: SurfaceTool, col_body: StaticBody3D) -> void:
	# 1) Büyük Ev ön cephe ekseni (edge 0: [-39.21,-58.72] -> [-25.91,-48.23], dışa bakan yön GB)
	var p0: Vector2 = Vector2(-39.21, -58.72)
	var p1: Vector2 = Vector2(-25.91, -48.23)
	var right_dir: Vector2 = (p1 - p0).normalized()         # soldan sağa (+X)
	var out: Vector2 = Vector2(-right_dir.y, right_dir.x)   # cepheden dışarı GB (+Z)
	var front_mid: Vector2 = (p0 + p1) * 0.5                # (-32.56, -53.48)
	var porch_mid: Vector2 = front_mid + out * 4.4
	var base_y: float = TerrainHeight.active_height(front_mid.x, front_mid.y)
	var xf: Transform3D = _frame_xform(porch_mid, right_dir, out, base_y)

	# Işıklı "^ BÜYÜK EV / — RESTAURANT • CAFE —" alınlık tabelası (link1.jpg & link2.jpg)
	# (z=+0.34: buyukev.glb koyu arka plakasının tam önüne net oturur)
	var sign_root: Node3D = Node3D.new()
	sign_root.name = "BuyukEvSign"
	sign_root.transform = xf * Transform3D(Basis.IDENTITY, Vector3(0.0, 5.12, 0.34))
	add_child(sign_root)

	var red_neon: StandardMaterial3D = StandardMaterial3D.new()
	red_neon.albedo_color = Color(0.96, 0.20, 0.18)
	red_neon.emission_enabled = true
	red_neon.emission = Color(0.98, 0.22, 0.18)
	red_neon.emission_energy_multiplier = 0.85
	# Üstte kırmızı çatı chevron '^' (sol ve sağ eğik bar — BÜYÜK EV üstünde temiz boşluklu)
	for side: float in [-1.0, 1.0]:
		var bar_mi: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		bm.size = Vector3(1.48, 0.10, 0.08)
		bm.material = red_neon
		bar_mi.mesh = bm
		bar_mi.position = Vector3(side * 0.67, 0.49, 0.0)
		bar_mi.rotation.z = -side * 0.19
		bar_mi.visibility_range_end = 130.0
		sign_root.add_child(bar_mi)
	# Alt iki kısa kırmızı çizgi (— RESTAURANT • CAFE —)
	for side: float in [-1.0, 1.0]:
		var d_mi: MeshInstance3D = MeshInstance3D.new()
		var dbm: BoxMesh = BoxMesh.new()
		dbm.size = Vector3(0.42, 0.055, 0.06)
		dbm.material = red_neon
		d_mi.mesh = dbm
		d_mi.position = Vector3(side * 1.40, -0.40, 0.0)
		d_mi.visibility_range_end = 110.0
		sign_root.add_child(d_mi)

	# Parlak beyaz 3D "BÜYÜK EV" + altta "RESTAURANT • CAFE"
	var main_tm: TextMesh = TextMesh.new()
	main_tm.text = "BÜYÜK EV"
	main_tm.font_size = 64
	main_tm.pixel_size = 0.45 / 48.0
	main_tm.depth = 0.08
	main_tm.curve_step = 2.5
	var wmat: StandardMaterial3D = StandardMaterial3D.new()
	wmat.albedo_color = Color(0.99, 0.99, 1.0)
	wmat.emission_enabled = true
	wmat.emission = Color(0.99, 0.99, 1.0)
	wmat.emission_energy_multiplier = 0.45
	main_tm.material = wmat
	var main_mi: MeshInstance3D = MeshInstance3D.new()
	main_mi.mesh = main_tm
	main_mi.position = Vector3(0.0, -0.05, 0.02)
	main_mi.visibility_range_end = 130.0
	sign_root.add_child(main_mi)

	var sub_lbl: Label3D = Label3D.new()
	sub_lbl.text = "RESTAURANT • CAFE"
	sub_lbl.font_size = 38
	sub_lbl.pixel_size = 0.0044
	sub_lbl.modulate = Color(0.98, 0.98, 1.0)
	sub_lbl.outline_size = 4
	sub_lbl.outline_modulate = Color(0.10, 0.10, 0.14)
	sub_lbl.position = Vector3(0.0, -0.40, 0.06)
	sub_lbl.visibility_range_end = 100.0
	sign_root.add_child(sub_lbl)

	# 2) Sundurma altı kafe masa/sandalyeleri + siyah ayaklı menü panosu (link1.jpg & link2.jpg)
	var chair_col: Color = Color(0.76, 0.68, 0.56)
	var tbl_col: Color = Color(0.24, 0.22, 0.20)
	for tx: float in [-5.6, -4.0, 0.6, 4.2, 5.8]:
		var tz: float = -2.2
		_add_box_xf(st, xf, Vector3(1.15, 0.07, 0.78), Vector3(tx, 1.22, tz), tbl_col)
		_add_box_xf(st, xf, Vector3(0.10, 0.72, 0.10), Vector3(tx, 0.84, tz), COL_ANTHRACITE)
		for cs: float in [-0.58, 0.58]:
			_add_box_xf(st, xf, Vector3(0.42, 0.44, 0.42), Vector3(tx, 0.70, tz + cs), chair_col)
	# Girişte siyah ayaklı menü panosu
	_add_box_xf(st, xf, Vector3(0.58, 0.92, 0.08), Vector3(-0.65, 0.94, -0.85), COL_ANTHRACITE)
	_add_box_xf(st, xf, Vector3(0.46, 0.76, 0.02), Vector3(-0.65, 0.96, -0.80), Color(0.86, 0.84, 0.80))

	# 3) Yemekhane–Büyük Ev orta bulvarı koridor detayları (link3.jpg & link4.jpg):
	#    - Büyük Ev tarafında pembe-kiremit beton kaldırım, pembe çiçekli süs eriği/erguvan ağaçları,
	#      siyah lale başlı YTÜ lambaları ve yeşil YTÜ çöp kutuları
	#    - Orta asfalt bulvar üzerinde iki beyaz yaya geçidi (zebra crosswalk) + dur çizgileri
	var b_a: Vector2 = Vector2(-68.11, -45.68)  # Mescit/Yemekhane köşesi (along = 0)
	var b_b: Vector2 = Vector2(-16.94, -127.76) # EEF tarafı (along = 96.7)
	var along: Vector2 = (b_b - b_a).normalized()          # KD bulvar ekseni
	var to_bev: Vector2 = Vector2(-along.y, along.x)       # GD Büyük Ev yönü (+across)
	var pink_walk: Color = Color(0.60, 0.34, 0.30)
	var pink_blossom: Color = Color(0.86, 0.56, 0.68)
	var pink_blossom_hi: Color = Color(0.93, 0.72, 0.80)
	var pink_blossom_lo: Color = Color(0.74, 0.43, 0.56)
	var ytu_bin_green: Color = Color(0.14, 0.44, 0.22)
	var lamp_glow: Color = Color(0.95, 0.96, 0.92)
	var curb_yel: Color = Color(0.90, 0.74, 0.14)
	var curb_wht: Color = Color(0.91, 0.91, 0.89)
	# p#332 (Büyük Ev kenarı tek yön bulvar) gerçek eğri ekseni across(s):
	# (-0.4, 3.89) -> (26.3, 5.56) -> (51.1, 5.55) -> (96.7, 3.92)
	var a332 := func(s: float) -> float:
		if s <= 26.3:
			return lerpf(3.89, 5.56, clampf((s + 0.4) / 26.7, 0.0, 1.0))
		if s <= 51.1:
			return 5.56
		return lerpf(5.56, 3.92, clampf((s - 51.1) / 45.6, 0.0, 1.0))

	# 3a) Büyük Ev & Mescit boyunca pürüzsüz pembe-kiremit kaldırım şeridi (link3.jpg & link4.jpg)
	#     p#332 yol eğrisini birebir izler; mavi bisiklet yolunun hemen dışından başlayarak p#193 gri
	#     parke şeridini tamamen kapatır. Yemekhane (sol) bordürünü road_asphalt.gdshader eğriye tam boyar.
	for seg_i: int in 20:
		var s0: float = 2.0 + float(seg_i) * 4.8
		var s1: float = s0 + 4.8
		var sp0: Vector2 = b_a + along * s0 + to_bev * (a332.call(s0) + 3.32)
		var sp1: Vector2 = b_a + along * s1 + to_bev * (a332.call(s1) + 3.32)
		var seg_dir: Vector2 = (sp1 - sp0).normalized()
		var seg_out: Vector2 = Vector2(-seg_dir.y, seg_dir.x)
		var wp: Vector2 = 0.5 * (sp0 + sp1)
		var wy: float = TerrainHeight.active_height(wp.x, wp.y)
		var sxf: Transform3D = _frame_xform(wp, seg_dir, seg_out, wy)
		_add_box_xf(st, sxf, Vector3(sp0.distance_to(sp1) + 0.14, 0.06, 3.10), Vector3(0.0, 0.122, 0.0), pink_walk)

	# Büyük Ev bulvar kenarında (mavi bisiklet yolu ile pembe kaldırım sınırında) eğriyi izleyen
	# gerçek 3D sarı-beyaz dönüşümlü bordür taşları (link3.jpg & link4.jpg!)
	for ci: int in 94:
		var cs: float = 3.0 + float(ci) * 0.96
		if absf(cs - 28.5) < 2.2:
			continue  # yaya geçidi ağzı açık kalsın
		var c_col: Color = curb_yel if (ci % 2 == 0) else curb_wht
		var cp0: Vector2 = b_a + along * (cs - 0.48) + to_bev * (a332.call(cs - 0.48) + 1.78)
		var cp1: Vector2 = b_a + along * (cs + 0.48) + to_bev * (a332.call(cs + 0.48) + 1.78)
		var cdir: Vector2 = (cp1 - cp0).normalized()
		var cout: Vector2 = Vector2(-cdir.y, cdir.x)
		var rp: Vector2 = 0.5 * (cp0 + cp1)
		var ry: float = TerrainHeight.active_height(rp.x, rp.y)
		var rxf: Transform3D = _frame_xform(rp, cdir, cout, ry)
		_add_box_xf(st, rxf, Vector3(0.92, 0.16, 0.24), Vector3(0.0, 0.095, 0.0), c_col)

	# 3b) Siyah lale başlı modern YTÜ sokak lambaları + yeşil çöp kutuları + pembe çiçekli ağaçlar
	for idx: int in 7:
		var s_pos: float = 6.0 + float(idx) * 14.0
		var road_a: float = a332.call(s_pos)
		# Siyah modern YTÜ lale lamba (kaldırımın yol kenarı tarafında, link3.jpg & link4.jpg!)
		var lp: Vector2 = b_a + along * s_pos + to_bev * (road_a + 2.25)
		var ly: float = TerrainHeight.active_height(lp.x, lp.y)
		var lxf: Transform3D = _frame_xform(lp, along, to_bev, ly)
		_add_cyl_xf(st, lxf, 0.075, 3.6, Vector3(0.0, 1.8, 0.0), 6, COL_ANTHRACITE)
		# İki kollu lale/çatal başlık + üst disk LED armatür (link3.jpg & link4.jpg!)
		for fork: float in [-1.0, 1.0]:
			_add_box_xf(st, lxf, Vector3(0.055, 0.72, 0.055), Vector3(fork * 0.22, 3.85, 0.0), COL_ANTHRACITE)
		_add_cyl_xf(st, lxf, 0.34, 0.08, Vector3(0.0, 4.24, 0.0), 10, COL_ANTHRACITE)
		_add_cyl_xf(st, lxf, 0.26, 0.04, Vector3(0.0, 4.19, 0.0), 10, lamp_glow)

		# Her 2 lambada bir yeşil YTÜ çöp kutusu (pembe kaldırımın dış çim kenarında)
		if idx % 2 == 0:
			var gp_a: float = a332.call(s_pos + 3.2)
			var gp: Vector2 = b_a + along * (s_pos + 3.2) + to_bev * (gp_a + 5.10)
			var gy: float = TerrainHeight.active_height(gp.x, gp.y)
			var gxf: Transform3D = _frame_xform(gp, along, to_bev, gy)
			_add_box_xf(st, gxf, Vector3(0.46, 0.88, 0.40), Vector3(0.0, 0.44, 0.0), ytu_bin_green)
			_add_box_xf(st, gxf, Vector3(0.24, 0.24, 0.04), Vector3(0.0, 0.56, -0.21), COL_WHITE)

		# Büyük Ev kış bahçesi önünde organik çok-yüzlü pembe çiçekli erguvan / süs eriği ağaçları (link3.jpg!)
		if s_pos >= 18.0 and s_pos <= 86.0:
			var tp_a: float = a332.call(s_pos + 5.0)
			var tp: Vector2 = b_a + along * (s_pos + 5.0) + to_bev * (tp_a + 6.45)
			var ty: float = TerrainHeight.active_height(tp.x, tp.y)
			var txf: Transform3D = _frame_xform(tp, along, to_bev, ty)
			_add_cyl_xf(st, txf, 0.11, 2.45, Vector3(0.0, 1.22, 0.0), 6, Color(0.42, 0.35, 0.31))
			_add_foliage_blob_xf(st, txf, Vector3(0.0, 3.25, 0.0), 1.55, 1.35, pink_blossom)
			_add_foliage_blob_xf(st, txf, Vector3(0.65, 3.65, -0.35), 1.05, 0.95, pink_blossom_hi)
			_add_foliage_blob_xf(st, txf, Vector3(-0.62, 2.95, 0.38), 1.00, 0.90, pink_blossom_lo)

	# 3c) Orta asfalt bulvar üzerinde 2 adet net beyaz yaya geçidi (zebra crosswalk — link4.jpg!)
	#     y = +0.126 (tüm yol şeritlerinin üstünde kesintisiz parlak beyaz şeritler, bisiklet yollarına taşmadan)
	for cross_s: float in [0.5, 28.5]:
		var center_across: float = 0.0 if cross_s < 10.0 else 1.64
		var cwp: Vector2 = b_a + along * cross_s + to_bev * center_across
		var cy: float = TerrainHeight.active_height(cwp.x, cwp.y)
		var cxf: Transform3D = _frame_xform(cwp, along, to_bev, cy)
		# Yalnızca ön yaya geçidinde (cross_s = 0.5) altındaki p#115 parke şeridini road_asphalt ile
		# aynı koyulukta lineer asfalt tonuyla (0.055, 0.063, 0.076) kapat; cross_s = 28.5 zaten saf asfalt!
		if cross_s < 10.0:
			_add_box_xf(st, cxf, Vector3(3.6, 0.02, 9.2), Vector3(0.0, 0.118, 0.0), Color(0.055, 0.063, 0.076))
		# 8 beyaz zebra şeridi (sadece araç şeritleri arasında, mavi bisiklet yollarına taşmadan — link4.jpg!)
		for zi: int in 8:
			var z_off: float = -3.5 + float(zi) * 1.00
			var sp_pt: Vector2 = cwp + to_bev * z_off
			var dy: float = TerrainHeight.active_height(sp_pt.x, sp_pt.y) - cy
			_add_box_xf(st, cxf, Vector3(2.95, 0.022, 0.52), Vector3(0.0, dy + 0.128, z_off), Color(0.95, 0.95, 0.93))
		# İki yanda kendi şeridi içinde kalan beyaz dur çizgileri (orta çift çizgiyi geçmeden)
		for side_stop: float in [-2.35, 2.35]:
			_add_box_xf(st, cxf, Vector3(0.28, 0.022, 3.6), Vector3(side_stop, 0.126, -2.2 if side_stop < 0.0 else 2.2), Color(0.93, 0.93, 0.91))

	# 3d) Sol tarafta (Yemekhane önü çim sınırı) alçak siyah demir korkuluk çiti (link4.jpg sol taraf!)
	for fi: int in 10:
		var fs: float = 4.0 + float(fi) * 4.5
		var fp: Vector2 = b_a + along * fs + to_bev * (-8.2)
		var fy: float = TerrainHeight.active_height(fp.x, fp.y)
		var fxf: Transform3D = _frame_xform(fp, along, to_bev, fy)
		_add_box_xf(st, fxf, Vector3(4.5, 0.05, 0.05), Vector3(0.0, 0.82, 0.0), COL_ANTHRACITE)
		_add_box_xf(st, fxf, Vector3(4.5, 0.05, 0.05), Vector3(0.0, 0.26, 0.0), COL_ANTHRACITE)
		_add_box_xf(st, fxf, Vector3(0.06, 0.92, 0.06), Vector3(-2.2, 0.46, 0.0), COL_ANTHRACITE)


## 15) YTÜ Davutpaşa Kampüsü Lojmanları (11 blok — Yapı Dergisi Munsell Renk Tasarımı & Mimari Görünüşler):
##     - 3 renk grubu (Tablo 2 & Şekil 8):
##       * Grup 1 (C1, J3, K1, L2): Çakıl Sinterflex (32,5-9/2) + Sarı (25,8-8,1/5,4) dikey sirkülasyon kuleleri
##       * Grup 2 (C2, F, J2, L3):  Beyaz Sinterflex (35-9/1) + Yeşil (35,7-8,1/3,9) dikey sirkülasyon kuleleri
##       * Grup 3 (J1, K2, L1):     Çimento Sinterflex (30-5/2) + Turuncu (13,1-7,5/7,7) dikey sirkülasyon kuleleri
##     - Her blokta OSM'deki birebir 3.8 m merdiven kulesi konumlarında yerden 21.3 m'ye yükselen
##       yüksek doymuşluklu dikey sirkülasyon kuleleri (her katta siyah doğramalı merdiven pencereli) +
##       kuleler arasında Sinterflex kaplı kademeli çatı/teras katı kütleleri + ince teras korkulukları.
func _build_lojmanlar(st: SurfaceTool, col_body: StaticBody3D) -> void:
	# sRGB -> lineer (CampusLandmarks vertex_color_use_as_albedo lineer çalışır; shader source_color ile birebir eşleşir!)
	var palettes: Dictionary = {
		"cakil": {
			"tower": Color(0.80, 0.64, 0.28).srgb_to_linear(),  # Munsell 25,8-8,1/5,4 Sarı
			"stone": Color(0.84, 0.83, 0.76).srgb_to_linear(),  # Munsell 32,5-9/2 Çakıl
		},
		"beyaz": {
			"tower": Color(0.55, 0.65, 0.39).srgb_to_linear(),  # Munsell 35,7-8,1/3,9 Yeşil
			"stone": Color(0.87, 0.88, 0.85).srgb_to_linear(),  # Munsell 35-9/1 Beyaz
		},
		"cimento": {
			"tower": Color(0.81, 0.47, 0.32).srgb_to_linear(),  # Munsell 13,1-7,5/7,7 Turuncu
			"stone": Color(0.57, 0.57, 0.53).srgb_to_linear(),  # Munsell 30-5/2 Çimento
		},
	}
	var col_win: Color = Color(0.10, 0.14, 0.19).srgb_to_linear()
	var col_frame: Color = Color(0.13, 0.14, 0.16).srgb_to_linear()
	var col_rail: Color = Color(0.72, 0.74, 0.76).srgb_to_linear()
	var col_cap: Color = Color(0.24, 0.25, 0.27).srgb_to_linear()

	# 11 blok kesin OSM merkezleri, doğrultuları, yarı boyutları, sirkülasyon cephesi yönü (circ_sign)
	# ve her bloğun kesin 3.8 m merdiven kulesi u merkezleri (Şekil 3-7 & kampus_greybox.json b#20..b#30):
	var blocks: Array = [
		["cimento", Vector2(-277.60, -444.38), Vector2(-0.8541, 0.5202), 28.20, 6.26, 1.0, [-19.9, 3.2, 20.0]],
		["cakil",   Vector2(-222.54, -477.92), Vector2(-0.8541, 0.5201), 26.88, 6.26, 1.0, [-12.35, 8.0, 18.7]],
		["beyaz",   Vector2(-156.28, -518.27), Vector2(-0.8540, 0.5203), 41.31, 6.26, 1.0, [-33.05, -16.6, 0.0, 16.4, 33.1]],
		["beyaz",   Vector2(-238.12, -416.03), Vector2(-0.5745, 0.8185), 28.13, 6.28, 1.0, [-19.9, 3.2, 20.0]],
		["cakil",   Vector2(-201.26, -389.82), Vector2(-0.7399, 0.6728), 28.17, 6.27, 1.0, [-19.9, 3.2, 20.0]],
		["cimento", Vector2(-169.54, -471.25), Vector2(-0.8481, 0.5299), 25.26, 6.26, 1.0, [-17.0, 0.1, 17.1]],
		["beyaz",   Vector2(-141.94, -445.47), Vector2(-0.8054, 0.5927), 26.87, 6.26, 1.0, [-12.3, 8.0, 18.7]],
		["cakil",   Vector2(-115.24, -491.08), Vector2(-0.5257, -0.8506), 25.18, 6.28, 1.0, [-17.0, 0.0, 16.95]],
		["cimento", Vector2(-108.41, -427.07), Vector2(0.7101, -0.7041), 34.65, 6.31, -1.0, [-26.5, -6.3, 10.1, 26.4]],
		["cakil",   Vector2(-91.70, -390.56),  Vector2(0.9077, -0.4197), 34.73, 6.29, -1.0, [-26.5, -6.3, 10.1, 26.5]],
		["beyaz",   Vector2(-64.12, -371.52),  Vector2(0.7209, -0.6931), 34.66, 6.31, -1.0, [-26.5, -6.3, 10.1, 26.4]],
	]

	var main_h: float = 17.5
	var tower_h: float = 21.35  # Ana çatı üstünde +3.85 m yüksek renkli merdiven kulesi (Resim 3 & 4!)
	var pent_h: float = 19.75   # Kademeli çatı/teras katı (+2.25 m)

	for blk: Array in blocks:
		var grp: String = str(blk[0])
		var pal: Dictionary = palettes[grp]
		var col_tower: Color = pal["tower"]
		var col_stone: Color = pal["stone"]
		var ctr: Vector2 = blk[1] as Vector2
		var u: Vector2 = (blk[2] as Vector2).normalized()
		var v: Vector2 = Vector2(-u.y, u.x)
		var hu: float = float(blk[3])
		var hv: float = float(blk[4])
		var cs: float = float(blk[5])  # sirkülasyon cephesi v işareti (+1 veya -1)
		var towers: Array = blk[6] as Array

		# GreyboxBuilder._polygon_avg_height ile birebir eşleşen ortalama taban kotu
		var ref_y: float = 0.0
		var sample_pts: Array[Vector2] = [
			ctr,
			ctr + u * hu + v * hv,
			ctr + u * hu - v * hv,
			ctr - u * hu + v * hv,
			ctr - u * hu - v * hv,
		]
		for sp: Vector2 in sample_pts:
			ref_y += TerrainHeight.active_height(sp.x, sp.y)
		ref_y /= float(sample_pts.size())
		var xf: Transform3D = _frame_xform(ctr, u, v, ref_y)

		# 1) Renkli dikey sirkülasyon / merdiven kuleleri (yerden 21.35 m tepeye kesintisiz renkli kütle!)
		var t_w: float = 3.92
		var t_depth: float = 5.60
		var t_z_outer: float = cs * (hv + 0.40)  # sirkülasyon cephesinden +0.40 m dışa çıkmalı!
		var t_z_center: float = t_z_outer - cs * (t_depth * 0.5)
		var t_base: float = -2.2
		var t_total_h: float = tower_h - t_base

		for tu_var: Variant in towers:
			var tu: float = float(tu_var)
			# Ana renkli merdiven kulesi gövdesi
			_add_box_xf(st, xf, Vector3(t_w, t_total_h, t_depth), Vector3(tu, t_base + t_total_h * 0.5, t_z_center), col_tower)
			# Tepe ince renkli/açık parapet harpuştası (Resim 3 & 4: koyu siyah kapak yok, kule rengiyle uyumlu!)
			_add_box_xf(st, xf, Vector3(t_w + 0.08, 0.10, t_depth + 0.08), Vector3(tu, tower_h + 0.04, t_z_center), col_tower * 0.84)
			# Sirkülasyon yüzünde her katta (zemin + 4 normal + çatı kulesi = 6 seviye) siyah çerçeveli cam merdiven penceresi
			var face_z: float = t_z_outer + cs * 0.03
			for fl: int in 6:
				var wy: float = 1.65 + float(fl) * 3.50
				var wh: float = 2.45 if fl == 0 else (1.90 if fl == 5 else 2.20)
				var ww: float = 2.45 if fl == 0 else 2.15
				_add_box_xf(st, xf, Vector3(ww + 0.22, wh + 0.20, 0.08), Vector3(tu, wy, face_z), col_frame)
				_add_box_xf(st, xf, Vector3(ww, wh, 0.10), Vector3(tu, wy, face_z + cs * 0.015), col_win)
				# İnce 2x2 siyah pencere kayıtı
				_add_box_xf(st, xf, Vector3(0.08, wh, 0.12), Vector3(tu, wy, face_z + cs * 0.02), col_frame)
				_add_box_xf(st, xf, Vector3(ww, 0.08, 0.12), Vector3(tu, wy, face_z + cs * 0.02), col_frame)

		# 2) Kuleler arasında Sinterflex kaplı kademeli çatı / dubleks teras katı kütleleri (17.35 -> 19.75 m — Resim 3 & 4!)
		#    Her blokta merdiven kulelerinin arasındaki açıklıklara ve kısa uçlara kademeli teras kutuları yerleştir.
		var sorted_t: Array[float] = []
		for tu_v: Variant in towers:
			sorted_t.append(float(tu_v))
		sorted_t.sort()
		var spans: Array = []
		# Sol uç -> ilk kule
		spans.append([-hu + 0.15, sorted_t[0] - 2.10])
		# Kuleler arası açıklıklar
		for ti: int in sorted_t.size() - 1:
			spans.append([sorted_t[ti] + 2.10, sorted_t[ti + 1] - 2.10])
		# Son kule -> sağ uç
		spans.append([sorted_t[sorted_t.size() - 1] + 2.10, hu - 0.15])

		var p_depth: float = hv * 1.32  # teras bırakmak için kısmen geri çekilmiş çatı katı
		var p_z: float = -cs * (hv - p_depth * 0.5 - 0.10)  # yaşam/teras cephesine yaslı, sirkülasyon tarafında teraslı
		var p_h: float = pent_h - (main_h - 0.15)
		var p_yc: float = (main_h - 0.15) + p_h * 0.5
		for sp_idx: int in spans.size():
			var sa: float = float(spans[sp_idx][0])
			var sb: float = float(spans[sp_idx][1])
			var slen: float = sb - sa
			if slen < 4.5:
				continue
			# Uçlarda ve geniş orta aralıklarda kademeli Sinterflex çatı dairesi (arada açık teras boşluğu bırak)
			var box_len: float = slen if (sp_idx == 0 or sp_idx == spans.size() - 1) else slen * 0.64
			var box_c: float = (sa + sb) * 0.5
			_add_box_xf(st, xf, Vector3(box_len, p_h, p_depth), Vector3(box_c, p_yc, p_z), col_stone)
			# Açık gri-taş çatı membran harpuştası (Resim 3 & 4'teki gibi doğal açık ton, kara kapak değil!)
			_add_box_xf(st, xf, Vector3(box_len + 0.08, 0.10, p_depth + 0.08), Vector3(box_c, pent_h + 0.04, p_z), col_stone * 0.84)
			# Çatı katı küçük koyu teras pencereleri (her iki uzun yüzde)
			var n_pw: int = clampi(int(box_len / 4.2), 1, 3)
			for wi: int in n_pw:
				var wu: float = box_c - box_len * 0.30 + (box_len * 0.60 * float(wi) / maxf(1.0, float(n_pw - 1))) if n_pw > 1 else box_c
				for side_p: float in [-1.0, 1.0]:
					var pw_z: float = p_z + side_p * (p_depth * 0.5 + 0.04)
					_add_box_xf(st, xf, Vector3(1.55, 1.15, 0.07), Vector3(wu, main_h + 1.15, pw_z), col_win)
		# Çatı parapet teras korkuluk şeridi (her iki uzun kenar boyunca ince gümüş-gri küpeşte — Resim 4!)
		for side_r: float in [-1.0, 1.0]:
			var rz: float = side_r * (hv - 0.18)
			_add_box_xf(st, xf, Vector3(hu * 2.0 - 0.9, 0.06, 0.06), Vector3(0.0, main_h + 0.96, rz), col_rail)
			_add_box_xf(st, xf, Vector3(hu * 2.0 - 0.9, 0.04, 0.04), Vector3(0.0, main_h + 0.52, rz), col_rail)

	# 3) Lojmanlar ana giriş meydanında (L1 / L2 / C2 arası yaya meydanı) YTÜ Lojmanlar yönlendirme totemi
	var tot_wp: Vector2 = Vector2(-124.0, -402.0)
	var tot_out: Vector2 = Vector2(0.55, 0.84).normalized()
	var tot_right: Vector2 = Vector2(tot_out.y, -tot_out.x)
	_build_ytu_totem(st, col_body, tot_wp, tot_right, tot_out, "LojmanlarTotem", "YTÜ DAVUTPAŞA\nLOJMANLARI\n\n• C1-C2 • F Blok\n• J1-J3 • K1-K2\n• L1-L3 Blokları")


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


## Eğimli arazide kenarları havada kalmayan, -0.40 m etekli taş döşeme platformu (+0.10 m yüzey kotu).
static func _add_paver_xf(st: SurfaceTool, xf: Transform3D, w: float, depth: float, z_center: float) -> void:
	_add_box_xf(st, xf, Vector3(w, 0.50, depth), Vector3(0.0, -0.15, z_center), COL_PAVER)


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


## Organik çok-yüzlü (low-poly) ağaç tacı kümesi (pembe çiçekli süs ağaçları için).
static func _add_foliage_blob_xf(st: SurfaceTool, xf: Transform3D, local_pos: Vector3, rx: float, ry: float, color: Color) -> void:
	var segs: int = 7
	var rings: Array = [
		[rx * 0.78, -ry * 0.42, 0.25],
		[rx, 0.05 * ry, 0.0],
		[rx * 0.72, ry * 0.56, 0.35],
	]
	st.set_color(color)
	var bot: Vector3 = xf * (local_pos + Vector3(0.0, -ry, 0.0))
	var top: Vector3 = xf * (local_pos + Vector3(0.0, ry, 0.0))
	var ring_pts: Array = []
	for r_def: Array in rings:
		var rad: float = float(r_def[0])
		var yy: float = float(r_def[1])
		var ph: float = float(r_def[2])
		var pts: Array[Vector3] = []
		for i: int in segs:
			var ang: float = TAU * float(i) / float(segs) + ph
			pts.append(xf * (local_pos + Vector3(cos(ang) * rad, yy, sin(ang) * rad)))
		ring_pts.append(pts)
	for i: int in segs:
		var j: int = (i + 1) % segs
		# Alt koni (dışa bakan sarma yönü)
		st.add_vertex(bot)
		st.add_vertex(ring_pts[0][i])
		st.add_vertex(ring_pts[0][j])
		# Orta şeritler
		for k: int in 2:
			var a: Vector3 = ring_pts[k][i]
			var b: Vector3 = ring_pts[k][j]
			var c: Vector3 = ring_pts[k + 1][j]
			var d: Vector3 = ring_pts[k + 1][i]
			st.add_vertex(a)
			st.add_vertex(d)
			st.add_vertex(c)
			st.add_vertex(a)
			st.add_vertex(c)
			st.add_vertex(b)
		# Üst koni
		st.add_vertex(top)
		st.add_vertex(ring_pts[2][j])
		st.add_vertex(ring_pts[2][i])


## Merkez Kütüphanesi dış taş meydan dörtgeni: üst teras sınırında y_top kotuna kilitlenir, dışa doğru doğal araziye yumuşakça iner.
static func _merkez_plaza_y(lo: Vector2, lu: Vector2, lv: Vector2, y_top: float, uv: Vector2) -> float:
	var wp: Vector2 = lo + lu * uv.x + lv * uv.y
	var ty: float = TerrainHeight.active_height(wp.x, wp.y) + 0.128
	# Üst gezinti terası + merdiven başı sahanlık zarfına ([18.42..62.60] x [18.12..35.60]) 2B Öklid uzaklığı
	var du: float = maxf(0.0, maxf(18.42 - uv.x, uv.x - 62.60))
	var dv: float = maxf(0.0, maxf(18.12 - uv.y, uv.y - 35.60))
	var dist: float = sqrt(du * du + dv * dv)
	var t: float = smoothstep(0.0, 5.5, dist)
	return lerpf(y_top, ty, t)


static func _add_merkez_plaza_quad(st: SurfaceTool, lo: Vector2, lu: Vector2, lv: Vector2, y_top: float, uva: Vector2, uvb: Vector2, uvc: Vector2, uvd: Vector2, color: Color) -> void:
	var a: Vector2 = lo + lu * uva.x + lv * uva.y
	var b: Vector2 = lo + lu * uvb.x + lv * uvb.y
	var c: Vector2 = lo + lu * uvc.x + lv * uvc.y
	var d: Vector2 = lo + lu * uvd.x + lv * uvd.y
	var va: Vector3 = Vector3(a.x, _merkez_plaza_y(lo, lu, lv, y_top, uva), a.y)
	var vb: Vector3 = Vector3(b.x, _merkez_plaza_y(lo, lu, lv, y_top, uvb), b.y)
	var vc: Vector3 = Vector3(c.x, _merkez_plaza_y(lo, lu, lv, y_top, uvc), c.y)
	var vd: Vector3 = Vector3(d.x, _merkez_plaza_y(lo, lu, lv, y_top, uvd), d.y)
	st.set_color(color)
	var n1: Vector3 = (vc - va).cross(vb - va)
	if n1.y >= 0.0:
		st.add_vertex(va)
		st.add_vertex(vb)
		st.add_vertex(vc)
		st.add_vertex(va)
		st.add_vertex(vc)
		st.add_vertex(vd)
	else:
		st.add_vertex(va)
		st.add_vertex(vc)
		st.add_vertex(vb)
		st.add_vertex(va)
		st.add_vertex(vd)
		st.add_vertex(vc)


## Arazi eğimine birebir yapışan yukarı bakan tek renkli taş/drenaj dörtgeni (çim sızmasız meydan kaplaması).
static func _add_terrain_quad(st: SurfaceTool, a: Vector2, b: Vector2, c: Vector2, d: Vector2, y_off: float, color: Color) -> void:
	var va: Vector3 = Vector3(a.x, TerrainHeight.active_height(a.x, a.y) + y_off, a.y)
	var vb: Vector3 = Vector3(b.x, TerrainHeight.active_height(b.x, b.y) + y_off, b.y)
	var vc: Vector3 = Vector3(c.x, TerrainHeight.active_height(c.x, c.y) + y_off, c.y)
	var vd: Vector3 = Vector3(d.x, TerrainHeight.active_height(d.x, d.y) + y_off, d.y)
	st.set_color(color)
	# Godot sağ-el +Y yukarı normal sarma yönü ((v2 - v0) x (v1 - v0)).y > 0
	var n1: Vector3 = (vc - va).cross(vb - va)
	if n1.y >= 0.0:
		st.add_vertex(va)
		st.add_vertex(vb)
		st.add_vertex(vc)
		st.add_vertex(va)
		st.add_vertex(vc)
		st.add_vertex(vd)
	else:
		st.add_vertex(va)
		st.add_vertex(vc)
		st.add_vertex(vb)
		st.add_vertex(va)
		st.add_vertex(vd)
		st.add_vertex(vc)
