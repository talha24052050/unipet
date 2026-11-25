extends SceneTree
## UniPet Tanıtım Filmi v3 — yeni ikonik içerik (Godot Movie Maker, 1080x1920, 30 fps, 31.5 sn).
## Kullanım:
##   godot_console --path game --write-movie <çıktı>.avi --fixed-fps 30 --resolution 1080x1920 -s <repo>/tools/ad/cinematic_v3.gd
## Kurgu ve yazılar: tools/ad/build_ad_v3.py (aynı SHOTS zamanları). Ekran 1920 yüksekliğe sığmazsa Godot kaydı
## 720x1280 alır; build_ad_v3.py lanczos ile 1080x1920'ye büyütür.
##
##   0. gate    (3.5) A Kapısı gerçek İETT durağı: Mavi Ring yanaşır, kapılar açılır, bekleyen petler zıplar
##   1. ride    (3.5) Kampüs içinde ilerleyen Ring'in yanından takip; camda petler
##   2. map     (2.5) Kampüs üstü yüksek drone (üstüne 2D Ring hattı + 11 gerçek durak haritası biner)
##   3. hamam   (4.0) Tarihi Hamam çökük avlusuna iniş: ARTLAB afişi, ESLAB minibüsü, Sami el sallar
##   4. social  (3.5) Hokka önünde buluşma: isimli petler, sohbet balonları (üstüne profil kartı biner)
##   5. cats    (3.0) Ortabahçe kedileri: petlerin etrafında dolaşan kediler + kalpler
##   6. race    (3.5) Stadyum pistinde koşu yarışı, alçak takip kamerası
##   7. dressup (3.0) Beat'e senkron pet + aksesuar değişimi
##   8. kutbi   (5.0) Gece Ortabahçe: ışık çemberinden efsanevi Kutbi + kapanış

const FPS: float = 30.0
const SHOTS: Array = [
	["gate", 3.5],
	["ride", 3.5],
	["map", 2.5],
	["hamam", 4.0],
	["social", 3.5],
	["cats", 3.0],
	["race", 3.5],
	["dressup", 3.0],
	["kutbi", 5.0],
]

const HAMAM_ORIGIN: Vector2 = Vector2(44.56, -161.98)
const HAMAM_U: Vector2 = Vector2(-0.630079, 0.776531)
const HAMAM_N: Vector2 = Vector2(-0.776519, -0.630094)
const HOKKA: Vector3 = Vector3(-66.0, 0.0, -112.0)
const CAT_SPOT: Vector3 = Vector3(6.0, 0.0, 14.0)
const COURTYARD: Vector3 = Vector3(12.0, 0.0, 20.0)
const DRESSUP_SPOT: Vector3 = Vector3(16.0, 0.0, 28.0)
const GATHER_CENTER: Vector3 = Vector3(-4.0, 0.0, 56.0)
const KUTBI_SPOT: Vector3 = Vector3(16.0, 0.0, 30.0)
const RACE_CPS: Array = [[-322.51, 39.14], [-313.11, 4.73], [-296.8, -26.1], [-263.06, -32.93], [-237.47, -9.91], [-239.09, 24.94], [-248.49, 59.35]]
const SEATS: Array[Vector3] = [Vector3(-0.68, 1.18, 1.65), Vector3(0.68, 1.18, 1.65), Vector3(-0.68, 1.18, 0.05), Vector3(0.68, 1.18, 0.05), Vector3(-0.68, 1.18, -1.55)]

