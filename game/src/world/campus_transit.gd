extends Node3D
## YTÜ Davutpaşa Kampüsü Ulaşım Sistemi (Mavi YTÜ Ring + Sembolik İETT 41AT + 11 Durak + Biniş Tanıtım Turu):
## - Oyun A Kapısı Başlangıç Durağı'nda başlar; anlık ışınlanma yerine kampüs içi ulaşım Ring ve 41AT ile sağlanır.
## - 11 gerçek durakta cam durak kabinleri ve çift logolu (YTÜ RİNG | 41AT İETT) durak totemleri yer alır.
## - 3 adet Mavi YTÜ Ring otobüsü ve sembolik sarı-siyah İETT 41AT (AYAZAĞA - DAVUTPAŞA Y.T.Ü.) otobüsü
##   4.1 km'lik asfalt kampüs ring hattında kesintisiz dolaşır ve duraklarda yolcu indirip bindirir.
## - Oyuncu ilk kez A Kapısı'ndan Ring'e bindiğinde 4 kartlık interaktif "UniPet Kampüs Tanıtım Turu" açılır.

signal boarded_bus(bus_id: String, is_41at: bool)
signal alighted_bus(stop_id: String, stop_name: String)

const LocalProfile := preload("res://src/core/local_profile.gd")
const TRANSIT_JSON_PATH: String = "res://data/transit_routes.json"

const CRUISE_SPEED_MPS: float = 12.4
const STOP_DWELL_SEC: float = 6.0
const INITIAL_A_GATE_DWELL_SEC: float = 14.0
const BOARD_RADIUS_M: float = 15.5
const STOP_APPROACH_SLOW_M: float = 18.0

@export var player: Node3D
@export var ui: CanvasLayer

var stops: Array = []          # [{"id","name","desc","road_pos":Vector2,"shelter_pos":Vector2,"shelter_yaw":float,"s":float}]
var waypoints: PackedVector2Array = PackedVector2Array()
var cum_lengths: PackedFloat32Array = PackedFloat32Array()
var loop_length: float = 0.0

## Otobüs durumları: [{"id","label","is_41at","node":Node3D,"s":float,"dwell":float,"last_stop_idx":int,"pos":Vector2,"yaw":float}]
var _buses: Array[Dictionary] = []

var riding_bus_idx: int = -1
var target_stop_idx: int = -1
var _saved_collision_disabled: bool = false

var _hud_layer: CanvasLayer
var _board_btn: Button
var _ride_panel: PanelContainer
var _ride_status_lbl: Label
var _stop_select: OptionButton
var _alight_now_btn: Button
var _tour_btn: Button

var _onboarding_card: PanelContainer
var _onboarding_title: Label
var _onboarding_body: Label
var _onboarding_prev_btn: Button
var _onboarding_next_btn: Button
var _onboarding_quick_row: HBoxContainer
var _onboarding_step: int = 0

const ONBOARDING_STEPS: Array[Dictionary] = [
	{
		"title": "1/4 • YTÜ Davutpaşa Kampüsü'ne Hoş Geldin! 🐾",
		"body": "A Kapısı'ndan kampüse adım attın! UniPet'te artık ışınlanma yok; kampüsün tüm fakülte, kafe ve meydanlarına Mavi YTÜ Ring otobüsleri veya kampüsün efsanesi 41AT ile seyahat edebilirsin.",
	},
	{
		"title": "2/4 • Tarihi Hamam & ARTLAB Yapay Zeka Zirvesi 🤖",
		"body": "2 gün sonra Tarihi Hamam Kültür Merkezi'nde YTÜ SKY LAB'in ARTLAB Yapay Zeka Zirvesi başlıyor! Merdivenlerden 2 metre aşağıdaki çökük avluya inip dev zirve afişini ve kapının solundaki Espressolab (ESLAB) kahve minibüsünü ziyaret edebilirsin.",
	},
	{
		"title": "3/4 • Kafe Salonları & Kampüs Kimliği ☕",
		"body": "Hokka, Kayıntı, Büyük Ev, Yemekhane ve Yıldız Cafe kapılarından içeri girdiğinde o kafenin canlı sohbet odası otomatik açılır! Oyunculara dokunarak ✓ Doğrulanmış YTÜ Öğrencisi veya 🎯 YKS Adayı profillerini görebilir, arkadaş ekleyebilirsin.",
	},
	{
		"title": "4/4 • Pet Bakımı, Yıldız Tozu & İneceğin Durak ⭐",
		"body": "Kampüste yürüyerek 47 noktayı keşfet, yıldız tozlarını topla ve petini mutlu tut! Aşağıdan inmek istediğin durağı hemen seçebilirsin — otobüs o durağa vardığında seni otomatik olarak kaldırıma indirecek!",
	},
]


func _ready() -> void:
	if player == null and has_node("../Player"):
		player = get_node("../Player") as Node3D
	if ui == null and has_node("../UI"):
		ui = get_node("../UI") as CanvasLayer
	build()


func build() -> void:
	if not stops.is_empty():
		return
	_load_route_data()
	if waypoints.size() < 3 or stops.is_empty():
		return
	_build_stop_shelters()
	_spawn_fleet()
	_build_transit_hud()
	_update_buses_transforms(0.0)


func _load_route_data() -> void:
	if not FileAccess.file_exists(TRANSIT_JSON_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TRANSIT_JSON_PATH))
	if not (parsed is Dictionary):
		return
	var d: Dictionary = parsed
	var raw_wps: Array = d.get("waypoints", [])
	waypoints.resize(raw_wps.size())
	for i: int in raw_wps.size():
		waypoints[i] = Vector2(float(raw_wps[i][0]), float(raw_wps[i][1]))
	var m: int = waypoints.size()
	if m < 3:
		return
	cum_lengths.resize(m + 1)
	cum_lengths[0] = 0.0
	for i: int in m:
		var a: Vector2 = waypoints[i]
		var b: Vector2 = waypoints[(i + 1) % m]
		cum_lengths[i + 1] = cum_lengths[i] + a.distance_to(b)
	loop_length = cum_lengths[m]

	stops.clear()
	for st_raw: Dictionary in d.get("stops", []):
		var wi: int = clampi(int(st_raw.get("waypoint_index", 0)), 0, m - 1)
		var rp: Array = st_raw.get("road_pos", [0.0, 0.0])
		var sp: Array = st_raw.get("shelter_pos", rp)
		stops.append({
			"id": str(st_raw.get("id", "")),
			"name": str(st_raw.get("name", "Durak")),
			"desc": str(st_raw.get("desc", "")),
			"road_pos": Vector2(float(rp[0]), float(rp[1])),
			"shelter_pos": Vector2(float(sp[0]), float(sp[1])),
			"shelter_yaw": float(st_raw.get("shelter_yaw", 0.0)),
			"waypoint_index": wi,
			"s": cum_lengths[wi],
		})


