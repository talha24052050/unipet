extends SceneTree
## UniPet Tanıtım Filmi (agy kurgusu) — Tüm yeni ikonik YTÜ Davutpaşa içerikleriyle sinematik çekim
## (Godot Movie Maker, 1080x1920, 30 fps, 30.5 sn + 51 kare ısınma).
##
## Kullanım:
##   C:\Tools\Godot\godot_console.exe --path game --write-movie <çıktı>.avi --fixed-fps 30 --resolution 1080x1920 -s <repo>/tools/ad/cinematic_agy.gd
## Kurgu, tipografi, UI kartları ve ses miksajı:
##   python tools/ad/build_ad_agy.py <çıktı>.avi docs/media/unipet_tanitim_agy.mp4
##
## Çekimler (SHOTS — toplam 30.5 sn):
##   0. gate         (3.0 sn) A Kapısı İETT Durağı: Mavi YTÜ Ring yanaşıp kapılarını açar, yan şeritten efsane Sarı İETT 41AT geçer
##   1. yildiz_store (3.0 sn) ★ YTU YILDIZ STORE 3D tabela + I ❤ YTU duvar panosu + ahşap amfide takılan petler
##   2. love_cats    (3.0 sn) Ortabahçe dev I ❤ YTU yazısı + 5 renk Davutpaşa Kedisi (miyav + kalpler) + dönen Yıldız Tozları
##   3. merkez_lib   (2.5 sn) Yeni Merkez Kütüphanesi (-1. kat çökük avlu & ahşap amfi) + havaya savrulan vize kitapları & dans
##   4. hamam        (4.0 sn) Tarihi Hamam (-2m çökük avlu): gümüş ESLAB kahve minibüsü, dev ARTLAB afişi ve el sallayan 3D Voxel Sami
##   5. social       (3.5 sn) Hokka Kafe Sohbet Salonu halkası önünde canlı buluşma ve sohbet balonları
##   6. stadium      (3.0 sn) YTÜ Stadyumu: ışıklı kapılardan geçen 6'lı Koşu Yarışı + çimde Frizbi yakalayan petler
##   7. dressup      (2.5 sn) Altın saatte beat'e senkron 6 Pet & 11 Aksesuar (Çiçek Tacı, Yıldız Taç, Pelerin, Kanatlar) stil şovu
##   8. star         (2.0 sn) Gece sokak lambalarıyla ışıldayan Ortabahçe'ye düşen kayan yıldız ve altın şok dalgası
##   9. kutbi        (4.0 sn) Altın ışık çemberinden çıkan Efsanevi Yıldız Pet Kutbi + etrafında dans eden kampüs kalabalığı

var _th: GDScript
var _love_signs: GDScript
var _stardust_field: GDScript

const FPS: float = 30.0
const SHOTS: Array = [
	["gate", 3.0],
	["yildiz_store", 3.0],
	["love_cats", 3.0],
	["merkez_lib", 2.5],
	["hamam", 4.0],
	["social", 3.5],
	["stadium", 3.0],
	["dressup", 2.5],
	["star", 2.0],
	["kutbi", 4.0],
]

# Yıldız Store (yemekhane_plaza.gd ile birebir)
const STORE_P0: Vector2 = Vector2(-104.18, -58.13)
const STORE_P3: Vector2 = Vector2(-113.01, -47.20)

# Ortabahçe dev "I ❤ YTU" (love_signs.json #2: (38.4, 29.7), yaw -128.6 deg, arkası Tarihi Kışla)
const LOVE_SIGN_POS: Vector2 = Vector2(38.4, 29.7)
const LOVE_SIGN_YAW_DEG: float = -128.6

# Yeni Merkez Kütüphanesi (campus_landmarks.gd ile birebir)
const LIB_ORIGIN: Vector2 = Vector2(-74.33, -236.71)
const LIB_U: Vector2 = Vector2(0.809885, 0.586589)
const LIB_V: Vector2 = Vector2(-0.586589, 0.809885)
const LIB_Y_SUNK: float = -3.92

# Tarihi Hamam (tarihi_hamam.gd ile birebir)
const HAMAM_ORIGIN: Vector2 = Vector2(44.56, -161.98)
const HAMAM_U: Vector2 = Vector2(-0.630079, 0.776531)
const HAMAM_N: Vector2 = Vector2(-0.776519, -0.630094)

# Hokka Kafe önü açık bulvar (bina dışı doğrulandı; kapı halkası (-69.0, -114.5))
const HOKKA_PLAZA: Vector3 = Vector3(-66.2, 0.0, -118.0)
const HOKKA_DOOR: Vector3 = Vector3(-69.0, 0.0, -114.5)

# YTÜ Stadyumu koşu pisti ve frizbi sahası (race.json & minigames.json)
const RACE_CPS: Array = [
	[-322.51, 39.14], [-313.11, 4.73], [-296.80, -26.10],
	[-263.06, -32.93], [-237.47, -9.91], [-239.09, 24.94], [-248.49, 59.35],
]
const FRISBEE_SPOT: Vector3 = Vector3(-296.0, 0.0, 18.0)

# Ortabahçe stil, yıldız ve Kutbi noktaları
const COURTYARD: Vector3 = Vector3(12.0, 0.0, 20.0)
const DRESSUP_SPOT: Vector3 = Vector3(14.0, 0.0, 26.0)
const KUTBI_SPOT: Vector3 = Vector3(16.0, 0.0, 30.0)

const PETS: Array[StringName] = [&"mushnub", &"shark", &"chicken", &"ninja", &"birb", &"yeti"]
const NAMES: PackedStringArray = [
	"Zeynep", "Mert", "Ece", "Kaan", "Defne", "Arda", "Elif", "Can",
	"Ada", "Emir", "Nil", "Efe", "Su", "Deniz", "Bora", "Selin",
]
const EMOTES: Array[StringName] = [&"emote_dance", &"emote_wave", &"emote_jump", &"emote_yes"]
const ACC_SETS: Array = [
	{"head": "crown_star", "back": "cape"},
	{"head": "flower_crown", "neck": "scarf"},
	{"face": "sunglasses", "back": "wings"},
	{"head": "hat_cap", "face": "glasses", "back": "backpack"},
	{"head": "beanie", "neck": "bowtie"},
	{"head": "flower_crown", "back": "cape"},
	{"head": "crown_star", "face": "sunglasses"},
	{"back": "wings", "neck": "scarf"},
]
const DRESSUP_LOOKS: Array = [
	{"pet": &"shark", "acc": {"head": "crown_star", "back": "cape", "face": "sunglasses"}},
	{"pet": &"chicken", "acc": {"head": "flower_crown", "neck": "scarf"}},
	{"pet": &"ninja", "acc": {"back": "wings", "face": "glasses"}},
	{"pet": &"birb", "acc": {"head": "hat_cap", "back": "backpack", "neck": "bowtie"}},
	{"pet": &"yeti", "acc": {"head": "beanie", "back": "cape", "face": "sunglasses"}},
	{"pet": &"mushnub", "acc": {"head": "crown_star", "back": "wings", "face": "glasses"}},
]
const BOOK_COLORS: Array[Color] = [
	Color(0.86, 0.22, 0.24), Color(0.18, 0.48, 0.86), Color(0.96, 0.74, 0.18),
	Color(0.22, 0.68, 0.38), Color(0.60, 0.32, 0.78), Color(0.95, 0.94, 0.90),
]
const CONFETTI_COLORS: Array[Color] = [
	Color(1.0, 0.84, 0.22), Color(0.25, 0.78, 1.0), Color(1.0, 0.36, 0.56),
	Color(0.42, 0.95, 0.45), Color(0.82, 0.48, 1.0),
]
const STAR_COLOR: Color = Color(1.0, 0.86, 0.42)
const STAR_CORE_COLOR: Color = Color(1.0, 0.98, 0.86)
const HEART_COLOR: Color = Color(0.98, 0.30, 0.48)

var cam: Camera3D
var player_node: Node3D
var day_night: Node
var street_lights: Node
var transit: Node
var sami_node: Node3D
var frame: int = 0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _shot_started: Dictionary = {}
var _events_fired: Dictionary = {}