const PETS: Array[StringName] = [&"mushnub", &"shark", &"chicken", &"ninja", &"birb", &"yeti"]
const NAMES: PackedStringArray = ["Zeynep", "Mert", "Ece", "Kaan", "Defne", "Arda", "Elif", "Can", "Ada", "Emir", "Nil", "Efe", "Su", "Deniz", "Bora", "Selin"]
const EMOTES: Array[StringName] = [&"emote_dance", &"emote_wave", &"emote_jump", &"emote_yes"]
const ACC_SETS: Array = [
	{"head": "hat_cap", "face": "glasses"}, {"neck": "scarf"}, {"head": "beanie"}, {"face": "sunglasses"},
	{"neck": "bowtie"}, {"back": "wings"}, {"back": "backpack", "head": "flower_crown"}, {"head": "crown_star", "back": "cape"},
]
const DRESSUP_LOOKS: Array = [
	{"pet": &"mushnub", "acc": {"head": "hat_cap", "face": "glasses"}},
	{"pet": &"shark", "acc": {"face": "sunglasses", "neck": "bowtie"}},
	{"pet": &"chicken", "acc": {"head": "flower_crown", "neck": "scarf"}},
	{"pet": &"ninja", "acc": {"back": "cape", "face": "glasses"}},
	{"pet": &"birb", "acc": {"back": "backpack", "head": "beanie"}},
	{"pet": &"yeti", "acc": {"head": "crown_star", "back": "wings"}},
]
const CONFETTI_COLORS: Array[Color] = [Color(1.0, 0.84, 0.22), Color(0.25, 0.78, 1.0), Color(1.0, 0.36, 0.56), Color(0.42, 0.95, 0.45), Color(0.82, 0.48, 1.0)]
const STAR_COLOR: Color = Color(1.0, 0.86, 0.42)
const HEART_COLOR: Color = Color(1.0, 0.38, 0.55)

var cam: Camera3D
var day_night: Node
var transit: Node
var frame: int = 0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _shot_started: Dictionary = {}

var gate_pets: Array[Node3D] = []
var riders: Array[Node3D] = []
var ride_bus: int = 0
var hamam_pets: Array[Node3D] = []
var social: Array[Node3D] = []
var bubbles_shown: Dictionary = {}
var cats: Array[Node3D] = []
var cat_pets: Array[Node3D] = []
var hearts: Array[Dictionary] = []
var racers: Array[Dictionary] = []
var dressup_pet: Node3D
var dressup_idx: int = -1
var dressup_burst_t: float = -10.0
var sparks: Array[Dictionary] = []
var crowd: Array[Node3D] = []
var kutbi: Node3D
var kutbi_light: OmniLight3D
var kutbi_ring: MeshInstance3D
var embers: Array[Dictionary] = []


func _initialize() -> void:
	rng.seed = 20261125
	await process_frame
	change_scene_to_file("res://scenes/main.tscn")
	for i: int in 30:
		await process_frame
	var s: Node = current_scene
	for cl: Node in s.find_children("*", "CanvasLayer", true, false):
		(cl as CanvasLayer).visible = false
	var player: Node3D = s.get_node("Player")
	player.visible = false
	player.process_mode = Node.PROCESS_MODE_DISABLED
	day_night = s.get_node("DayNight")
	day_night.set_process(false)
	day_night.call("apply", 14.5)
	var env: Environment = (s.get_node("Environment") as WorldEnvironment).environment
	env.glow_enabled = true
	env.glow_intensity = 1.25
	env.glow_bloom = 0.18
	env.glow_hdr_threshold = 0.9
	transit = s.get_node("CampusTransit")
	transit.set("use_wall_clock", false)

	cam = Camera3D.new()
	cam.far = 1200.0
	s.add_child(cam)
	cam.make_current()

	var RP: PackedScene = load("res://scenes/remote_player.tscn")
	_setup_gate(RP)
	_setup_riders(RP)
	_setup_hamam(RP)
	_setup_social(RP)
	_setup_cats(RP)
	_setup_race(RP)
	_setup_dressup(RP)
	_setup_finale(RP)
	for g: Node in s.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).visibility_range_end = 0.0
	for i: int in 20:
		await process_frame

	var total: float = 0.0
	for sh: Array in SHOTS:
		total += float(sh[1])
	while frame / FPS <= total:
		var t: float = frame / FPS
		var start: float = 0.0
		for j: int in SHOTS.size():
			var sh: Array = SHOTS[j]
			if t < start + float(sh[1]) or j == SHOTS.size() - 1:
				var nm: String = str(sh[0])
				if not _shot_started.has(nm):
					_shot_started[nm] = true
					_on_shot_start(nm)
				_shot(nm, t - start, float(sh[1]))
				break
			start += float(sh[1])
		await process_frame
		frame += 1
	quit()