## 1) 11 Kampüs Durağı: Koyu antrasit-cam modern durak kabini + Çift logolu (YTÜ RİNG & 41AT) sarı-mavi durak totemi!
func _build_stop_shelters() -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)

	var col_body: StaticBody3D = StaticBody3D.new()
	col_body.name = "BusStopCollisions"
	add_child(col_body)

	var c_pad: Color = Color(0.58, 0.60, 0.62).srgb_to_linear()
	var c_frame: Color = Color(0.14, 0.16, 0.20).srgb_to_linear()
	var c_roof: Color = Color(0.22, 0.26, 0.32).srgb_to_linear()
	var c_glass: Color = Color(0.22, 0.36, 0.48).srgb_to_linear()
	var c_bench: Color = Color(0.54, 0.36, 0.20).srgb_to_linear()
	var c_ring_blue: Color = Color(0.06, 0.38, 0.84).srgb_to_linear()
	var c_iett_yellow: Color = Color(0.95, 0.72, 0.08).srgb_to_linear()
	var c_white: Color = Color(0.95, 0.96, 0.98).srgb_to_linear()

	for idx: int in stops.size():
		var stop: Dictionary = stops[idx]
		var sp: Vector2 = stop["shelter_pos"]
		var by: float = TerrainHeight.active_height(sp.x, sp.y)
		var yaw: float = float(stop["shelter_yaw"])
		var sxf: Transform3D = Transform3D(Basis(Vector3.UP, yaw), Vector3(sp.x, by, sp.y))

		# Kaldırım platformu + arka/yan direkler + cam paneller + saçak + ahşap oturma bankı
		_box(st, sxf, Vector3(4.20, 0.14, 1.85), Vector3(0.0, 0.07, 0.0), c_pad)
		for px: float in [-1.85, 0.0, 1.85]:
			_box(st, sxf, Vector3(0.09, 2.45, 0.09), Vector3(px, 1.28, -0.72), c_frame)
		for px2: float in [-1.85, 1.85]:
			_box(st, sxf, Vector3(0.08, 2.45, 0.08), Vector3(px2, 1.28, 0.62), c_frame)
		# Arka ve yan temperli camlar
		_box(st, sxf, Vector3(3.62, 1.92, 0.04), Vector3(0.0, 1.24, -0.72), c_glass)
		_box(st, sxf, Vector3(0.04, 1.92, 1.28), Vector3(-1.85, 1.24, -0.05), c_glass)
		# Üst saçak + mavi YTÜ Ring alın şeridi
		_box(st, sxf, Vector3(4.36, 0.12, 1.96), Vector3(0.0, 2.54, -0.02), c_roof)
		_box(st, sxf, Vector3(4.38, 0.09, 0.06), Vector3(0.0, 2.55, 0.95), c_ring_blue)
		# Ahşap yolcu bankı
		_box(st, sxf, Vector3(2.80, 0.07, 0.42), Vector3(0.0, 0.52, -0.42), c_bench)
		_box(st, sxf, Vector3(0.08, 0.45, 0.36), Vector3(-1.10, 0.28, -0.42), c_frame)
		_box(st, sxf, Vector3(0.08, 0.45, 0.36), Vector3(1.10, 0.28, -0.42), c_frame)

		# Sağ yanda ikonik Sarı-Mavi İETT 41AT & YTÜ RİNG Durak Totemi
		_cyl(st, sxf, 0.055, 2.95, Vector3(2.55, 1.48, 0.48), 8, c_frame)
		_box(st, sxf, Vector3(0.76, 0.52, 0.10), Vector3(2.55, 2.68, 0.48), c_ring_blue)
		_box(st, sxf, Vector3(0.76, 0.34, 0.11), Vector3(2.55, 2.24, 0.48), c_iett_yellow)
		_box(st, sxf, Vector3(0.70, 0.04, 0.12), Vector3(2.55, 2.44, 0.48), c_white)

		# Durak çarpıştırıcısı (arka duvar)
		var cs: CollisionShape3D = CollisionShape3D.new()
		var bs: BoxShape3D = BoxShape3D.new()
		bs.size = Vector3(3.90, 2.50, 0.35)
		cs.shape = bs
		cs.transform = sxf * Transform3D(Basis.IDENTITY, Vector3(0.0, 1.25, -0.70))
		col_body.add_child(cs)

		# Durak 3B tabelası
		var lbl: Label3D = Label3D.new()
		lbl.name = "StopSign_%s" % str(stop["id"])
		lbl.text = "🚏 %d. %s\n🚌 Mavi Ring  •  41AT İETT" % [idx + 1, str(stop["name"])]
		lbl.font_size = 28
		lbl.pixel_size = 0.0052
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.modulate = Color(0.98, 0.99, 1.0)
		lbl.outline_size = 8
		lbl.outline_modulate = Color(0.05, 0.12, 0.28, 0.96)
		lbl.visibility_range_end = 95.0
		lbl.position = Vector3(sp.x, by + 3.45, sp.y)
		add_child(lbl)

	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.68
	mesh.surface_set_material(0, mat)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "CampusBusStopsMesh"
	mi.mesh = mesh
	add_child(mi)


## 2) 3 Mavi YTÜ Ring + 1 Sembolik İETT 41AT Otobüsü Filosu
func _spawn_fleet() -> void:
	var ring_mesh: ArrayMesh = _create_blue_ring_mesh()
	var bus_41at_mesh: ArrayMesh = _create_41at_iett_mesh()

	var fleet_specs: Array[Dictionary] = [
		{"id": "ring_1", "label": "Mavi YTÜ Ring #1", "is_41at": false, "s": float(stops[0]["s"]), "dwell": INITIAL_A_GATE_DWELL_SEC, "stop": 0},
		{"id": "iett_41at", "label": "İETT 41AT (Ayazağa - Davutpaşa Y.T.Ü.)", "is_41at": true, "s": fposmod(float(stops[0]["s"]) - 42.0, loop_length), "dwell": 0.0, "stop": -1},
		{"id": "ring_2", "label": "Mavi YTÜ Ring #2", "is_41at": false, "s": fposmod(loop_length * 0.35, loop_length), "dwell": 0.0, "stop": -1},
		{"id": "ring_3", "label": "Mavi YTÜ Ring #3", "is_41at": false, "s": fposmod(loop_length * 0.70, loop_length), "dwell": 0.0, "stop": -1},
	]

	for spec: Dictionary in fleet_specs:
		var is_41at: bool = bool(spec["is_41at"])
		var bus_root: Node3D = Node3D.new()
		bus_root.name = str(spec["id"]).to_pascal_case()
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "BusBodyMesh"
		mi.mesh = bus_41at_mesh if is_41at else ring_mesh
		bus_root.add_child(mi)

		if is_41at:
			_attach_41at_led_signs(bus_root)
		else:
			_attach_ring_led_signs(bus_root)

		add_child(bus_root)
		_buses.append({
			"id": str(spec["id"]),
			"label": str(spec["label"]),
			"is_41at": is_41at,
			"node": bus_root,
			"s": float(spec["s"]),
			"dwell": float(spec["dwell"]),
			"last_stop_idx": int(spec["stop"]),
			"pos": Vector2.ZERO,
			"yaw": 0.0,
		})