# Shot 0: A Kapısı + Mavi Ring + 41AT
var gate_pets: Array[Node3D] = []
var gate_fwd: Vector2 = Vector2(-0.799, -0.601)
var gate_right: Vector2 = Vector2(0.601, -0.799)
var gate_road_origin: Vector2 = Vector2(756.32, 564.81)

# Shot 1: Yıldız Store
var store_xf: Transform3D
var store_pets: Array[Node3D] = []

# Shot 2: I ❤ YTU + Kediler + Yıldız Tozu
var love_front: Vector3
var love_center: Vector3
var cat_pets: Array[Node3D] = []
var hero_cats: Array[Node3D] = []
var floating_hearts: Array[Dictionary] = []
var stardust_items: Array[Dictionary] = []

# Shot 3: Yeni Merkez Kütüphanesi
var lib_student: Node3D
var lib_peers: Array[Node3D] = []
var books: Array[MeshInstance3D] = []
var book_rest: Array[Transform3D] = []
var book_vel: Array[Vector3] = []
var book_spin: Array[Vector3] = []
var lib_confetti: Array[Dictionary] = []

# Shot 4: Tarihi Hamam + ESLAB + ARTLAB + Sami
var hamam_pets: Array[Node3D] = []

# Shot 5: Hokka Kafe Lounge
var social_pets: Array[Node3D] = []

# Shot 6: Stadyum Yarış + Frizbi
var racers: Array[Dictionary] = []
var frisbee_pets: Array[Node3D] = []
var frisbee_disc: MeshInstance3D
var frisbee_ring: MeshInstance3D

# Shot 7: Dress-up
var dressup_pet: Node3D
var dressup_idx: int = -1
var dressup_burst_t: float = -10.0
var dressup_sparks: Array[Dictionary] = []

# Shot 8 & 9: Kayan Yıldız & Kutbi Finali
var star_parts: Array[MeshInstance3D] = []
var star_hist: Array[Vector3] = []
var flash_core: MeshInstance3D
var shock_ring: MeshInstance3D
var flash_light: OmniLight3D
var impact_sparks: Array[Dictionary] = []

var finale_crowd: Array[Node3D] = []
var kutbi: Node3D
var kutbi_light: OmniLight3D
var kutbi_rim: OmniLight3D
var kutbi_ring: MeshInstance3D
var kutbi_embers: Array[Dictionary] = []


func _initialize() -> void:
	rng.seed = 20261125
	await process_frame  # Isınma karesi 1/51
	_th = load("res://src/world/terrain_height.gd")
	_love_signs = load("res://src/world/love_signs.gd")
	_stardust_field = load("res://src/collect/stardust_field.gd")
	change_scene_to_file("res://scenes/main.tscn")
	for i: int in 30:    # Isınma karesi 2..31/51
		await process_frame

	var s: Node = current_scene
	for cl: Node in s.find_children("*", "CanvasLayer", true, false):
		(cl as CanvasLayer).visible = false

	player_node = s.get_node("Player") as Node3D
	player_node.visible = false
	player_node.process_mode = Node.PROCESS_MODE_DISABLED

	day_night = s.get_node("DayNight")
	day_night.set_process(false)
	day_night.call("apply", 10.5)

	street_lights = s.get_node_or_null("World/StreetLights")
	if street_lights != null:
		street_lights.set_process(false)
		street_lights.call("set_day_mode", true)

	var env: Environment = (s.get_node("Environment") as WorldEnvironment).environment
	env.glow_enabled = true
	env.glow_intensity = 1.28
	env.glow_bloom = 0.20
	env.glow_hdr_threshold = 0.88

	transit = s.get_node("CampusTransit")
	transit.set("use_wall_clock", false)
	# Sahne döngüsünde otobüsleri biz güncelliyoruz ki 41AT'nin sinematik konumu process() tarafından ezilmesin!
	transit.set_process(false)

	sami_node = s.get_node_or_null("SamiNpc") as Node3D
	if sami_node != null:
		sami_node.set_process(false)
		var sv: Node3D = sami_node.get("visual") as Node3D
		if sv != null:
			sv.visible = true

	# RaceClient kapılarını parlat (Stadyum çekiminde ışıklı kontrol kapıları görünsün)
	var rc_node: Node = s.get_node_or_null("RaceClient")
	if rc_node != null:
		rc_node.set_process(false)
		var gmats: Array = rc_node.get("_gate_mats") as Array
		for gm_i: int in gmats.size():
			var gm: StandardMaterial3D = gmats[gm_i] as StandardMaterial3D
			if gm != null:
				var gc: Color = Color(1.0, 0.82, 0.24) if gm_i <= 1 else Color(0.28, 0.86, 0.98)
				gm.albedo_color = gc
				gm.emission_enabled = true
				gm.emission = gc
				gm.emission_energy_multiplier = 2.2

	cam = Camera3D.new()
	cam.far = 1200.0
	s.add_child(cam)
	cam.make_current()

	var RP: PackedScene = load("res://scenes/remote_player.tscn")
	_setup_gate(RP)
	_setup_yildiz_store(RP)
	_setup_love_cats(RP)
	_setup_merkez_lib(RP)
	_setup_hamam(RP)
	_setup_social(RP)
	_setup_stadium(RP)
	_setup_dressup(RP)
	_setup_star_and_kutbi(RP)

	# Sinematik çekimde hiçbir bina/tabela/aksesuar mesafe kırpmasıyla kaybolmasın
	for g: Node in s.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).visibility_range_end = 0.0

	for i: int in 20:    # Isınma karesi 32..51/51 (GODOT_SKIP = 51 / 30.0 sn)
		await process_frame

	var total: float = 0.0
	for sh: Array in SHOTS:
		total += float(sh[1])

	while frame / FPS < total - 0.0001:
		var t: float = float(frame) / FPS
		var start: float = 0.0
		for j: int in SHOTS.size():
			var sh: Array = SHOTS[j]
			var dur: float = float(sh[1])
			if t < start + dur - 0.0001 or j == SHOTS.size() - 1:
				var nm: String = str(sh[0])
				if not _shot_started.has(nm):
					_shot_started[nm] = true
					_on_shot_start(nm)
				_shot(nm, t - start, dur)
				break
			start += dur
		await process_frame
		frame += 1
	quit()


# ==============================================================================
# Kurulum Fonksiyonları
# ==============================================================================

func _setup_gate(RP: PackedScene) -> void:
	var st: Dictionary = (transit.get("stops") as Array)[0]
	gate_road_origin = st["road_pos"] as Vector2
	var sh_pos: Vector2 = st["shelter_pos"] as Vector2
	var pose0: Dictionary = transit.call("_sample_loop_pose", 2.0)
	gate_fwd = (pose0["dir"] as Vector2).normalized()
	gate_right = Vector2(-gate_fwd.y, gate_fwd.x)

	# Durak önünde bekleyen 5 heyecanlı pet
	for i: int in 5:
		var along_off: float = (float(i) - 2.0) * 1.28
		var p2: Vector2 = sh_pos - gate_right * 1.45 + gate_fwd * along_off
		var yaw: float = atan2(-gate_right.x, -gate_right.y)
		gate_pets.append(_spawn(RP, PETS[i % PETS.size()], NAMES[i], ACC_SETS[i % ACC_SETS.size()], Vector3(p2.x, 0.0, p2.y), yaw))