# ------------------------------------------------------------------ kurulum

func _stop(i: int) -> Dictionary:
	return (transit.get("stops") as Array)[i]


func _bus(i: int) -> Dictionary:
	return (transit.get("_buses") as Array)[i]


func _hamam(s_m: float, y: float, d_m: float) -> Vector3:
	return Vector3(HAMAM_ORIGIN.x + HAMAM_U.x * s_m + HAMAM_N.x * d_m, y, HAMAM_ORIGIN.y + HAMAM_U.y * s_m + HAMAM_N.y * d_m)


func _setup_gate(RP: PackedScene) -> void:
	var st: Dictionary = _stop(0)
	var sp: Vector2 = st["shelter_pos"]
	var rp: Vector2 = st["road_pos"]
	var to_road: Vector2 = (rp - sp).normalized()
	var along: Vector2 = Vector2(-to_road.y, to_road.x)
	for i: int in 5:
		var p2: Vector2 = sp + to_road * 2.2 + along * (float(i) - 2.0) * 1.35
		gate_pets.append(_spawn(RP, PETS[i % PETS.size()], NAMES[i + 8], ACC_SETS[(i + 3) % ACC_SETS.size()], Vector3(p2.x, 0.0, p2.y), atan2(to_road.x, to_road.y)))


func _setup_riders(RP: PackedScene) -> void:
	for i: int in SEATS.size():
		var n: Node3D = _spawn(RP, PETS[(i + 2) % PETS.size()], "", ACC_SETS[i % ACC_SETS.size()], Vector3(0, -50, 0), 0.0)
		n.scale = Vector3.ONE * 0.85
		riders.append(n)


func _setup_hamam(RP: PackedScene) -> void:
	var spots: Array = [[17.0, 6.4], [22.5, 6.0], [9.5, 6.5], [26.0, 5.2]]
	for i: int in spots.size():
		var p: Vector3 = _hamam(float(spots[i][0]), 0.0, float(spots[i][1]))
		var n: Node3D = _spawn(RP, PETS[(i + 1) % PETS.size()], NAMES[i + 4], ACC_SETS[(i + 5) % ACC_SETS.size()], p, atan2(-HAMAM_N.x, -HAMAM_N.y))
		hamam_pets.append(n)


func _setup_social(RP: PackedScene) -> void:
	for i: int in 8:
		var a: float = TAU * float(i) / 8.0 + rng.randf_range(-0.12, 0.12)
		var r: float = rng.randf_range(2.4, 3.8)
		var p: Vector3 = HOKKA + Vector3(cos(a) * r, 0.0, sin(a) * r)
		social.append(_spawn(RP, PETS[i % PETS.size()], NAMES[i], ACC_SETS[i % ACC_SETS.size()], p, atan2(HOKKA.x - p.x, HOKKA.z - p.z)))