## Mavi YTÜ Ring Otobüsü 3B Modeli (10.4 m uzunluk, metalik YTÜ mavisi + beyaz tavan/kuşak, panoramik camlar)
func _create_blue_ring_mesh() -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var id_xf: Transform3D = Transform3D.IDENTITY

	var c_blue: Color = Color(0.07, 0.42, 0.86).srgb_to_linear()
	var c_blue_dk: Color = Color(0.04, 0.26, 0.62).srgb_to_linear()
	var c_white: Color = Color(0.95, 0.97, 0.99).srgb_to_linear()
	var c_glass: Color = Color(0.09, 0.15, 0.22).srgb_to_linear()
	var c_black: Color = Color(0.10, 0.11, 0.13).srgb_to_linear()
	var c_rim: Color = Color(0.78, 0.81, 0.85).srgb_to_linear()
	var c_headlight: Color = Color(0.98, 0.98, 0.92).srgb_to_linear()
	var c_taillight: Color = Color(0.88, 0.14, 0.12).srgb_to_linear()
	var c_led_bg: Color = Color(0.05, 0.08, 0.14).srgb_to_linear()

	# Alt şasi + mavi alt gövde + beyaz kuşak + koyu panoramik cam bandı + beyaz tavan + klima ünitesi
	_box(st, id_xf, Vector3(2.46, 0.28, 10.10), Vector3(0.0, 0.46, 0.0), c_black)
	_box(st, id_xf, Vector3(2.52, 1.12, 10.20), Vector3(0.0, 1.08, 0.0), c_blue)
	_box(st, id_xf, Vector3(2.55, 0.18, 10.24), Vector3(0.0, 1.66, 0.0), c_white)
	_box(st, id_xf, Vector3(2.50, 1.10, 9.96), Vector3(0.0, 2.26, 0.0), c_glass)
	# Pencere dikmeleri (mavi)
	for pz: float in [-4.92, -3.20, -1.50, 0.20, 1.90, 3.60, 4.92]:
		_box(st, id_xf, Vector3(2.53, 1.12, 0.18), Vector3(0.0, 2.26, pz), c_blue_dk)
	# Üst alın ve beyaz tavan + tavan kliması
	_box(st, id_xf, Vector3(2.52, 0.34, 10.16), Vector3(0.0, 2.96, 0.0), c_blue)
	_box(st, id_xf, Vector3(2.38, 0.14, 9.80), Vector3(0.0, 3.18, 0.0), c_white)
	_box(st, id_xf, Vector3(1.56, 0.24, 3.20), Vector3(0.0, 3.34, -0.40), c_white)

	# Ön LED tabela yuvası + ön farlar + tampon + arka stoplar + yan aynalar
	_box(st, id_xf, Vector3(1.92, 0.30, 0.08), Vector3(0.0, 2.94, 5.10), c_led_bg)
	_box(st, id_xf, Vector3(2.54, 0.32, 0.20), Vector3(0.0, 0.54, 5.08), c_blue_dk)
	_box(st, id_xf, Vector3(2.54, 0.32, 0.20), Vector3(0.0, 0.54, -5.08), c_blue_dk)
	for sgn: float in [-1.0, 1.0]:
		_box(st, id_xf, Vector3(0.42, 0.20, 0.08), Vector3(sgn * 0.92, 0.86, 5.11), c_headlight)
		_box(st, id_xf, Vector3(0.32, 0.44, 0.08), Vector3(sgn * 0.98, 1.04, -5.11), c_taillight)
		_box(st, id_xf, Vector3(0.18, 0.38, 0.14), Vector3(sgn * 1.36, 2.28, 4.86), c_black)

	# Sağ yolcu biniş çift kapıları (-X = sağ kaldırım tarafı! İleri = +Z, Yukarı = +Y -> Sağ = -X!)
	for dz: float in [3.55, -0.65]:
		_box(st, id_xf, Vector3(0.06, 2.18, 1.22), Vector3(-1.25, 1.56, dz), c_black)
		_box(st, id_xf, Vector3(0.08, 1.96, 0.54), Vector3(-1.26, 1.60, dz - 0.28), c_glass)
		_box(st, id_xf, Vector3(0.08, 1.96, 0.54), Vector3(-1.26, 1.60, dz + 0.28), c_glass)

	# 4 Tekerlek
	for wz: float in [-3.15, 3.15]:
		for wsgn: float in [-1.0, 1.0]:
			_cyl_x(st, id_xf, 0.48, 0.30, Vector3(wsgn * 1.18, 0.48, wz), 16, c_black)
			_cyl_x(st, id_xf, 0.28, 0.32, Vector3(wsgn * 1.19, 0.48, wz), 12, c_rim)

	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.46
	mat.metallic = 0.15
	mesh.surface_set_material(0, mat)
	return mesh