func _setup_yildiz_store(RP: PackedScene) -> void:
	var across: Vector2 = (STORE_P0 - STORE_P3).normalized()
	var out: Vector2 = Vector2(-across.y, across.x)
	var mid: Vector2 = (STORE_P3 + STORE_P0) * 0.5
	var base_y: float = _terrain_y(mid.x, mid.y)
	store_xf = Transform3D(Basis(Vector3(across.x, 0.0, across.y), Vector3.UP, Vector3(out.x, 0.0, out.y)), Vector3(mid.x, base_y, mid.y))

	# Ahşap amfi basamaklarında ve meydanda takılan petler
	var spots_local: Array = [
		Vector3(-4.2, 1.30, 3.8), Vector3(-2.6, 0.90, 5.1), Vector3(3.1, 1.10, 4.4), Vector3(4.8, 0.70, 5.8),
		Vector3(-1.4, 0.0, 9.6), Vector3(1.5, 0.0, 10.2), Vector3(3.6, 0.0, 9.2),
	]
	for i: int in spots_local.size():
		var wp: Vector3 = store_xf * (spots_local[i] as Vector3)
		var look_dir: Vector2 = out if i < 4 else -out
		var yaw: float = atan2(look_dir.x, look_dir.y) + rng.randf_range(-0.35, 0.35)
		var p: Node3D = _spawn(RP, PETS[(i + 1) % PETS.size()], NAMES[(i + 3) % NAMES.size()], ACC_SETS[(i + 2) % ACC_SETS.size()], wp, yaw)
		if i < 4:
			# Amfi merdiven basamak yüksekliğini koru
			p.global_position = Vector3(wp.x, base_y + (spots_local[i] as Vector3).y, wp.z)
		store_pets.append(p)


func _setup_love_cats(RP: PackedScene) -> void:
	var yaw_rad: float = deg_to_rad(LOVE_SIGN_YAW_DEG)
	love_front = Vector3(sin(yaw_rad), 0.0, cos(yaw_rad)).normalized()
	var love_right: Vector3 = Vector3(love_front.z, 0.0, -love_front.x)
	love_center = _ground(Vector3(LOVE_SIGN_POS.x, 0.0, LOVE_SIGN_POS.y))

	# I ❤ YTU önünde 3 sevimli pet (yazının ortasını kapatmamaları için iki yana dengeli dizilim)
	var pet_offs: Array = [-3.3, 2.9, 4.3]
	var pet_z_offs: Array = [2.6, 2.5, 3.6]
	for i: int in 3:
		var p: Vector3 = love_center + love_front * float(pet_z_offs[i]) + love_right * float(pet_offs[i])
		var yaw: float = atan2(love_front.x, love_front.z) + rng.randf_range(-0.25, 0.25)
		cat_pets.append(_spawn(RP, [&"mushnub", &"birb", &"chicken"][i], ["Zeynep", "Ece", "Kaan"][i], ACC_SETS[(i + 1) % ACC_SETS.size()], p, yaw))

	# 5 farklı tüy renginde Davutpaşa Kedisi (tam ön planda net görünsün)
	var CampusCat: GDScript = load("res://src/world/campus_cat.gd")
	var cat_seeds: Array[int] = [101, 102, 103, 104, 105]
	for i: int in 5:
		var c: Node3D = CampusCat.new()
		current_scene.add_child(c)
		var rx: float = (float(i) - 2.0) * 1.10
		var rz: float = 4.6 + (0.55 if i % 2 == 0 else -0.15)
		var cp: Vector3 = _ground(love_center + love_front * rz + love_right * rx)
		c.call("setup", cat_seeds[i], cp, 3.0)
		c.set_process(false)
		c.global_position = cp
		c.rotation.y = atan2(love_front.x, love_front.z) + rng.randf_range(-0.4, 0.4)
		hero_cats.append(c)

	# 3B kalpler (LoveSigns.heart_mesh ile gerçek kalp geometrisi!)
	var h_mesh: ArrayMesh = _love_signs.call("heart_mesh", 0.28, 0.06) as ArrayMesh
	var h_mat: StandardMaterial3D = StandardMaterial3D.new()
	h_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	h_mat.albedo_color = HEART_COLOR
	h_mat.emission_enabled = true
	h_mat.emission = HEART_COLOR
	h_mat.emission_energy_multiplier = 2.4
	for i: int in 14:
		var hm: MeshInstance3D = MeshInstance3D.new()
		hm.mesh = h_mesh
		hm.material_override = h_mat
		hm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		hm.visible = false
		current_scene.add_child(hm)
		var anchor_cat: Vector3 = hero_cats[i % hero_cats.size()].global_position
		floating_hearts.append({
			"node": hm,
			"origin": anchor_cat + Vector3(rng.randf_range(-0.35, 0.35), 0.45, rng.randf_range(-0.35, 0.35)),
			"t0": 0.25 + float(i) * 0.16,
		})

	# Ön planda dönen 4 altın Yıldız Tozu
	var s_mesh: Mesh = _stardust_field.call("star_mesh") as Mesh
	for i: int in 4:
		var sm: MeshInstance3D = MeshInstance3D.new()
		sm.mesh = s_mesh
		sm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		current_scene.add_child(sm)
		var sp: Vector3 = _ground(love_center + love_front * (5.5 + float(i % 2) * 0.8) + love_right * (-2.7 + float(i) * 1.8))
		sm.global_position = sp + Vector3.UP * 0.65
		stardust_items.append({"node": sm, "base": sp, "pick_t": 1.35 if i == 1 else (2.15 if i == 2 else 99.0)})


func _lib_pt(u: float, y: float, v: float) -> Vector3:
	return Vector3(LIB_ORIGIN.x + LIB_U.x * u + LIB_V.x * v, y, LIB_ORIGIN.y + LIB_U.y * u + LIB_V.y * v)


func _setup_merkez_lib(RP: PackedScene) -> void:
	# v=24.7 orta eksenindeki lale lambalarından (u=24, 31.5, 39, 46.5) tamamen açık nokta: u=35.5, v=21.6
	var st_pos: Vector3 = _lib_pt(35.5, LIB_Y_SUNK, 21.6)
	var face_cam_yaw: float = atan2(LIB_U.x * 0.85 - LIB_V.x * 0.45, LIB_U.y * 0.85 - LIB_V.y * 0.45)
	lib_student = _spawn(RP, &"mushnub", "Mert", {"face": "glasses"}, st_pos, face_cam_yaw)
	lib_student.global_position = st_pos

	# Sol ahşap amfi basamaklarında ve avluda oturan diğer öğrenciler
	var peer_uvs: Array = [
		[33.5, LIB_Y_SUNK, 27.6], [30.0, LIB_Y_SUNK, 22.2],
		[52.0, -2.42, 27.8], [54.2, -1.92, 29.4],
	]
	for i: int in peer_uvs.size():
		var uvy: Array = peer_uvs[i]
		var pp: Vector3 = _lib_pt(float(uvy[0]), float(uvy[1]), float(uvy[2]))
		var n: Node3D = _spawn(RP, PETS[(i + 2) % PETS.size()], NAMES[i + 5], ACC_SETS[(i + 3) % ACC_SETS.size()], pp, face_cam_yaw + rng.randf_range(-0.4, 0.4))
		n.global_position = pp
		lib_peers.append(n)

	# 3 renkli vize kitap kulesi
	var right_3d: Vector3 = Vector3(-LIB_V.x, 0.0, -LIB_V.y)
	var fwd_3d: Vector3 = Vector3(LIB_U.x, 0.0, LIB_U.y)
	var stacks: Array = [right_3d * -0.82, right_3d * 0.82, right_3d * -0.52 - fwd_3d * 0.62]
	for s_idx: int in stacks.size():
		var off: Vector3 = stacks[s_idx]
		var cnt: int = 12 if s_idx < 2 else 9
		var h: float = 0.0
		for i: int in cnt:
			var bm: MeshInstance3D = MeshInstance3D.new()
			var box: BoxMesh = BoxMesh.new()
			var th: float = rng.randf_range(0.065, 0.115)
			box.size = Vector3(rng.randf_range(0.36, 0.52), th, rng.randf_range(0.26, 0.34))
			var mat: StandardMaterial3D = StandardMaterial3D.new()
			mat.albedo_color = BOOK_COLORS[rng.randi() % BOOK_COLORS.size()]
			mat.roughness = 0.65
			box.material = mat
			bm.mesh = box
			current_scene.add_child(bm)
			var base: Vector3 = st_pos + off + Vector3(0.0, h + th * 0.5, 0.0)
			bm.global_transform = Transform3D(Basis(Vector3.UP, face_cam_yaw + rng.randf_range(-0.28, 0.28)), base)
			h += th
			books.append(bm)
			book_rest.append(bm.global_transform)
			var side_sign: float = -1.0 if s_idx != 1 else 1.0
			var vel_dir: Vector3 = (right_3d * side_sign * rng.randf_range(2.2, 4.6)) + Vector3(0.0, rng.randf_range(4.2, 7.0), 0.0) + fwd_3d * rng.randf_range(-1.8, 2.2)
			book_vel.append(vel_dir)
			book_spin.append(Vector3(rng.randf_range(-9.0, 9.0), rng.randf_range(-9.0, 9.0), rng.randf_range(-9.0, 9.0)))

	for i: int in 30:
		var m: MeshInstance3D = _make_glow_sphere(rng.randf_range(0.045, 0.085), CONFETTI_COLORS[i % CONFETTI_COLORS.size()], 4.2)
		var dir: Vector3 = Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(0.45, 1.5), rng.randf_range(-1.0, 1.0)).normalized()
		lib_confetti.append({"node": m, "vel": dir * rng.randf_range(2.8, 6.2)})