func _setup_cats(RP: PackedScene) -> void:
	var CampusCat: GDScript = load("res://src/world/campus_cat.gd")
	for i: int in 2:
		var p: Vector3 = CAT_SPOT + Vector3(-1.2 + 2.4 * float(i), 0.0, 0.0)
		cat_pets.append(_spawn(RP, [&"mushnub", &"chicken"][i], ["Zeynep", "Kaan"][i], ACC_SETS[i * 2], p, PI if i == 0 else 0.0))
	for i: int in 4:
		var c: Node3D = CampusCat.new()
		current_scene.add_child(c)
		# kameranın baktığı tarafa (açı ~2.75), petlerin önüne
		var lat: float = -1.8 + 1.2 * float(i)
		var home: Vector3 = _ground(CAT_SPOT + Vector3(sin(2.75) * 1.6 + cos(2.75) * lat, 0.0, cos(2.75) * 1.6 - sin(2.75) * lat))
		c.call("setup", 4049 * (i + 3), home, 0.8)
		cats.append(c)
	for i: int in 16:
		hearts.append({"node": _make_glow_sphere(rng.randf_range(0.07, 0.12), HEART_COLOR, 4.5, 0.95), "t0": rng.randf_range(0.2, 2.6), "x": rng.randf_range(-2.4, 2.4), "z": rng.randf_range(-1.6, 1.6)})


func _setup_race(RP: PackedScene) -> void:
	for i: int in 6:
		var n: Node3D = _spawn(RP, PETS[i % PETS.size()], NAMES[i + 2], ACC_SETS[(i + 1) % ACC_SETS.size()], Vector3(RACE_CPS[0][0], 0.0, RACE_CPS[0][1]), 0.0)
		racers.append({"node": n, "lane": (float(i) - 2.5) * 1.15, "speed": rng.randf_range(6.4, 7.6) + (0.55 if i == 2 else 0.0)})


func _setup_dressup(RP: PackedScene) -> void:
	dressup_pet = _spawn(RP, &"mushnub", "", {"head": "hat_cap"}, DRESSUP_SPOT, 0.0)
	for i: int in 22:
		var m: MeshInstance3D = _make_glow_sphere(rng.randf_range(0.04, 0.09), CONFETTI_COLORS[i % CONFETTI_COLORS.size()], 5.0)
		var dir: Vector3 = Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(0.2, 1.4), rng.randf_range(-1.0, 1.0)).normalized()
		sparks.append({"node": m, "vel": dir * rng.randf_range(2.2, 4.8)})


func _setup_finale(RP: PackedScene) -> void:
	for i: int in 12:
		var a: float = TAU * float(i) / 12.0 + rng.randf_range(-0.1, 0.1)
		var r: float = rng.randf_range(5.6, 8.0)
		var p: Vector3 = KUTBI_SPOT + Vector3(cos(a) * r, 0.0, sin(a) * r)
		crowd.append(_spawn(RP, PETS[i % PETS.size()], NAMES[i], ACC_SETS[i % ACC_SETS.size()], p, atan2(KUTBI_SPOT.x - p.x, KUTBI_SPOT.z - p.z)))
	kutbi = _spawn(RP, &"kutbi", "", {}, KUTBI_SPOT, 0.0)
	kutbi.visible = false
	kutbi_light = OmniLight3D.new()
	kutbi_light.light_color = STAR_COLOR
	kutbi_light.omni_range = 9.0
	kutbi_light.light_energy = 0.0
	current_scene.add_child(kutbi_light)
	kutbi_ring = MeshInstance3D.new()
	var tor: TorusMesh = TorusMesh.new()
	tor.inner_radius = 1.05
	tor.outer_radius = 1.18
	var km: StandardMaterial3D = StandardMaterial3D.new()
	km.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	km.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	km.albedo_color = Color(STAR_COLOR.r, STAR_COLOR.g, STAR_COLOR.b, 0.85)
	km.emission_enabled = true
	km.emission = STAR_COLOR
	km.emission_energy_multiplier = 5.5
	tor.material = km
	kutbi_ring.mesh = tor
	kutbi_ring.visible = false
	current_scene.add_child(kutbi_ring)
	for i: int in 48:
		embers.append({"node": _make_glow_sphere(rng.randf_range(0.025, 0.06), STAR_COLOR if i % 3 != 0 else Color(0.75, 0.88, 1.0), 5.5, 0.9),
			"ang": rng.randf_range(0.0, TAU), "rad": rng.randf_range(0.85, 2.8), "y0": rng.randf_range(-0.2, 2.4),
			"rise": rng.randf_range(0.35, 0.85), "spin": rng.randf_range(0.4, 1.2) * (1.0 if i % 2 == 0 else -1.0)})