## Sembolik İETT 41AT Otobüsü 3B Modeli (12.0 m uzunluk — İkonik İETT Sarısı, Parlak Siyah Ön Maske & Cam Kuşağı,
## Turuncu LED Hat Tabelası Yuvaları, Erguvan-Kırmızı İETT Şeridi, Çift Arka Dingil, Ön Cam Hat Levhası!)
func _create_41at_iett_mesh() -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var id_xf: Transform3D = Transform3D.IDENTITY

	var c_iett_yellow: Color = Color(0.95, 0.71, 0.07).srgb_to_linear()
	var c_iett_gold_dk: Color = Color(0.78, 0.54, 0.04).srgb_to_linear()
	var c_piano_black: Color = Color(0.07, 0.08, 0.10).srgb_to_linear()
	var c_erguvan: Color = Color(0.64, 0.10, 0.28).srgb_to_linear()
	var c_iett_red: Color = Color(0.82, 0.12, 0.14).srgb_to_linear()
	var c_white: Color = Color(0.96, 0.97, 0.98).srgb_to_linear()
	var c_glass: Color = Color(0.09, 0.13, 0.17).srgb_to_linear()
	var c_tire: Color = Color(0.09, 0.10, 0.11).srgb_to_linear()
	var c_rim: Color = Color(0.76, 0.79, 0.83).srgb_to_linear()
	var c_amber_glow: Color = Color(1.0, 0.60, 0.06).srgb_to_linear()
	var c_headlight: Color = Color(0.99, 0.96, 0.86).srgb_to_linear()
	var c_taillight: Color = Color(0.90, 0.12, 0.10).srgb_to_linear()

	# 12.0 m Tam Boy İETT Şehir Otobüsü Gövdesi
	_box(st, id_xf, Vector3(2.50, 0.28, 11.90), Vector3(0.0, 0.46, 0.0), c_piano_black)
	# İkonik İETT Sarı alt gövde (y=0.56..1.74) + ince Erguvan/İETT kırmızı belediye kuşağı!
	_box(st, id_xf, Vector3(2.55, 1.18, 12.00), Vector3(0.0, 1.15, 0.0), c_iett_yellow)
	_box(st, id_xf, Vector3(2.57, 0.09, 12.02), Vector3(0.0, 0.74, 0.0), c_erguvan)
	_box(st, id_xf, Vector3(2.57, 0.06, 12.02), Vector3(0.0, 1.70, 0.0), c_piano_black)

	# İETT otobüslerinin imzası olan parlak siyah pencere kuşağı ve siyah ön cam maskesi (y=1.74..2.88)
	_box(st, id_xf, Vector3(2.53, 1.14, 11.96), Vector3(0.0, 2.31, 0.0), c_piano_black)
	_box(st, id_xf, Vector3(2.55, 1.00, 11.40), Vector3(0.0, 2.30, 0.0), c_glass)
	for pz: float in [-5.85, -4.10, -2.35, -0.60, 1.15, 2.90, 4.55, 5.85]:
		_box(st, id_xf, Vector3(2.56, 1.12, 0.18), Vector3(0.0, 2.31, pz), c_piano_black)

	# Sarı üst tavan kemeri + beyaz büyük İETT tavan klima ünitesi
	_box(st, id_xf, Vector3(2.54, 0.34, 11.96), Vector3(0.0, 3.02, 0.0), c_iett_yellow)
	_box(st, id_xf, Vector3(2.40, 0.12, 11.60), Vector3(0.0, 3.23, 0.0), c_white)
	_box(st, id_xf, Vector3(1.74, 0.28, 4.20), Vector3(0.0, 3.38, -0.30), c_white)

	# ÖN CEPHE DETAYLARI (+Z = +6.00 m):
	# Siyah ön maske + Üst Turuncu Kayan LED Tabela kutusu + Ön cam sağ alt klasik beyaz-kırmızı "41AT" güzergah levhası!
	_box(st, id_xf, Vector3(2.44, 1.54, 0.08), Vector3(0.0, 2.42, 5.99), c_piano_black)
	_box(st, id_xf, Vector3(2.24, 1.02, 0.09), Vector3(0.0, 2.24, 6.00), c_glass)
	# Ön turuncu LED matris çerçevesi
	_box(st, id_xf, Vector3(2.16, 0.36, 0.10), Vector3(0.0, 2.98, 6.01), c_piano_black)
	# Ön cam sağ alt köşedeki nostaljik/sembolik beyaz-kırmızı 41AT hat tabelası!
	_box(st, id_xf, Vector3(0.58, 0.20, 0.11), Vector3(-0.74, 1.84, 6.01), c_white)
	_box(st, id_xf, Vector3(0.18, 0.20, 0.115), Vector3(-0.94, 1.84, 6.012), c_iett_red)
	# Ön siyah ızgara + gümüş arma + çift yuvarlak mercek farlar + sis farları + resmi plaka (34 TP 4100)
	_box(st, id_xf, Vector3(1.52, 0.42, 0.08), Vector3(0.0, 1.02, 6.01), c_piano_black)
	_cyl_z(st, id_xf, 0.13, 0.10, Vector3(0.0, 1.04, 6.02), 12, c_rim)
	_box(st, id_xf, Vector3(2.56, 0.34, 0.22), Vector3(0.0, 0.54, 5.96), c_iett_gold_dk)
	_box(st, id_xf, Vector3(0.56, 0.13, 0.06), Vector3(0.0, 0.54, 6.08), c_white)
	for sgn: float in [-1.0, 1.0]:
		_box(st, id_xf, Vector3(0.46, 0.22, 0.08), Vector3(sgn * 0.96, 0.96, 6.01), c_piano_black)
		_cyl_z(st, id_xf, 0.085, 0.10, Vector3(sgn * 1.04, 0.96, 6.02), 10, c_headlight)
		_cyl_z(st, id_xf, 0.075, 0.10, Vector3(sgn * 0.86, 0.96, 6.02), 10, c_amber_glow)
		# İETT karakteristik kıvrık sarı-siyah boynuz dikiz aynaları!
		_box(st, id_xf, Vector3(0.28, 0.07, 0.07), Vector3(sgn * 1.34, 2.66, 5.82), c_iett_yellow)
		_box(st, id_xf, Vector3(0.16, 0.44, 0.12), Vector3(sgn * 1.44, 2.42, 5.86), c_piano_black)

	# SAĞ BİNİŞ YANI (-X = sağ kaldırım yönü): 3 adet çift kanatlı kapı (ön, orta, arka) + yan turuncu LED kutusu!
	_box(st, id_xf, Vector3(0.08, 0.28, 1.65), Vector3(-1.27, 2.86, 3.65), c_piano_black)
	for dz: float in [4.75, 0.25, -4.45]:
		_box(st, id_xf, Vector3(0.06, 2.24, 1.24), Vector3(-1.26, 1.58, dz), c_piano_black)
		_box(st, id_xf, Vector3(0.08, 1.98, 0.54), Vector3(-1.27, 1.62, dz - 0.29), c_glass)
		_box(st, id_xf, Vector3(0.08, 1.98, 0.54), Vector3(-1.27, 1.62, dz + 0.29), c_glass)

	# ARKA CEPHE (-Z = -6.00 m): Arka turuncu "41AT" LED kutusu + dikey üçlü stop grubu + motor ızgarası
	_box(st, id_xf, Vector3(1.10, 0.30, 0.09), Vector3(0.0, 2.94, -6.01), c_piano_black)
	_box(st, id_xf, Vector3(1.66, 0.64, 0.08), Vector3(0.0, 0.98, -6.01), c_piano_black)
	for sgn2: float in [-1.0, 1.0]:
		_box(st, id_xf, Vector3(0.24, 0.68, 0.09), Vector3(sgn2 * 1.06, 1.18, -6.01), c_taillight)
		_box(st, id_xf, Vector3(0.22, 0.20, 0.10), Vector3(sgn2 * 1.06, 1.36, -6.015), c_amber_glow)

	# Tekerlekler (ön aks + çift arka aks / körüklü-uzun İETT duruşu)
	for wz: float in [3.65, -2.85, -4.15]:
		for wsgn: float in [-1.0, 1.0]:
			_cyl_x(st, id_xf, 0.50, 0.30, Vector3(wsgn * 1.20, 0.50, wz), 16, c_tire)
			_cyl_x(st, id_xf, 0.30, 0.32, Vector3(wsgn * 1.21, 0.50, wz), 12, c_rim)

	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.40
	mat.metallic = 0.18
	mesh.surface_set_material(0, mat)
	return mesh