func _hamam_pt(s_m: float, y: float, d_m: float) -> Vector3:
	return Vector3(HAMAM_ORIGIN.x + HAMAM_U.x * s_m + HAMAM_N.x * d_m, y, HAMAM_ORIGIN.y + HAMAM_U.y * s_m + HAMAM_N.y * d_m)


func _setup_hamam(RP: PackedScene) -> void:
	# ESLAB kahve minibüsü (s=5.65, d=3.35), Sami ve ARTLAB afişi (s=26.70) önünde canlı kalabalık
	if sami_node != null:
		sami_node.global_position = _hamam_pt(21.4, -2.0, 3.85)
	var spots: Array = [
		[8.6, -2.0, 2.6],   # ESLAB servis penceresi önü (s < 11.2, merdivensiz açık alan!)
		[8.9, -2.0, 4.3],   # ESLAB önü 2. pet
		[19.2, -2.0, 4.6],  # Sami'nin solu
		[24.6, -2.0, 4.8],  # Sami'nin sağı / ARTLAB afişi önü
	]
	var face_cam_yaw: float = atan2(HAMAM_N.x, HAMAM_N.y)
	for i: int in spots.size():
		var sp: Array = spots[i]
		var p: Vector3 = _hamam_pt(float(sp[0]), float(sp[1]), float(sp[2]))
		var yaw_i: float = atan2(-HAMAM_U.x, -HAMAM_U.y) if i == 0 else face_cam_yaw + rng.randf_range(-0.3, 0.3)
		var n: Node3D = _spawn(RP, PETS[(i + 1) % PETS.size()], NAMES[i + 8], ACC_SETS[i % ACC_SETS.size()], p, yaw_i)
		n.global_position = p
		hamam_pets.append(n)


func _setup_social(RP: PackedScene) -> void:
	for i: int in 8:
		var a: float = TAU * float(i) / 8.0 + 0.22
		var r: float = 2.75 if i % 2 == 0 else 3.45
		var p: Vector3 = HOKKA_PLAZA + Vector3(cos(a) * r, 0.0, sin(a) * r)
		social_pets.append(_spawn(RP, PETS[i % PETS.size()], NAMES[i], ACC_SETS[i % ACC_SETS.size()], p, atan2(HOKKA_PLAZA.x - p.x, HOKKA_PLAZA.z - p.z)))


func _setup_stadium(RP: PackedScene) -> void:
	# 6 kulvarda depar atan yarışçılar
	for i: int in 6:
		var p0: Vector3 = Vector3(float(RACE_CPS[0][0]), 0.0, float(RACE_CPS[0][1]))
		var n: Node3D = _spawn(RP, PETS[i % PETS.size()], NAMES[i + 2], ACC_SETS[i % ACC_SETS.size()], p0, 2.875)
		(n.get("visual") as Node).call("set_locomotion", 6.8)
		var spd: float = 7.4 + (0.65 if i == 2 else rng.randf_range(-0.35, 0.35))
		racers.append({"node": n, "lane": (float(i) - 2.5) * 1.12, "speed": spd})

	# İç çim sahada Frizbi yakalayan 3 pet + parlayan Frizbi diski + hedef halkası
	for i: int in 3:
		var fp: Vector3 = FRISBEE_SPOT + Vector3(float(i - 1) * 3.8, 0.0, float(i % 2) * 2.4)
		frisbee_pets.append(_spawn(RP, PETS[(i + 3) % PETS.size()], "", ACC_SETS[(i + 4) % ACC_SETS.size()], fp, 1.8))

	frisbee_disc = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.32
	cm.bottom_radius = 0.36
	cm.height = 0.07
	var dmat: StandardMaterial3D = StandardMaterial3D.new()
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dmat.albedo_color = Color(1.0, 0.48, 0.14)
	dmat.emission_enabled = true
	dmat.emission = Color(1.0, 0.52, 0.16)
	dmat.emission_energy_multiplier = 3.2
	cm.material = dmat
	frisbee_disc.mesh = cm
	frisbee_disc.visible = false
	current_scene.add_child(frisbee_disc)

	frisbee_ring = MeshInstance3D.new()
	var tm: TorusMesh = TorusMesh.new()
	tm.inner_radius = 0.85
	tm.outer_radius = 1.08
	tm.material = dmat
	frisbee_ring.mesh = tm
	frisbee_ring.visible = false
	current_scene.add_child(frisbee_ring)


func _setup_dressup(RP: PackedScene) -> void:
	dressup_pet = _spawn(RP, &"shark", "", {"head": "crown_star", "back": "cape"}, DRESSUP_SPOT, 0.0)
	dressup_pet.visible = false
	for i: int in 24:
		var m: MeshInstance3D = _make_glow_sphere(rng.randf_range(0.045, 0.095), CONFETTI_COLORS[i % CONFETTI_COLORS.size()], 5.2)
		var dir: Vector3 = Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(0.25, 1.45), rng.randf_range(-1.0, 1.0)).normalized()
		dressup_sparks.append({"node": m, "vel": dir * rng.randf_range(2.4, 5.0)})