# ------------------------------------------------------------------ çekimler

func _on_shot_start(nm: String) -> void:
	var period: float = float(transit.get("_period"))
	match nm:
		"gate":
			# Ring #1 (faz 0) A Kapısı'na ~2.2 sn sonra yanaşsın
			transit.set("_sim_time", period - 2.2)
		"ride":
			# Ring #1'in hareket hâlinde olduğu, İnşaat → Spor Kompleksi arası bir an
			var best: float = 0.0
			var t: float = 0.0
			while t < period:
				var smp: Dictionary = transit.call("_sample_timetable", t)
				var s0: float = float(smp["s"])
				var smp2: Dictionary = transit.call("_sample_timetable", t + 3.6)
				if s0 > 1250.0 and float(smp["dwell"]) <= 0.0 and float(smp2["dwell"]) <= 0.0 and float(smp2["s"]) > s0 + 20.0:
					best = t
					break
				t += 0.1
			transit.set("_sim_time", best)
			ride_bus = 0
		"map":
			for r: Node3D in riders:
				r.visible = false


func _shot(nm: String, t: float, dur: float) -> void:
	var k: float = clampf(t / dur, 0.0, 1.0)
	var e: float = _ease(k)
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.fov = 58.0
	match nm:
		"gate":
			day_night.call("apply", 9.5)
			var st: Dictionary = _stop(0)
			var sp: Vector2 = st["shelter_pos"]
			var rp: Vector2 = st["road_pos"]
			var to_road: Vector2 = (rp - sp).normalized()
			var along: Vector2 = Vector2(-to_road.y, to_road.x)
			# Kamera durağın yanında, bekleyen petlerin arkasından yanaşan Ring'e bakar
			var bus_p: Vector3 = (_bus(0)["node"] as Node3D).global_position
			var cam2: Vector2 = sp - to_road * lerpf(3.5, 2.5, e) + along * lerpf(7.0, 5.0, e)
			var cam_p: Vector3 = _ground(Vector3(cam2.x, 0.0, cam2.y)) + Vector3.UP * lerpf(2.4, 1.7, e)
			var stop_c: Vector3 = _ground(Vector3(rp.x, 0.0, rp.y)) + Vector3.UP * 1.2
			cam.fov = lerpf(64.0, 56.0, e)
			cam.global_position = cam_p
			cam.look_at(stop_c.lerp(bus_p + Vector3.UP * 1.4, 0.55 * (1.0 - e)))
			if absf(t - 2.4) < 0.5 / FPS:
				for i: int in gate_pets.size():
					(gate_pets[i].get("visual") as Node).call("play_emote", &"emote_jump" if i % 2 == 0 else &"emote_wave")
			if absf(t - 0.6) < 0.5 / FPS:
				_bubble(gate_pets[1], "Ring geliyor!", 2.6)

		"ride":
			day_night.call("apply", 11.0)
			var b: Dictionary = _bus(ride_bus)
			var nd: Node3D = b["node"]
			var xf: Transform3D = nd.global_transform
			for i: int in riders.size():
				riders[i].visible = true
				riders[i].global_position = xf * SEATS[i]
				riders[i].rotation.y = nd.rotation.y
			var side: Vector3 = xf.basis.x.normalized()
			var fwd: Vector3 = xf.basis.z.normalized()
			var c: Vector3 = nd.global_position + Vector3.UP * 1.7
			cam.fov = 60.0
			cam.global_position = c + side * lerpf(-12.5, -10.0, e) + fwd * lerpf(9.0, -3.0, e) + Vector3.UP * lerpf(3.2, 1.6, e)
			cam.look_at(c + fwd * 0.5)

		"map":
			day_night.call("apply", 12.5)
			cam.keep_aspect = Camera3D.KEEP_WIDTH
			cam.fov = 70.0
			var center: Vector3 = Vector3(220.0, 0.0, 80.0)
			cam.global_position = center + Vector3(lerpf(-60.0, 40.0, e), lerpf(520.0, 470.0, e), 260.0)
			cam.look_at(center + Vector3(0.0, 0.0, 30.0))

		"hamam":
			day_night.call("apply", 15.8)
			# Yüksekten çökük avlunun içine iniş: sonunda avlu zemininde (y=-2), afiş + Sami + petler + ESLAB kadrajda
			var look: Vector3 = _hamam(lerpf(26.7, 18.5, e), lerpf(2.5, -0.4, e), lerpf(0.6, 3.2, e))
			cam.fov = lerpf(64.0, 66.0, e)
			cam.global_position = _hamam(lerpf(30.0, 31.5, e), lerpf(16.0, -0.7, e), lerpf(42.0, 7.6, e))
			cam.look_at(look)
			if absf(t - 0.2) < 0.5 / FPS:
				for i: int in hamam_pets.size():
					(hamam_pets[i].get("visual") as Node).call("play_emote", EMOTES[i % EMOTES.size()])
			if absf(t - 1.6) < 0.5 / FPS:
				var sami: Node = current_scene.get_node_or_null("SamiNpc")
				if sami != null and sami.get("_bubble") != null:
					(sami.get("_bubble") as Node).call("show_message", "ARTLAB'a hoş geldin!", 3.0)
				_bubble(hamam_pets[0], "UniPet yakında!", 2.4)

		"social":
			day_night.call("apply", 17.2)
			if frame % 15 == 0:
				for i: int in social.size():
					if (i + frame / 15) % 3 == 0:
						(social[i].get("visual") as Node).call("play_emote", EMOTES[(i + frame) % EMOTES.size()])
			var lines: Array = [[0.15, 0, "Hokka'da buluşalım!"], [0.8, 3, "Arkadaş ekledim!"], [1.5, 5, "Ring 2 dk sonra"], [2.2, 6, "Kahve benden!"]]
			for li: Array in lines:
				var key: String = "s%d" % int(li[1])
				if t >= float(li[0]) and not bubbles_shown.has(key):
					bubbles_shown[key] = true
					_bubble(social[int(li[1])], str(li[2]), 3.0)
			var c: Vector3 = _ground(HOKKA) + Vector3.UP * 0.8
			var ang: float = lerpf(0.9, 0.2, e)
			var r: float = lerpf(5.5, 8.5, e)
			cam.fov = 58.0
			cam.global_position = c + Vector3(sin(ang) * r, lerpf(1.6, 3.6, e), cos(ang) * r)
			cam.look_at(c + Vector3.UP * 0.3)

		"cats":
			day_night.call("apply", 16.4)
			if frame % 30 == 0:
				for ct: Node3D in cats:
					ct.call("pet")
			if absf(t - 0.4) < 0.5 / FPS:
				(cat_pets[0].get("visual") as Node).call("play_emote", &"emote_wave")
			if absf(t - 1.3) < 0.5 / FPS:
				(cat_pets[1].get("visual") as Node).call("play_emote", &"emote_jump")
				_bubble(cat_pets[1], "Miyav!", 1.8)
			var base: Vector3 = _ground(CAT_SPOT)
			for h: Dictionary in hearts:
				var m: MeshInstance3D = h["node"]
				var ht: float = t - float(h["t0"])
				m.visible = ht > 0.0 and ht < 1.4
				if m.visible:
					m.global_position = base + Vector3(float(h["x"]) + sin(ht * 5.0) * 0.12, 0.6 + ht * 1.1, float(h["z"]))
					m.scale = Vector3.ONE * sin(clampf(ht / 1.4, 0.0, 1.0) * PI)
			var c: Vector3 = base + Vector3.UP * 0.4
			var ang: float = lerpf(2.4, 3.1, e)
			var r: float = lerpf(5.0, 4.0, e)
			cam.fov = 56.0
			cam.global_position = c + Vector3(sin(ang) * r, lerpf(1.8, 1.1, e), cos(ang) * r)
			cam.look_at(c)

		"race":
			for h: Dictionary in hearts:
				(h["node"] as MeshInstance3D).visible = false
			day_night.call("apply", 17.6)
			var lead: Vector3 = Vector3.ZERO
			var lead_d: float = -1.0
			for rc: Dictionary in racers:
				var dist: float = 4.0 + float(rc["speed"]) * t
				var pose: Array = _track_pose(dist, float(rc["lane"]))
				var n: Node3D = rc["node"]
				n.global_position = _ground(pose[0])
				n.rotation.y = float(pose[1])
				if t < 0.05:
					(n.get("visual") as Node).call("set_locomotion", 6.5)
				if dist > lead_d:
					lead_d = dist
					lead = n.global_position
			var lp: Array = _track_pose(lead_d - 1.5, 0.0)
			var dir: float = float(lp[1])
			var fwd: Vector3 = Vector3(sin(dir), 0.0, cos(dir))
			var right: Vector3 = Vector3(fwd.z, 0.0, -fwd.x)
			cam.fov = lerpf(60.0, 54.0, e)
			cam.global_position = lead + fwd * lerpf(6.0, 3.5, e) + right * lerpf(5.5, 4.0, e) + Vector3.UP * lerpf(1.2, 0.8, e)
			cam.look_at(lead + Vector3.UP * 0.5 - fwd * 2.0)

		"dressup":
			day_night.call("apply", 17.3)
			var step_idx: int = mini(int(t / 0.5), DRESSUP_LOOKS.size() - 1)
			if step_idx != dressup_idx:
				dressup_idx = step_idx
				dressup_burst_t = t
				var look: Dictionary = DRESSUP_LOOKS[dressup_idx]
				dressup_pet.call("apply_profile", {"pet": str(look["pet"]), "name": "", "acc": look["acc"]})
				(dressup_pet.get("visual") as Node).call("play_emote", &"emote_dance" if dressup_idx == DRESSUP_LOOKS.size() - 1 else (&"emote_jump" if dressup_idx % 2 == 0 else &"emote_wave"))
			var dt_pop: float = t - dressup_burst_t
			dressup_pet.scale = Vector3.ONE * lerpf(0.65, 1.0, _ease_out_back(dt_pop / 0.24))
			dressup_pet.rotation.y = lerpf(-0.4, 0.4, sin(t * 2.1) * 0.5 + 0.5)
			var origin: Vector3 = dressup_pet.global_position + Vector3.UP * 0.75
			for sp: Dictionary in sparks:
				var m: MeshInstance3D = sp["node"]
				m.visible = dt_pop < 0.46
				if m.visible:
					m.global_position = origin + (sp["vel"] as Vector3) * dt_pop + Vector3.DOWN * 3.8 * dt_pop * dt_pop
					m.scale = Vector3.ONE * clampf(1.0 - dt_pop / 0.46, 0.0, 1.0)
			var c: Vector3 = dressup_pet.global_position + Vector3.UP * 0.65
			var orbit: float = lerpf(-0.6, 0.7, e)
			var dist: float = lerpf(3.3, 2.55, e)
			cam.fov = 52.0
			cam.global_position = c + Vector3(sin(orbit) * dist, lerpf(0.7, 0.35, k), cos(orbit) * dist)
			cam.look_at(c + Vector3.UP * 0.08)

		"kutbi":
			for sp: Dictionary in sparks:
				(sp["node"] as MeshInstance3D).visible = false
			dressup_pet.visible = false
			day_night.call("apply", 21.8)
			kutbi.visible = true
			var kp: Vector3 = kutbi.global_position
			var grow: float = _ease_out_back(clampf(t / 0.85, 0.0, 1.0))
			kutbi.scale = Vector3.ONE * lerpf(0.05, 1.08, grow)
			kutbi_light.global_position = kp + Vector3(0.4, 1.2, 1.6)
			kutbi_light.light_energy = lerpf(5.0, 1.6, clampf(t / 1.0, 0.0, 1.0))
			kutbi_ring.visible = true
			kutbi_ring.global_position = kp + Vector3.UP * 0.08
			var pulse: float = 1.0 + sin(t * 3.5) * 0.06
			kutbi_ring.scale = Vector3(pulse * grow, 1.0, pulse * grow)
			kutbi_ring.rotation.y = t * 0.8
			for em: Dictionary in embers:
				var m: MeshInstance3D = em["node"]
				m.visible = true
				var a: float = float(em["ang"]) + float(em["spin"]) * t
				var y: float = fposmod(float(em["y0"]) + float(em["rise"]) * t, 3.2)
				m.global_position = kp + Vector3(cos(a) * float(em["rad"]), y, sin(a) * float(em["rad"]))
				m.scale = Vector3.ONE * (0.4 + 0.8 * sin(clampf(y / 3.2, 0.0, 1.0) * PI))
			if absf(t - 0.75) < 0.5 / FPS:
				(kutbi.get("visual") as Node).call("play_emote", &"emote_wave")
				for i: int in crowd.size():
					(crowd[i].get("visual") as Node).call("play_emote", &"emote_jump" if i % 2 == 0 else &"emote_dance")
			if absf(t - 2.35) < 0.5 / FPS:
				(kutbi.get("visual") as Node).call("play_emote", &"emote_dance")
			var c: Vector3 = kp + Vector3.UP * 0.7
			var orbit: float = lerpf(-0.42, 0.36, e)
			var dist: float = lerpf(5.2, 2.4, e)
			cam.fov = lerpf(58.0, 48.0, e)
			cam.global_position = c + Vector3(sin(orbit) * dist, lerpf(0.9, 0.1, k), cos(orbit) * dist)
			cam.look_at(c + Vector3.UP * 0.14)