func _attach_ring_led_signs(bus_root: Node3D) -> void:
	_add_bus_label(bus_root, Vector3(0.0, 2.94, 5.16), 0.0, "FrontSign", "YTÜ RİNG • KAMPÜS İÇİ", 30, 0.0046, Color(0.55, 0.94, 1.0))
	_add_bus_label(bus_root, Vector3(-1.30, 1.66, 1.45), -PI * 0.5, "RightBodySign", "★ YILDIZ TEKNİK ÜNİVERSİTESİ • ÜCRETSİZ ÖĞRENCİ RİNGİ", 24, 0.0040, Color(0.06, 0.20, 0.52))
	_add_bus_label(bus_root, Vector3(1.30, 1.66, 1.45), PI * 0.5, "LeftBodySign", "★ YILDIZ TEKNİK ÜNİVERSİTESİ • DAVUTPAŞA RİNG", 24, 0.0040, Color(0.06, 0.20, 0.52))


func _attach_41at_led_signs(bus_root: Node3D) -> void:
	# Parlak kehribar-turuncu İETT LED hat yazıları (ön, sağ biniş yanı, arka + gövde İETT yazısı)
	var led_amber: Color = Color(1.0, 0.66, 0.10)
	_add_bus_label(bus_root, Vector3(0.0, 2.98, 6.08), 0.0, "FrontLed41AT", "41AT  AYAZAĞA - DAVUTPAŞA Y.T.Ü.", 30, 0.0042, led_amber)
	_add_bus_label(bus_root, Vector3(-0.74, 1.84, 6.08), 0.0, "WindshieldCard41AT", "41AT DAVUTPAŞA Y.T.Ü.", 18, 0.0024, Color(0.10, 0.10, 0.12))
	_add_bus_label(bus_root, Vector3(-1.32, 2.86, 3.65), -PI * 0.5, "SideLed41AT", "41AT DAVUTPAŞA Y.T.Ü.", 24, 0.0038, led_amber)
	_add_bus_label(bus_root, Vector3(0.0, 2.94, -6.08), PI, "RearLed41AT", "41AT", 32, 0.0048, led_amber)
	_add_bus_label(bus_root, Vector3(-1.30, 1.24, 2.45), -PI * 0.5, "IettRightCrest", "İETT  •  41AT EFSANESİ  •  İSTANBUL", 26, 0.0044, Color(0.12, 0.10, 0.08))
	_add_bus_label(bus_root, Vector3(1.30, 1.24, 0.0), PI * 0.5, "IettLeftCrest", "İETT  •  41AT AYAZAĞA - DAVUTPAŞA Y.T.Ü.", 26, 0.0044, Color(0.12, 0.10, 0.08))


static func _add_bus_label(parent: Node3D, pos: Vector3, ry: float, nm: String, txt: String, fsize: int, px: float, col: Color) -> void:
	var lbl: Label3D = Label3D.new()
	lbl.name = nm
	lbl.text = txt
	lbl.font_size = fsize
	lbl.pixel_size = px
	lbl.modulate = col
	lbl.outline_size = 6
	lbl.outline_modulate = Color(0.04, 0.05, 0.08, 0.92)
	lbl.visibility_range_end = 130.0
	lbl.position = pos
	lbl.rotation = Vector3(0.0, ry, 0.0)
	parent.add_child(lbl)