func _setup_star_and_kutbi(RP: PackedScene) -> void:
	for i: int in 32:
		var k: float = 1.0 - float(i) / 32.0
		var col: Color = STAR_COLOR.lerp(STAR_CORE_COLOR, pow(k, 3.0))
		star_parts.append(_make_glow_sphere(lerpf(0.35, 3.3, k * k), col, lerpf(3.2, 10.0, k), clampf(k, 0.14, 1.0)))

	flash_core = _make_glow_sphere(1.0, STAR_CORE_COLOR, 10.0, 0.95)

	shock_ring = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.82
	torus.outer_radius = 1.0
	torus.rings = 32
	torus.ring_segments = 12
	var rmat: StandardMaterial3D = StandardMaterial3D.new()
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmat.albedo_color = Color(STAR_COLOR.r, STAR_COLOR.g, STAR_COLOR.b, 0.92)
	rmat.emission_enabled = true
	rmat.emission = STAR_COLOR
	rmat.emission_energy_multiplier = 7.0
	torus.material = rmat
	shock_ring.mesh = torus
	shock_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shock_ring.visible = false
	current_scene.add_child(shock_ring)

	flash_light = OmniLight3D.new()
	flash_light.light_color = STAR_COLOR
	flash_light.omni_range = 120.0
	flash_light.light_energy = 0.0
	current_scene.add_child(flash_light)

	for i: int in 40:
		var m: MeshInstance3D = _make_glow_sphere(rng.randf_range(0.35, 0.85), STAR_COLOR.lerp(STAR_CORE_COLOR, rng.randf()), 7.0, 0.95)
		var ang: float = rng.randf_range(0.0, TAU)
		var spd: float = rng.randf_range(14.0, 38.0)
		impact_sparks.append({"node": m, "vel": Vector3(cos(ang) * spd, rng.randf_range(12.0, 32.0), sin(ang) * spd)})

	# Kutbi ve etrafında yarım ay şeklinde kutlama yapan 12 kampüs peti
	for i: int in 12:
		var a: float = lerpf(PI * 0.62, PI * 1.38, float(i) / 11.0) + rng.randf_range(-0.05, 0.05)
		var r: float = 4.6 if i % 2 == 0 else 5.8
		var p: Vector3 = KUTBI_SPOT + Vector3(sin(a) * r, 0.0, cos(a) * r)
		var n: Node3D = _spawn(RP, PETS[i % PETS.size()], NAMES[i], ACC_SETS[i % ACC_SETS.size()], p, atan2(KUTBI_SPOT.x - p.x, KUTBI_SPOT.z - p.z))
		n.visible = false
		finale_crowd.append(n)

	kutbi = _spawn(RP, &"kutbi", "", {}, KUTBI_SPOT, 0.0)
	kutbi.visible = false

	kutbi_light = OmniLight3D.new()
	kutbi_light.light_color = STAR_COLOR
	kutbi_light.omni_range = 9.5
	kutbi_light.light_energy = 0.0
	current_scene.add_child(kutbi_light)

	kutbi_rim = OmniLight3D.new()
	kutbi_rim.light_color = Color(0.52, 0.72, 1.0)
	kutbi_rim.omni_range = 8.0
	kutbi_rim.light_energy = 0.0
	current_scene.add_child(kutbi_rim)

	kutbi_ring = MeshInstance3D.new()
	var ring_mesh: TorusMesh = TorusMesh.new()
	ring_mesh.inner_radius = 1.08
	ring_mesh.outer_radius = 1.22
	ring_mesh.rings = 40
	ring_mesh.ring_segments = 10
	var kmat: StandardMaterial3D = StandardMaterial3D.new()
	kmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	kmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	kmat.albedo_color = Color(STAR_COLOR.r, STAR_COLOR.g, STAR_COLOR.b, 0.88)
	kmat.emission_enabled = true
	kmat.emission = STAR_COLOR
	kmat.emission_energy_multiplier = 5.8
	ring_mesh.material = kmat
	kutbi_ring.mesh = ring_mesh
	kutbi_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	kutbi_ring.visible = false
	current_scene.add_child(kutbi_ring)

	for i: int in 52:
		var col: Color = STAR_COLOR if i % 3 != 0 else Color(0.74, 0.88, 1.0)
		var m: MeshInstance3D = _make_glow_sphere(rng.randf_range(0.022, 0.048), col, 5.2, 0.90)
		kutbi_embers.append({
			"node": m,
			"ang": rng.randf_range(0.0, TAU),
			"rad": rng.randf_range(0.85, 1.65),
			"y0": rng.randf_range(-0.1, 2.4),
			"rise": rng.randf_range(0.38, 0.88),
			"spin": rng.randf_range(0.45, 1.25) * (1.0 if i % 2 == 0 else -1.0),
		})


# ==============================================================================
# Sahne Başlangıç & Kare Güncellemeleri
# ==============================================================================

func _on_shot_start(nm: String) -> void:
	var period: float = float(transit.get("_period"))
	match nm:
		"gate":
			# Mavi Ring #1 1.15 sn sonra A Kapısı durağına tam yanaşıp kayar kapılarını açsın
			transit.set("_sim_time", period - 1.15)
		"yildiz_store":
			# Spor Kompleksi / Yıldız Store önünden Mavi Ring arkadan süzülerek geçsin
			var arr_t: float = float((transit.get("_stop_arrival_t") as PackedFloat32Array)[4])
			if arr_t > 5.0:
				transit.set("_sim_time", arr_t - 3.5)
		"dressup":
			dressup_pet.visible = true
			frisbee_disc.visible = false
			frisbee_ring.visible = false
		"star":
			dressup_pet.visible = false
			for sp: Dictionary in dressup_sparks:
				(sp["node"] as MeshInstance3D).visible = false
			player_node.global_position = _ground(KUTBI_SPOT)
			if street_lights != null:
				street_lights.call("set_day_mode", false)
				street_lights.call("update_lights")
		"kutbi":
			flash_core.visible = false
			shock_ring.visible = false
			flash_light.light_energy = 0.0
			for sp: Dictionary in impact_sparks:
				(sp["node"] as MeshInstance3D).visible = false
			for p_s: MeshInstance3D in star_parts:
				p_s.visible = false
			for fc: Node3D in finale_crowd:
				fc.visible = true
			player_node.global_position = _ground(KUTBI_SPOT)
			if street_lights != null:
				street_lights.call("set_day_mode", false)
				street_lights.call("update_lights")


func _once(key: String) -> bool:
	if _events_fired.has(key):
		return false
	_events_fired[key] = true
	return true


