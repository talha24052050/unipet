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


## 3) Yeni Merkez Kütüphanesi (b#139): modern cam cephe girişi, koyu kanopi ve çalışma bankları.
func _build_merkez_library(st: SurfaceTool, col_body: StaticBody3D) -> void:
	var mid: Vector2 = Vector2(-84.3, -157.8)
	var out: Vector2 = Vector2(-0.59, 0.81).normalized()
	var right_dir: Vector2 = Vector2(out.y, -out.x)
	var base_y: float = TerrainHeight.active_height(mid.x, mid.y)
	var xf: Transform3D = _frame_xform(mid, right_dir, out, base_y)

	_add_paver_xf(st, xf, 16.0, 8.0, 4.1)
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


## 15) Büyük Ev Kafe Terası (b#43): vitrin önü ahşap teras platformu, çiçeklikler ve yeşil şemsiyeli açık hava masaları.
func _build_buyuk_ev_terrace(st: SurfaceTool, col_body: StaticBody3D) -> void:
	var mid: Vector2 = Vector2(-8.8, -69.3)
	var out: Vector2 = Vector2(0.78, 0.63).normalized()
	var right_dir: Vector2 = Vector2(out.y, -out.x)
	var base_y: float = TerrainHeight.active_height(mid.x, mid.y)
	var xf: Transform3D = _frame_xform(mid, right_dir, out, base_y)

	# Ahşap güneşlenme/oturma terası platformu (eğimli arazide havada kalmasın diye -0.31m etekli)
	_add_box_xf(st, xf, Vector3(16.0, 0.45, 5.5), Vector3(0.0, -0.085, 2.85), COL_WOOD)
	for sx: float in [-7.85, 7.85]:
		_add_box_xf(st, xf, Vector3(0.45, 0.42, 5.5), Vector3(sx, 0.35, 2.85), COL_STONE_DARK)
		_add_box_xf(st, xf, Vector3(0.35, 0.35, 5.1), Vector3(sx, 0.62, 2.85), COL_PLANT_GREEN)
	for i: int in 4:
		var tx: float = -5.4 + float(i) * 3.6
		var tz: float = 2.85
		_add_box_xf(st, xf, Vector3(1.35, 0.08, 0.90), Vector3(tx, 0.88, tz), COL_WOOD)
		_add_box_xf(st, xf, Vector3(0.14, 0.74, 0.14), Vector3(tx, 0.51, tz), COL_ANTHRACITE)
		for sz: float in [-0.70, 0.70]:
			_add_box_xf(st, xf, Vector3(1.25, 0.07, 0.32), Vector3(tx, 0.56, tz + sz), COL_WOOD)
		_add_box_xf(st, xf, Vector3(0.08, 2.55, 0.08), Vector3(tx, 1.41, tz), COL_ANTHRACITE)
		_add_box_xf(st, xf, Vector3(2.35, 0.20, 2.35), Vector3(tx, 2.66, tz), COL_CANOPY_GREEN)
		_add_box_xf(st, xf, Vector3(1.25, 0.16, 1.25), Vector3(tx, 2.82, tz), COL_CANOPY_GREEN)
		var ccol: CollisionShape3D = CollisionShape3D.new()
		var csh: BoxShape3D = BoxShape3D.new()
		csh.size = Vector3(1.4, 1.2, 1.6)
		ccol.shape = csh
		ccol.transform = xf * Transform3D(Basis.IDENTITY, Vector3(tx, 0.65, tz))
		col_body.add_child(ccol)


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