## 3) Biniş Butonu, Yolculuk Durak Seçici Barı ve 4 Kartlık İlk Biniş Tanıtım Turu (Onboarding)
func _build_transit_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.name = "TransitHudLayer"
	_hud_layer.layer = 15
	add_child(_hud_layer)

	# Yaya iken otobüs yaklaşınca çıkan "🚌 Ring'e Bin / 41AT'ye Bin" butonu
	_board_btn = Button.new()
	_board_btn.name = "BoardBusButton"
	_board_btn.visible = false
	_board_btn.anchor_left = 0.5
	_board_btn.anchor_top = 1.0
	_board_btn.anchor_right = 0.5
	_board_btn.anchor_bottom = 1.0
	_board_btn.offset_left = -195.0
	_board_btn.offset_right = 195.0
	_board_btn.offset_top = -156.0
	_board_btn.offset_bottom = -88.0
	_board_btn.add_theme_font_size_override("font_size", 22)
	_board_btn.pressed.connect(func() -> void: board_nearest_bus())
	_hud_layer.add_child(_board_btn)

	# Otobüse binildiğinde altta görünen Durak Seçici & İniş Paneli (sağ alttaki Sohbet butonuna değmez!)
	_ride_panel = PanelContainer.new()
	_ride_panel.name = "RideHudPanel"
	_ride_panel.visible = false
	_ride_panel.anchor_left = 0.5
	_ride_panel.anchor_top = 1.0
	_ride_panel.anchor_right = 0.5
	_ride_panel.anchor_bottom = 1.0
	_ride_panel.offset_left = -338.0
	_ride_panel.offset_right = 246.0
	_ride_panel.offset_top = -178.0
	_ride_panel.offset_bottom = -18.0
	var rst: StyleBoxFlat = StyleBoxFlat.new()
	rst.bg_color = Color(0.07, 0.12, 0.22, 0.95)
	rst.border_width_left = 2
	rst.border_width_top = 2
	rst.border_width_right = 2
	rst.border_width_bottom = 2
	rst.border_color = Color(0.28, 0.66, 1.0, 0.95)
	rst.set_corner_radius_all(18)
	rst.content_margin_left = 14.0
	rst.content_margin_right = 14.0
	rst.content_margin_top = 10.0
	rst.content_margin_bottom = 10.0
	_ride_panel.add_theme_stylebox_override("panel", rst)
	_hud_layer.add_child(_ride_panel)

	var rvb: VBoxContainer = VBoxContainer.new()
	rvb.add_theme_constant_override("separation", 8)
	_ride_panel.add_child(rvb)

	_ride_status_lbl = Label.new()
	_ride_status_lbl.name = "RideStatusLabel"
	_ride_status_lbl.add_theme_font_size_override("font_size", 19)
	_ride_status_lbl.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
	_ride_status_lbl.clip_text = true
	rvb.add_child(_ride_status_lbl)

	var ctrl_row: HBoxContainer = HBoxContainer.new()
	ctrl_row.add_theme_constant_override("separation", 8)
	rvb.add_child(ctrl_row)

	_stop_select = OptionButton.new()
	_stop_select.name = "TargetStopSelect"
	_stop_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stop_select.custom_minimum_size = Vector2(0, 52)
	_stop_select.add_theme_font_size_override("font_size", 17)
	_stop_select.add_item("🚏 İneceğin durağı seç (otomatik iner)...", 0)
	for i: int in stops.size():
		_stop_select.add_item("%d. %s" % [i + 1, str(stops[i]["name"])], i + 1)
	_stop_select.item_selected.connect(func(sel_i: int) -> void:
		Sfx.play(&"ui_click")
		target_stop_idx = sel_i - 1)
	ctrl_row.add_child(_stop_select)

	_tour_btn = Button.new()
	_tour_btn.name = "ReplayTourButton"
	_tour_btn.text = "📖 Tanıtım"
	_tour_btn.custom_minimum_size = Vector2(114, 52)
	_tour_btn.add_theme_font_size_override("font_size", 17)
	_tour_btn.pressed.connect(func() -> void:
		Sfx.play(&"ui_click")
		open_onboarding_tour())
	ctrl_row.add_child(_tour_btn)

	_alight_now_btn = Button.new()
	_alight_now_btn.name = "AlightNowButton"
	_alight_now_btn.text = "İn"
	_alight_now_btn.custom_minimum_size = Vector2(82, 52)
	_alight_now_btn.add_theme_font_size_override("font_size", 19)
	_alight_now_btn.pressed.connect(func() -> void: alight_bus())
	ctrl_row.add_child(_alight_now_btn)

	# 4) Ringe İlk Biniş "UniPet Kampüs Tanıtım Turu" Kartı
	_onboarding_card = PanelContainer.new()
	_onboarding_card.name = "RingOnboardingCard"
	_onboarding_card.visible = false
	_onboarding_card.anchor_left = 0.5
	_onboarding_card.anchor_top = 0.5
	_onboarding_card.anchor_right = 0.5
	_onboarding_card.anchor_bottom = 0.5
	_onboarding_card.offset_left = -310.0
	_onboarding_card.offset_right = 310.0
	_onboarding_card.offset_top = -230.0
	_onboarding_card.offset_bottom = 95.0
	var ost: StyleBoxFlat = StyleBoxFlat.new()
	ost.bg_color = Color(0.08, 0.13, 0.24, 0.96)
	ost.border_width_left = 3
	ost.border_width_top = 3
	ost.border_width_right = 3
	ost.border_width_bottom = 3
	ost.border_color = Color(1.0, 0.80, 0.28, 0.96)
	ost.set_corner_radius_all(22)
	ost.content_margin_left = 20.0
	ost.content_margin_right = 20.0
	ost.content_margin_top = 16.0
	ost.content_margin_bottom = 16.0
	_onboarding_card.add_theme_stylebox_override("panel", ost)
	_hud_layer.add_child(_onboarding_card)

	var ovb: VBoxContainer = VBoxContainer.new()
	ovb.add_theme_constant_override("separation", 10)
	_onboarding_card.add_child(ovb)

	var top_oh: HBoxContainer = HBoxContainer.new()
	ovb.add_child(top_oh)

	_onboarding_title = Label.new()
	_onboarding_title.name = "OnboardingTitle"
	_onboarding_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_onboarding_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_onboarding_title.add_theme_font_size_override("font_size", 22)
	_onboarding_title.add_theme_color_override("font_color", Color(1.0, 0.90, 0.48))
	top_oh.add_child(_onboarding_title)

	var close_o: Button = Button.new()
	close_o.text = "✕"
	close_o.custom_minimum_size = Vector2(44, 44)
	close_o.pressed.connect(func() -> void: _finish_onboarding())
	top_oh.add_child(close_o)

	_onboarding_body = Label.new()
	_onboarding_body.name = "OnboardingBody"
	_onboarding_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_onboarding_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_onboarding_body.add_theme_font_size_override("font_size", 18)
	_onboarding_body.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
	ovb.add_child(_onboarding_body)

	_onboarding_quick_row = HBoxContainer.new()
	_onboarding_quick_row.add_theme_constant_override("separation", 6)
	_onboarding_quick_row.visible = false
	ovb.add_child(_onboarding_quick_row)

	for q_item: Array in [[7, "🏛 Tarihi Hamam'da İn"], [8, "🍽 Yemekhane'de İn"], [9, "🌳 İİBF / Ortabahçe'de İn"]]:
		var st_i: int = int(q_item[0])
		var qb: Button = Button.new()
		qb.text = str(q_item[1])
		qb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		qb.custom_minimum_size = Vector2(0, 44)
		qb.add_theme_font_size_override("font_size", 15)
		qb.pressed.connect(func() -> void:
			set_target_stop_index(st_i)
			_finish_onboarding())
		_onboarding_quick_row.add_child(qb)

	var onav: HBoxContainer = HBoxContainer.new()
	onav.add_theme_constant_override("separation", 10)
	ovb.add_child(onav)

	_onboarding_prev_btn = Button.new()
	_onboarding_prev_btn.text = "◀ Geri"
	_onboarding_prev_btn.custom_minimum_size = Vector2(120, 48)
	_onboarding_prev_btn.add_theme_font_size_override("font_size", 18)
	_onboarding_prev_btn.pressed.connect(func() -> void:
		Sfx.play(&"ui_click")
		_onboarding_step = maxi(0, _onboarding_step - 1)
		_refresh_onboarding_card())
	onav.add_child(_onboarding_prev_btn)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	onav.add_child(spacer)

	_onboarding_next_btn = Button.new()
	_onboarding_next_btn.name = "OnboardingNextButton"
	_onboarding_next_btn.custom_minimum_size = Vector2(160, 48)
	_onboarding_next_btn.add_theme_font_size_override("font_size", 18)
	_onboarding_next_btn.pressed.connect(func() -> void:
		Sfx.play(&"ui_click")
		if _onboarding_step + 1 < ONBOARDING_STEPS.size():
			_onboarding_step += 1
			_refresh_onboarding_card()
		else:
			_finish_onboarding())
	onav.add_child(_onboarding_next_btn)


func open_onboarding_tour() -> void:
	if _onboarding_card == null:
		return
	_onboarding_step = 0
	_onboarding_card.visible = true
	_refresh_onboarding_card()


func is_onboarding_visible() -> bool:
	return _onboarding_card != null and _onboarding_card.visible


func _refresh_onboarding_card() -> void:
	var step_d: Dictionary = ONBOARDING_STEPS[_onboarding_step]
	_onboarding_title.text = str(step_d["title"])
	_onboarding_body.text = str(step_d["body"])
	_onboarding_prev_btn.disabled = (_onboarding_step == 0)
	var is_last: bool = (_onboarding_step == ONBOARDING_STEPS.size() - 1)
	_onboarding_next_btn.text = "Yolculuğa Başla ✓" if is_last else "İleri ▶"
	_onboarding_quick_row.visible = is_last