func _shot(nm: String, t: float, dur: float) -> void:
	if transit != null:
		transit.call("_update_buses_transforms", 1.0 / FPS)
	var k: float = clampf(t / dur, 0.0, 1.0)
	var e: float = _ease(k)
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.fov = 58.0

	match nm:
		"gate":
			day_night.call("apply", 10.2)
			# Sembolik Sarı-Siyah İETT 41AT, Mavi Ring'in hemen sol şeridinden aynı kadrajda süzülerek geçer!
			var buses: Array = transit.get("_buses") as Array
			var ring_node: Node3D = buses[0]["node"] as Node3D
			var bus41: Dictionary = buses[4]
			var bus41_node: Node3D = bus41["node"] as Node3D
			bus41["active"] = true
			bus41_node.visible = true
			var s_41: float = lerpf(-13.5, 5.2, k)
			var xz_41: Vector2 = gate_road_origin + gate_fwd * s_41 - gate_right * 1.55
			var y_b: float = _terrain_y(xz_41.x - gate_fwd.x * 3.5, xz_41.y - gate_fwd.y * 3.5)
			var y_f: float = _terrain_y(xz_41.x + gate_fwd.x * 3.5, xz_41.y + gate_fwd.y * 3.5)
			bus41_node.position = Vector3(xz_41.x, (y_b + y_f) * 0.5 + 0.09, xz_41.y)
			bus41_node.rotation = Vector3(-atan2(y_f - y_b, 7.0), atan2(gate_fwd.x, gate_fwd.y), 0.0)
			var d41: MeshInstance3D = bus41.get("doors") as MeshInstance3D
			if d41 != null:
				d41.position = Vector3.ZERO

			if t >= 0.25 and _once("gate_b1"):
				_bubble(gate_pets[1], "41AT ve Mavi Ring geldi!", 2.6)
			if t >= 1.20 and _once("gate_jump"):
				for i: int in gate_pets.size():
					(gate_pets[i].get("visual") as Node).call("play_emote", &"emote_jump" if i % 2 == 0 else &"emote_wave")

			# İki otobüsün de (Mavi Ring + Sarı 41AT) ön LED tabelalarını + açılan kapıyı + bekleyen petleri tek kadraja alan geniş açı
			var cam_xz: Vector2 = gate_road_origin + gate_fwd * lerpf(21.5, 16.5, e) + gate_right * lerpf(2.8, 1.9, e)
			cam.fov = lerpf(65.0, 58.0, e)
			cam.global_position = _ground(Vector3(cam_xz.x, 0.0, cam_xz.y)) + Vector3.UP * lerpf(3.0, 2.25, e)
			var focus_xz: Vector2 = gate_road_origin + gate_fwd * lerpf(-0.5, 2.2, e) - gate_right * 0.15
			cam.look_at(Vector3(focus_xz.x, ring_node.global_position.y + 1.65, focus_xz.y))

		"yildiz_store":
			day_night.call("apply", 14.8)
			if t >= 0.20 and _once("store_emote"):
				for i: int in store_pets.size():
					(store_pets[i].get("visual") as Node).call("play_emote", EMOTES[i % EMOTES.size()])
				_bubble(store_pets[1], "Yıldız Store merdivenlerindeyiz! ⭐", 2.7)
			if t >= 1.25 and _once("store_b2"):
				_bubble(store_pets[4], "Yemekten sonra kahve?", 2.0)

			cam.fov = lerpf(60.0, 54.0, e)
			cam.global_position = store_xf * Vector3(lerpf(-5.2, 4.2, e), lerpf(2.85, 2.25, e), lerpf(16.8, 13.2, e))
			cam.look_at(store_xf * Vector3(lerpf(-0.4, 0.2, e), lerpf(2.75, 2.55, e), 1.0))

		"love_cats":
			day_night.call("apply", 16.1)
			var love_right: Vector3 = Vector3(love_front.z, 0.0, -love_front.x)
			if t >= 0.25 and _once("cats_wave"):
				(cat_pets[0].get("visual") as Node).call("play_emote", &"emote_wave")
				(cat_pets[2].get("visual") as Node).call("play_emote", &"emote_dance")
				_bubble(cat_pets[1], "Davutpaşa kedileri çok tatlı! 🐾", 2.6)
			if t >= 1.35 and _once("cats_jump"):
				(cat_pets[1].get("visual") as Node).call("play_emote", &"emote_jump")

			# Kedilerin kuyruk sallaması ve petlerin etrafında sevgiyle dönmesi
			for i: int in hero_cats.size():
				var c: Node3D = hero_cats[i]
				var tail: Node3D = c.get("_tail") as Node3D
				if tail != null:
					tail.rotation.z = sin(t * 7.5 + float(i)) * 0.55
				if i % 2 == 1:
					var orbit_a: float = t * 1.45 + float(i) * 2.1
					var center_p: Vector3 = cat_pets[i % cat_pets.size()].global_position
					var np: Vector3 = _ground(center_p + Vector3(cos(orbit_a) * 1.05, 0.0, sin(orbit_a) * 1.05))
					var dv: Vector3 = np - c.global_position
					c.global_position = np
					if dv.length_squared() > 0.0001:
						c.rotation.y = atan2(dv.x, dv.z)

			# Kalpler yükselir
			for h: Dictionary in floating_hearts:
				var hm: MeshInstance3D = h["node"]
				var ht: float = t - float(h["t0"])
				hm.visible = ht > 0.0 and ht < 1.35
				if hm.visible:
					var orig: Vector3 = h["origin"]
					hm.global_position = orig + Vector3(sin(ht * 5.5) * 0.14, ht * 1.15, 0.0)
					hm.rotation.y = cam.global_rotation.y
					hm.scale = Vector3.ONE * sin(clampf(ht / 1.35, 0.0, 1.0) * PI)

			# Yıldız tozları döner ve 2 tanesi parlayarak toplanır
			for sd: Dictionary in stardust_items:
				var sm: MeshInstance3D = sd["node"]
				var pt: float = float(sd["pick_t"])
				var base_p: Vector3 = sd["base"]
				sm.rotation.y = t * 2.8
				if t < pt:
					sm.visible = true
					sm.scale = Vector3.ONE
					sm.global_position = base_p + Vector3.UP * (0.68 + sin(t * 3.2) * 0.12)
				elif t < pt + 0.38:
					var pk: float = (t - pt) / 0.38
					sm.visible = true
					sm.scale = Vector3.ONE * lerpf(1.0, 2.4, pk) * (1.0 - pk * 0.7)
					sm.global_position = base_p + Vector3.UP * lerpf(0.7, 2.0, pk)
				else:
					sm.visible = false

			cam.fov = lerpf(60.0, 54.0, e)
			cam.global_position = love_center + love_front * lerpf(11.4, 9.4, e) + love_right * lerpf(-1.8, 1.6, e) + Vector3.UP * lerpf(2.35, 1.75, e)
			cam.look_at(love_center + love_front * 1.6 + Vector3.UP * 0.90)

		"merkez_lib":
			for h: Dictionary in floating_hearts:
				(h["node"] as MeshInstance3D).visible = false
			day_night.call("apply", 15.4)
			var st: Vector3 = lib_student.global_position
			if t >= 0.08 and _once("lib_sad"):
				(lib_student.get("visual") as Node).call("play_emote", &"emote_no")
				_bubble(lib_student, "Finaller yetişmiyor...", 0.95)
			var burst: float = 1.05
			if t >= burst and _once("lib_burst"):
				(lib_student.get("visual") as Node).call("play_emote", &"emote_dance")
				_bubble(lib_student, "Mola zamanı! 🎉", 1.5)
				for p_peer: Node3D in lib_peers:
					(p_peer.get("visual") as Node).call("play_emote", &"emote_jump")

			for i: int in books.size():
				var dt: float = t - burst - float(i % 9) * 0.014
				if dt <= 0.0:
					books[i].global_transform = book_rest[i]
				else:
					var p0: Vector3 = book_rest[i].origin
					var v: Vector3 = book_vel[i]
					var p: Vector3 = p0 + v * dt + Vector3.DOWN * 6.0 * dt * dt
					var floor_y: float = LIB_Y_SUNK + 0.05
					if p.y < floor_y:
						var over: float = floor_y - p.y
						p.y = floor_y + maxf(0.0, over * 0.25 - over * over * 0.08)
					var rot_v: Vector3 = book_spin[i]
					var b: Basis = book_rest[i].basis
					if p.y > floor_y + 0.02:
						b = b.rotated(Vector3.RIGHT, rot_v.x * dt).rotated(Vector3.UP, rot_v.y * dt).rotated(Vector3.FORWARD, rot_v.z * dt)
					books[i].global_transform = Transform3D(b, p)

			var c_dt: float = t - burst
			for cf: Dictionary in lib_confetti:
				var m: MeshInstance3D = cf["node"]
				m.visible = c_dt > 0.0 and c_dt < 1.45
				if m.visible:
					m.global_position = st + Vector3.UP * 0.85 + (cf["vel"] as Vector3) * c_dt + Vector3.DOWN * 3.4 * c_dt * c_dt
					m.scale = Vector3.ONE * clampf(1.0 - c_dt / 1.45, 0.0, 1.0)

			var shake: Vector3 = Vector3.ZERO
			if c_dt > 0.0 and c_dt < 0.24:
				var amp: float = (1.0 - c_dt / 0.24) * 0.13
				shake = Vector3(sin(t * 78.0) * amp, cos(t * 64.0) * amp, 0.0)

			cam.fov = lerpf(60.0, 64.0, _ease(clampf((t - burst) / 0.7, 0.0, 1.0)))
			# v=19.6..20.6 koridorundan bakış: lamba direkleri (v=24.7) tamamen sol-arkada kalır, kütüphane girişi + ahşap amfi tam karşıda!
			cam.global_position = _lib_pt(lerpf(43.2, 39.8, e), lerpf(-1.45, -2.25, e), lerpf(19.4, 20.4, e)) + shake
			cam.look_at(_lib_pt(25.5, lerpf(-2.5, -1.7, e), 24.8))

		"hamam":
			for cf: Dictionary in lib_confetti:
				(cf["node"] as MeshInstance3D).visible = false
			day_night.call("apply", 16.0)
			if t < 1.50:
				# Açı A (0.0 - 1.5 sn, 3 vuruş): Merdiven 1'in solunda (s < 11.2) %100 engelsiz gümüş ESLAB Citroën Type-H kahve minibüsü!
				var ke: float = _ease(t / 1.50)
				if t >= 0.15 and _once("hamam_pets_1"):
					(hamam_pets[0].get("visual") as Node).call("play_emote", &"emote_wave")
					(hamam_pets[1].get("visual") as Node).call("play_emote", &"emote_jump")
					_bubble(hamam_pets[1], "ESLAB'dan kahvemi aldım!", 1.35)
				cam.keep_aspect = Camera3D.KEEP_WIDTH
				cam.fov = lerpf(66.0, 60.0, ke)
				cam.global_position = _hamam_pt(lerpf(11.0, 10.6, ke), lerpf(0.4, 0.1, ke), lerpf(8.4, 8.0, ke))
				cam.look_at(_hamam_pt(6.4, -0.9, 3.0))
			else:
				# Açı B: çitin üstünden (y=+3) çökük avluya yukarıdan bakış — Sami NPC + 12.5 m'lik ARTLAB afişi tek kadrajda
				var ks: float = _ease((t - 1.50) / 2.50)
				cam.keep_aspect = Camera3D.KEEP_WIDTH
				cam.fov = lerpf(64.0, 58.0, ks)
				cam.global_position = _hamam_pt(lerpf(22.4, 24.0, ks), lerpf(3.6, 3.0, ks), lerpf(12.6, 11.2, ks))
				cam.look_at(_hamam_pt(lerpf(23.2, 23.8, ks), lerpf(0.4, 0.7, ks), 1.6))
				if sami_node != null:
					var sv: Node3D = sami_node.get("visual") as Node3D
					if sv != null:
						sv.visible = true
					var cam_dir: Vector2 = Vector2(cam.global_position.x - sami_node.global_position.x, cam.global_position.z - sami_node.global_position.z)
					if cam_dir.length() > 0.1:
						sami_node.rotation.y = atan2(cam_dir.x, cam_dir.y)
					if t >= 1.58 and _once("sami_wave"):
						sami_node.call("_play_anim", "Wave")
						var sb: Node = sami_node.get("_bubble") as Node
						if sb != null:
							sb.call("show_message", "ARTLAB Zirvesi'ne hoş geldin!", 2.4)
						for i: int in [2, 3]:
							(hamam_pets[i].get("visual") as Node).call("play_emote", EMOTES[i % EMOTES.size()])
					if t >= 2.75 and _once("sami_jump"):
						sami_node.call("_play_anim", "Jump")
						_bubble(hamam_pets[3], "UniPet yakında!", 1.4)

		"social":
			day_night.call("apply", 16.9)
			if frame % 15 == 0:
				for i: int in social_pets.size():
					if (i + frame / 15) % 3 == 0:
						(social_pets[i].get("visual") as Node).call("play_emote", EMOTES[(i + frame) % EMOTES.size()])
			var chat_lines: Array = [
				[0.15, 0, "Hokka'da masa tuttuk! ☕"],
				[0.85, 3, "Arkadaş ekledim! 👋"],
				[1.65, 5, "Büyük Ev'e de geçelim!"],
				[2.40, 2, "Süper ortam! ✨"],
			]
			for li: Array in chat_lines:
				var bkey: String = "soc_%d" % int(li[1])
				if t >= float(li[0]) and _once(bkey):
					_bubble(social_pets[int(li[1])], str(li[2]), 2.9)

			var c: Vector3 = _ground(HOKKA_PLAZA) + Vector3.UP * 0.85
			var focus: Vector3 = c.lerp(_ground(HOKKA_DOOR) + Vector3.UP * 1.1, 0.35)
			# Kamera güneydoğu açık bulvardan Hokka cam cephesine ve kapı halkasına bakar
			var ang: float = lerpf(0.45, -0.25, e)
			var r: float = lerpf(6.2, 8.2, e)
			cam.fov = 56.0
			cam.global_position = c + Vector3(sin(ang) * r + 2.2, lerpf(1.75, 2.85, e), -cos(ang) * r - 2.2)
			cam.look_at(focus)

		"stadium":
			day_night.call("apply", 17.4)
			var lead: Vector3 = Vector3.ZERO
			var lead_d: float = -1.0
			for rc: Dictionary in racers:
				# d=35.7m'deki ışıklı yarış kapısının tam içinden (t ~ 1.7 sn) geçecek mesafe başlangıcı!
				var dist: float = 21.5 + float(rc["speed"]) * t
				var pose: Array = _track_pose(dist, float(rc["lane"]))
				var n: Node3D = rc["node"]
				n.global_position = _ground(pose[0])
				n.rotation.y = float(pose[1])
				if dist > lead_d:
					lead_d = dist
					lead = n.global_position

			# Yandaki yeşil çim sahada Frizbi uçuşu ve zıplayarak yakalama!
			frisbee_disc.visible = true
			frisbee_ring.visible = true
			var f_from: Vector3 = _ground(FRISBEE_SPOT + Vector3(10.0, 0.0, -10.0)) + Vector3.UP * 1.2
			var catcher: Node3D = frisbee_pets[1]
			var f_to: Vector3 = catcher.global_position + Vector3.UP * 0.9
			var fu: float = clampf(t / 1.85, 0.0, 1.0)
			var fp: Vector3 = f_from.lerp(f_to, fu) + Vector3.UP * (4.0 * 2.8 * fu * (1.0 - fu))
			frisbee_disc.global_position = fp if t < 1.88 else (f_to + Vector3.UP * 0.6)
			frisbee_disc.rotation = Vector3(0.25, t * 14.0, 0.0)
			frisbee_ring.global_position = Vector3(f_to.x, catcher.global_position.y + 0.08, f_to.z)
			var rs: float = lerpf(1.35, 0.75, fu)
			frisbee_ring.scale = Vector3(rs, 1.0, rs)
			if t >= 1.75 and _once("frisbee_catch"):
				for fp_pet: Node3D in frisbee_pets:
					(fp_pet.get("visual") as Node).call("play_emote", &"emote_jump")
				_bubble(catcher, "Yakaladım! +5", 1.5)

			# Kamera pistin gerçek BATI dış kenarından (outer_west = (fwd.z, 0, -fwd.x)) DOĞUYA (saha + ışıklı kapı + tribün + projektörler yönüne!) bakar!
			var lp: Array = _track_pose(lead_d, 0.0)
			var dir: float = float(lp[1])
			var fwd: Vector3 = Vector3(sin(dir), 0.0, cos(dir))
			var outer_west: Vector3 = Vector3(fwd.z, 0.0, -fwd.x)
			cam.fov = lerpf(64.0, 58.0, e)
			cam.global_position = lead + fwd * lerpf(7.8, 5.2, e) + outer_west * lerpf(5.8, 4.2, e) + Vector3.UP * lerpf(2.2, 1.45, e)
			cam.look_at(lead + Vector3.UP * 0.85 - fwd * 2.5 - outer_west * 3.8)

		"dressup":
			day_night.call("apply", 17.7)
			var step_dur: float = dur / float(DRESSUP_LOOKS.size())
			var step_idx: int = clampi(int(t / step_dur), 0, DRESSUP_LOOKS.size() - 1)
			if step_idx != dressup_idx:
				dressup_idx = step_idx
				dressup_burst_t = t
				var look: Dictionary = DRESSUP_LOOKS[dressup_idx]
				dressup_pet.call("apply_profile", {"pet": str(look["pet"]), "name": "", "acc": look["acc"]})
				var vis: Node = dressup_pet.get("visual")
				if dressup_idx == DRESSUP_LOOKS.size() - 1:
					vis.call("play_emote", &"emote_dance")
				else:
					vis.call("play_emote", &"emote_jump" if dressup_idx % 2 == 0 else &"emote_wave")

			var dt_pop: float = t - dressup_burst_t
			dressup_pet.scale = Vector3.ONE * lerpf(0.62, 1.04, _ease_out_back(dt_pop / 0.22))
			dressup_pet.rotation.y = lerpf(-0.48, 0.48, sin(t * 2.6) * 0.5 + 0.5)

			var origin: Vector3 = dressup_pet.global_position + Vector3.UP * 0.78
			for sp: Dictionary in dressup_sparks:
				var m: MeshInstance3D = sp["node"]
				m.visible = dt_pop < 0.38
				if m.visible:
					m.global_position = origin + (sp["vel"] as Vector3) * dt_pop + Vector3.DOWN * 4.2 * dt_pop * dt_pop
					m.scale = Vector3.ONE * clampf(1.0 - dt_pop / 0.38, 0.0, 1.0)

			var c: Vector3 = dressup_pet.global_position + Vector3.UP * 0.68
			var orbit: float = lerpf(-0.68, 0.72, e)
			var dist_c: float = lerpf(3.95, 3.15, e)
			cam.fov = 52.0
			cam.global_position = c + Vector3(sin(orbit) * dist_c, lerpf(0.85, 0.48, k), cos(orbit) * dist_c)
			cam.look_at(c + Vector3.UP * 0.12)

		"star":
			day_night.call("apply", 21.8)
			cam.keep_aspect = Camera3D.KEEP_WIDTH
			cam.fov = lerpf(70.0, 60.0, e)
			cam.global_position = COURTYARD + Vector3(lerpf(-8.0, 4.0, k), lerpf(38.0, 28.0, e), lerpf(142.0, 118.0, e))
			cam.look_at(COURTYARD + Vector3(0.0, lerpf(34.0, 8.0, e), lerpf(-120.0, -30.0, e)))

			var impact_t: float = 1.35  # Genel zaman = 24.5 + 1.35 = 25.85 sn
			var fall: float = clampf(t / impact_t, 0.0, 1.0)
			var a: Vector3 = COURTYARD + Vector3(-160.0, 160.0, -280.0)
			var b: Vector3 = COURTYARD + Vector3(22.0, 78.0, -135.0)
			var land: Vector3 = _ground(KUTBI_SPOT) + Vector3.UP * 1.1
			var head: Vector3 = a.lerp(b, fall).lerp(b.lerp(land, fall), fall)
			star_hist.push_front(head)
			if star_hist.size() > star_parts.size():
				star_hist.resize(star_parts.size())
			for i: int in star_parts.size():
				star_parts[i].visible = fall < 1.0 and i < star_hist.size()
				if star_parts[i].visible:
					star_parts[i].global_position = star_hist[i]

			var post_t: float = t - impact_t
			var fk: float = clampf(post_t / 0.65, 0.0, 1.0)
			flash_core.visible = post_t >= 0.0
			shock_ring.visible = post_t >= 0.0
			if post_t >= 0.0:
				flash_core.global_position = land
				flash_core.scale = Vector3.ONE * lerpf(1.5, 36.0, _ease(fk))
				(flash_core.mesh.surface_get_material(0) as StandardMaterial3D).albedo_color.a = lerpf(0.98, 0.0, fk)

				shock_ring.global_position = land + Vector3.UP * 0.4
				var ring_s: float = lerpf(2.2, 50.0, _ease(fk))
				shock_ring.scale = Vector3(ring_s, 1.0, ring_s)
				(shock_ring.mesh.surface_get_material(0) as StandardMaterial3D).albedo_color.a = lerpf(0.96, 0.0, fk)

				flash_light.global_position = land + Vector3.UP * 4.0
				flash_light.light_energy = 28.0 * (1.0 - fk)
			else:
				flash_light.light_energy = 0.0

			for sp: Dictionary in impact_sparks:
				var m: MeshInstance3D = sp["node"]
				m.visible = post_t > 0.0 and post_t < 0.65
				if m.visible:
					m.global_position = land + (sp["vel"] as Vector3) * post_t + Vector3.DOWN * 18.0 * post_t * post_t
					m.scale = Vector3.ONE * clampf(1.0 - post_t / 0.65, 0.0, 1.0)

		"kutbi":
			day_night.call("apply", 21.8)
			kutbi.visible = true
			var kp: Vector3 = kutbi.global_position
			var grow: float = _ease_out_back(clampf(t / 0.80, 0.0, 1.0))
			kutbi.scale = Vector3.ONE * lerpf(0.05, 1.12, grow)
			kutbi_light.global_position = kp + Vector3(0.4, 1.15, 1.6)
			kutbi_light.light_energy = lerpf(4.8, 1.55, clampf(t / 1.0, 0.0, 1.0))
			kutbi_rim.global_position = kp + Vector3(-1.4, 1.5, -1.6)
			kutbi_rim.light_energy = 2.2

			kutbi_ring.visible = true
			kutbi_ring.global_position = kp + Vector3.UP * 0.08
			var pulse: float = 1.0 + sin(t * 3.8) * 0.06
			kutbi_ring.scale = Vector3(pulse * grow, 1.0, pulse * grow)
			kutbi_ring.rotation.y = t * 0.85

			for em: Dictionary in kutbi_embers:
				var m: MeshInstance3D = em["node"]
				m.visible = true
				var a: float = float(em["ang"]) + float(em["spin"]) * t
				var y: float = fposmod(float(em["y0"]) + float(em["rise"]) * t, 3.2)
				m.global_position = kp + Vector3(cos(a) * float(em["rad"]), y, sin(a) * float(em["rad"]))
				m.scale = Vector3.ONE * (0.4 + 0.85 * sin(clampf(y / 3.2, 0.0, 1.0) * PI))

			if t >= 0.65 and _once("kutbi_wave"):
				(kutbi.get("visual") as Node).call("play_emote", &"emote_wave")
				for i: int in finale_crowd.size():
					(finale_crowd[i].get("visual") as Node).call("play_emote", &"emote_jump" if i % 2 == 0 else &"emote_dance")
			if t >= 2.10 and _once("kutbi_dance"):
				(kutbi.get("visual") as Node).call("play_emote", &"emote_dance")

			var c: Vector3 = kp + Vector3.UP * 0.70
			var orbit: float = lerpf(-0.38, 0.34, e)
			var dist_k: float = lerpf(4.3, 2.35, e)
			cam.fov = lerpf(56.0, 48.0, e)
			cam.global_position = c + Vector3(sin(orbit) * dist_k, lerpf(0.55, 0.08, k), cos(orbit) * dist_k)
			cam.look_at(c + Vector3.UP * 0.14)