## Pist üzerinde mesafe → [konum, yaw]; lane: şerit kayması (m).
func _track_pose(dist: float, lane: float) -> Array:
	var acc: float = 0.0
	for i: int in RACE_CPS.size() - 1:
		var a: Vector3 = Vector3(RACE_CPS[i][0], 0.0, RACE_CPS[i][1])
		var b: Vector3 = Vector3(RACE_CPS[i + 1][0], 0.0, RACE_CPS[i + 1][1])
		var seg: float = a.distance_to(b)
		if dist <= acc + seg or i == RACE_CPS.size() - 2:
			var f: float = clampf((dist - acc) / seg, 0.0, 1.0)
			var d: Vector3 = (b - a).normalized()
			var p: Vector3 = a.lerp(b, f) + Vector3(d.z, 0.0, -d.x) * lane
			return [p, atan2(d.x, d.z)]
		acc += seg
	return [Vector3.ZERO, 0.0]


# ------------------------------------------------------------------ yardımcılar

func _spawn(scene: PackedScene, pet: StringName, nick: String, acc: Dictionary, pos: Vector3, yaw: float) -> Node3D:
	var n: Node3D = scene.instantiate()
	current_scene.add_child(n)
	n.call("apply_profile", {"pet": str(pet), "name": nick, "acc": acc})
	n.global_position = _ground(pos)
	n.rotation.y = yaw
	n.set_process(false)
	n.visible = true  # uzak oyuncu ilk ağ durumunu beklerken gizli başlar
	return n


## Zemin: arazi yüksekliğinin biraz üstünden aşağı ışın (ağaç taçlarına / çatılara takılmasın; Hamam çukurunu bulur).
func _ground(p: Vector3) -> Vector3:
	var h: float = TerrainHeight.active_height(p.x, p.z)
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(p.x, h + 1.2, p.z), Vector3(p.x, h - 6.0, p.z))
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