func _finish_onboarding() -> void:
	if _onboarding_card != null:
		_onboarding_card.visible = false
	var prof: RefCounted = LocalProfile.load_or_default()
	if not bool(prof.get("onboarding_seen")):
		prof.set("onboarding_seen", true)
		prof.call("save")


func set_target_stop_index(stop_idx: int) -> void:
	target_stop_idx = clampi(stop_idx, -1, stops.size() - 1)
	if _stop_select != null:
		_stop_select.select(target_stop_idx + 1)


func get_live_buses() -> Array:
	var out: Array = []
	for b: Dictionary in _buses:
		out.append({
			"id": b["id"],
			"label": b["label"],
			"is_41at": b["is_41at"],
			"pos": b["pos"],
			"yaw": b["yaw"],
		})
	return out


func _process(delta: float) -> void:
	if _buses.is_empty() or loop_length <= 1.0:
		return
	_update_buses_transforms(delta)
	_update_player_riding_and_hud()


func _update_buses_transforms(delta: float) -> void:
	for bi: int in _buses.size():
		var b: Dictionary = _buses[bi]
		var dwell: float = float(b["dwell"])
		var cur_s: float = float(b["s"])
		if dwell > 0.0:
			dwell = maxf(0.0, dwell - delta)
			b["dwell"] = dwell
		else:
			# Sıradaki durağa yaklaşırken yumuşak yavaşlama ve durakta bekleme
			var nstop_i: int = _next_stop_index_from_s(cur_s)
			var dist_to_stop: float = _forward_dist_on_loop(cur_s, float(stops[nstop_i]["s"]))
			var speed: float = CRUISE_SPEED_MPS
			if dist_to_stop < STOP_APPROACH_SLOW_M and int(b["last_stop_idx"]) != nstop_i:
				speed = lerpf(3.2, CRUISE_SPEED_MPS, clampf(dist_to_stop / STOP_APPROACH_SLOW_M, 0.0, 1.0))
			var step_m: float = speed * delta
			if step_m > 0.0 and dist_to_stop <= maxf(step_m + 0.35, 0.8) and int(b["last_stop_idx"]) != nstop_i:
				cur_s = float(stops[nstop_i]["s"])
				b["dwell"] = STOP_DWELL_SEC
				b["last_stop_idx"] = nstop_i
				# Oyuncu bu otobüsteyse ve bu durağı seçtiyse otomatik indir!
				if riding_bus_idx == bi and target_stop_idx == nstop_i:
					b["s"] = cur_s
					_apply_bus_3d_pose(b)
					alight_bus(nstop_i)
					continue
			else:
				cur_s = fposmod(cur_s + step_m, loop_length)
				if dist_to_stop > 24.0 and int(b["last_stop_idx"]) == nstop_i:
					b["last_stop_idx"] = -1
			b["s"] = cur_s
		_apply_bus_3d_pose(b)


func _apply_bus_3d_pose(b: Dictionary) -> void:
	var pose: Dictionary = _sample_loop_pose(float(b["s"]))
	var pxz: Vector2 = pose["pos"]
	var fwd: Vector2 = pose["dir"]
	var yaw: float = atan2(fwd.x, fwd.y)
	# Güzergah sağ şerit ofseti (+1.55 m sağa: durak ceplerine tam yanaşsın ve çift yönlü yolda şeridinde gitsin)
	var right_2d: Vector2 = Vector2(-fwd.y, fwd.x)
	var lane_xz: Vector2 = pxz + right_2d * 1.45
	var y_back: float = TerrainHeight.active_height(lane_xz.x - fwd.x * 3.5, lane_xz.y - fwd.y * 3.5)
	var y_front: float = TerrainHeight.active_height(lane_xz.x + fwd.x * 3.5, lane_xz.y + fwd.y * 3.5)
	var y_mid: float = (y_back + y_front) * 0.5 + 0.09
	var pitch: float = -atan2(y_front - y_back, 7.0)

	b["pos"] = lane_xz
	b["yaw"] = yaw
	var nd: Node3D = b["node"] as Node3D
	if nd != null:
		nd.position = Vector3(lane_xz.x, y_mid, lane_xz.y)
		nd.rotation = Vector3(pitch, yaw, 0.0)


func _sample_loop_pose(s_val: float) -> Dictionary:
	var s: float = fposmod(s_val, loop_length)
	var m: int = waypoints.size()
	var lo: int = 0
	var hi: int = m - 1
	while lo < hi:
		var mid: int = (lo + hi + 1) >> 1
		if cum_lengths[mid] <= s:
			lo = mid
		else:
			hi = mid - 1
	var a: Vector2 = waypoints[lo]
	var b: Vector2 = waypoints[(lo + 1) % m]
	var seg_len: float = maxf(cum_lengths[lo + 1] - cum_lengths[lo], 0.001)
	var t: float = clampf((s - cum_lengths[lo]) / seg_len, 0.0, 1.0)
	var pos: Vector2 = a.lerp(b, t)
	var dir: Vector2 = (b - a) / seg_len
	if dir.length_squared() < 0.01:
		dir = Vector2(0.0, 1.0)
	return {"pos": pos, "dir": dir.normalized()}


func _forward_dist_on_loop(s_from: float, s_to: float) -> float:
	return fposmod(s_to - s_from, loop_length)


func _next_stop_index_from_s(s_from: float) -> int:
	var best_i: int = 0
	var best_d: float = INF
	for i: int in stops.size():
		var d: float = _forward_dist_on_loop(s_from, float(stops[i]["s"]))
		if d < best_d:
			best_d = d
			best_i = i
	return best_i


func _nearest_stop_index_xz(xz: Vector2) -> int:
	var best_i: int = 0
	var best_d: float = INF
	for i: int in stops.size():
		var d: float = xz.distance_to(stops[i]["shelter_pos"] as Vector2)
		if d < best_d:
			best_d = d
			best_i = i
	return best_i


static func _get_node_pos(n: Node3D) -> Vector3:
	return n.global_position if n.is_inside_tree() else n.position


static func _set_node_pos(n: Node3D, p: Vector3) -> void:
	if n.is_inside_tree():
		n.global_position = p
	else:
		n.position = p


func _find_boardable_bus_index() -> int:
	if player == null:
		return -1
	var p3: Vector3 = _get_node_pos(player)
	var p_xz: Vector2 = Vector2(p3.x, p3.z)
	var best_bi: int = -1
	var best_d: float = BOARD_RADIUS_M
	for bi: int in _buses.size():
		var b_xz: Vector2 = _buses[bi]["pos"]
		var d: float = p_xz.distance_to(b_xz)
		if d < best_d:
			best_d = d
			best_bi = bi
	return best_bi


func board_nearest_bus() -> bool:
	var bi: int = _find_boardable_bus_index()
	if bi < 0:
		return false
	return board_bus(bi)