# ==============================================================================
# Yardımcılar
# ==============================================================================

func _track_pose(dist: float, lane: float) -> Array:
	var acc: float = 0.0
	for i: int in RACE_CPS.size() - 1:
		var a: Vector3 = Vector3(float(RACE_CPS[i][0]), 0.0, float(RACE_CPS[i][1]))
		var b: Vector3 = Vector3(float(RACE_CPS[i + 1][0]), 0.0, float(RACE_CPS[i + 1][1]))
		var seg: float = a.distance_to(b)
		if dist <= acc + seg or i == RACE_CPS.size() - 2:
			var f: float = clampf((dist - acc) / seg, 0.0, 1.0)
			var d: Vector3 = (b - a).normalized()
			var p: Vector3 = a.lerp(b, f) + Vector3(d.z, 0.0, -d.x) * lane
			return [p, atan2(d.x, d.z)]
		acc += seg
	return [Vector3.ZERO, 0.0]


func _spawn(scene: PackedScene, pet: StringName, nick: String, acc: Dictionary, pos: Vector3, yaw: float) -> Node3D:
	var n: Node3D = scene.instantiate()
	current_scene.add_child(n)
	n.call("apply_profile", {"pet": str(pet), "name": nick, "acc": acc})
	n.global_position = _ground(pos)
	n.rotation.y = yaw
	n.set_process(false)
	n.visible = true
	return n


func _terrain_y(x: float, z: float) -> float:
	return float(_th.call("active_height", x, z)) if _th != null else 0.0


func _ground(p: Vector3) -> Vector3:
	var h: float = _terrain_y(p.x, p.z)
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(p.x, h + 1.5, p.z), Vector3(p.x, h - 6.0, p.z))
	var hit: Dictionary = current_scene.get_world_3d().direct_space_state.intersect_ray(q)
	return hit["position"] if not hit.is_empty() else Vector3(p.x, h, p.z)


func _bubble(rp: Node3D, text: String, dur: float) -> void:
	var b: Node = rp.get_node_or_null("ChatBubble")
	if b != null:
		b.call("show_message", text, dur)


func _make_glow_sphere(radius: float, col: Color, energy: float = 5.0, alpha: float = 1.0) -> MeshInstance3D:
	var m: MeshInstance3D = MeshInstance3D.new()
	var sp: SphereMesh = SphereMesh.new()
	sp.radius = radius
	sp.height = radius * 2.0
	sp.radial_segments = 12
	sp.rings = 6
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(col.r, col.g, col.b, alpha)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = energy
	sp.material = mat
	m.mesh = sp
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.visible = false
	current_scene.add_child(m)
	return m


func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _ease_out_back(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 1.0 + 2.70158 * pow(x - 1.0, 3.0) + 1.70158 * pow(x - 1.0, 2.0)