func board_bus(bus_idx: int) -> bool:
	if bus_idx < 0 or bus_idx >= _buses.size() or player == null:
		return false
	riding_bus_idx = bus_idx
	Sfx.play(&"ui_click")
	# Yürüyüş hedefini temizle ve oyuncuyu otobüs yolcusu moduna al
	if has_node("../PlayerController"):
		var pc: Node = get_node("../PlayerController")
		if pc.has_method("clear_destination"):
			pc.call("clear_destination")
	if "frozen" in player:
		player.set("frozen", true)
	var col: CollisionShape3D = player.get_node_or_null("Collision") as CollisionShape3D
	if col != null:
		_saved_collision_disabled = col.disabled
		col.disabled = true

	# Aktif harita hedefi varsa en yakın durağını otomatik seç!
	if Services != null and not Services.active_waypoint.is_empty():
		var wp_xz: Vector2 = Services.active_waypoint.get("pos", Vector2.ZERO)
		set_target_stop_index(_nearest_stop_index_xz(wp_xz))
	else:
		set_target_stop_index(-1)

	# Bekleyen başlangıç otobüsüyse kapıları kapatıp kalkışa hazırla (2.5 sn içinde yumuşak kalkış)
	if float(_buses[bus_idx]["dwell"]) > 2.5:
		_buses[bus_idx]["dwell"] = 2.2

	if _board_btn != null:
		_board_btn.visible = false
	if _ride_panel != null:
		_ride_panel.visible = true

	# İlk kez Ring'e biniyorsa Tanıtım Turu'nu otomatik aç!
	var prof: RefCounted = LocalProfile.load_or_default()
	if not bool(prof.get("onboarding_seen")):
		open_onboarding_tour()

	var bus_info: Dictionary = _buses[bus_idx]
	boarded_bus.emit(str(bus_info["id"]), bool(bus_info["is_41at"]))
	return true


func alight_bus(stop_idx: int = -1) -> void:
	if riding_bus_idx < 0 or player == null:
		return
	var b: Dictionary = _buses[riding_bus_idx]
	var b_xz: Vector2 = b["pos"]
	var chosen_stop_i: int = stop_idx if stop_idx >= 0 else _nearest_stop_index_xz(b_xz)
	var exit_xz: Vector2 = b_xz
	var stop_id: String = ""
	var stop_nm: String = "Kampüs Yolu"
	if chosen_stop_i >= 0 and chosen_stop_i < stops.size():
		var st_d: Dictionary = stops[chosen_stop_i]
		var sh_xz: Vector2 = st_d["shelter_pos"]
		if b_xz.distance_to(sh_xz) <= 24.0 or stop_idx >= 0:
			exit_xz = sh_xz.lerp(st_d["road_pos"] as Vector2, 0.25)
			stop_id = str(st_d["id"])
			stop_nm = str(st_d["name"])
	if exit_xz == b_xz:
		var yaw: float = float(b["yaw"])
		var right_2d: Vector2 = Vector2(-cos(yaw), sin(yaw))
		exit_xz = b_xz + right_2d * 3.8
		if player.has_method("resolve_safe_outdoor_xz"):
			exit_xz = player.call("resolve_safe_outdoor_xz", exit_xz, 2.5)

	riding_bus_idx = -1
	target_stop_idx = -1
	var col: CollisionShape3D = player.get_node_or_null("Collision") as CollisionShape3D
	if col != null:
		col.disabled = _saved_collision_disabled
	if "frozen" in player:
		player.set("frozen", false)

	var gy: float = TerrainHeight.active_height(exit_xz.x, exit_xz.y) + 0.30
	_set_node_pos(player, Vector3(exit_xz.x, gy, exit_xz.y))
	if "velocity" in player:
		player.set("velocity", Vector3.ZERO)

	if _ride_panel != null:
		_ride_panel.visible = false
	if _onboarding_card != null:
		_onboarding_card.visible = false

	Sfx.play(&"care_ok")
	if has_node("../UI/CareHud"):
		var hud: Node = get_node("../UI/CareHud")
		if hud.has_method("show_toast"):
			hud.call("show_toast", "🚏 %s durağında indin!" % stop_nm, 3.0)
	alighted_bus.emit(stop_id, stop_nm)


func _update_player_riding_and_hud() -> void:
	if player == null:
		return
	if riding_bus_idx >= 0 and riding_bus_idx < _buses.size():
		var b: Dictionary = _buses[riding_bus_idx]
		var nd: Node3D = b["node"] as Node3D
		if nd != null:
			_set_node_pos(player, _get_node_pos(nd) + Vector3(0.0, 1.35, 0.0))
			player.rotation.y = float(b["yaw"])
		var nstop_i: int = _next_stop_index_from_s(float(b["s"]))
		var dist_m: int = roundi(_forward_dist_on_loop(float(b["s"]), float(stops[nstop_i]["s"])))
		var prefix: String = "🟨 İETT 41AT" if bool(b["is_41at"]) else "🟦 Mavi Ring"
		var dwell_s: float = float(b["dwell"])
		if _ride_status_lbl != null:
			if dwell_s > 0.1 and int(b["last_stop_idx"]) >= 0:
				var cur_nm: String = str(stops[int(b["last_stop_idx"])]["name"])
				_ride_status_lbl.text = "%s  ·  🚏 Durakta: %s (kalkışa %d sn)" % [prefix, cur_nm, ceili(dwell_s)]
			else:
				_ride_status_lbl.text = "%s  ·  📍 Sıradaki: %s (%d m)" % [prefix, str(stops[nstop_i]["name"]), dist_m]
		return

	# Yaya iken yakında otobüs var mı kontrol et
	var near_bi: int = _find_boardable_bus_index()
	if _board_btn != null:
		if near_bi >= 0:
			var nb: Dictionary = _buses[near_bi]
			_board_btn.visible = true
			_board_btn.text = "🚌 Efsane 41AT'ye Bin" if bool(nb["is_41at"]) else "🚌 Mavi Ring'e Bin (Ücretsiz)"
		else:
			_board_btn.visible = false


# ==============================================================================
# Yardımcı 3B Kutu / Silindir Üreticileri
# ==============================================================================

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


static func _cyl_x(st: SurfaceTool, xf: Transform3D, radius: float, w_x: float, center: Vector3, segs: int, col: Color) -> void:
	_cyl(st, xf * Transform3D(Basis(Vector3.FORWARD, PI * 0.5), center), radius, w_x, Vector3.ZERO, segs, col)


static func _cyl_z(st: SurfaceTool, xf: Transform3D, radius: float, len_z: float, center: Vector3, segs: int, col: Color) -> void:
	_cyl(st, xf * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), center), radius, len_z, Vector3.ZERO, segs, col)
