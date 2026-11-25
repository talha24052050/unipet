extends SceneTree
## UniPet Tanıtım Filmi v2 — Sinematik oyun içi 3D çekim (Godot Movie Maker, 1080x1920, 30 fps).
## Kullanım:
##   godot_console --path game --write-movie <çıktı>.avi --fixed-fps 30 --resolution 1080x1920 -s <repo>/tools/ad/cinematic_v2.gd
##
## Çekimler (SHOTS; build_ad_v2.py aynı zamanları kullanır — toplam 26.5 sn):
##   0. queue    (3.0 sn) Yemekhane önü canlı pet kuyruğu + konuşma balonları + üzgün maskot
##   1. drone    (3.5 sn) Tarihi Kışla + Ortabahçe geniş açılı dalış + aşağıda koşan petler
##   2. dressup  (4.0 sn) Beat'e senkron (0.5 sn'de bir) pet & aksesuar değişimi + 3D parıltı patlaması
##   3. study    (3.5 sn) Kütüphane önü kitap kuleleri → konfeti + kitap savrulması + dans
##   4. gather   (4.0 sn) Ortabahçe altın saatten geceye geçiş + canlı sohbet balonları + sokak lambaları
##   5. star     (3.5 sn) Gece kayan yıldız + parlayan kuyruk + şok dalgası halkası + kıvılcımlar
##   6. kutbi    (5.0 sn) Işık çemberi + yükselen yıldız tozu içinden Kutbi'nin görkemli çıkışı & dansı

const FPS: float = 30.0
const SHOTS: Array = [
	["queue", 3.0],
	["drone", 3.5],
	["dressup", 4.0],
	["study", 3.5],
	["gather", 4.0],
	["star", 3.5],
	["kutbi", 5.0],
]

const YEMEKHANE_DOOR: Vector3 = Vector3(-72.0, 0.0, -82.0)
const QUEUE_DIR: Vector3 = Vector3(0.548, 0.0, -0.837)
const QUEUE_LEN: int = 12
const QUEUE_GAP: float = 1.55

const COURTYARD: Vector3 = Vector3(12.0, 0.0, 20.0)
const DRESSUP_SPOT: Vector3 = Vector3(16.0, 0.0, 28.0)
const STUDY_SPOT: Vector3 = Vector3(404.0, 0.0, 438.0)
const GATHER_CENTER: Vector3 = Vector3(-4.0, 0.0, 56.0)
const KUTBI_SPOT: Vector3 = Vector3(16.0, 0.0, 30.0)

const PETS: Array[StringName] = [&"mushnub", &"shark", &"chicken", &"ninja", &"birb", &"yeti"]
const NAMES: PackedStringArray = [
	"Zeynep", "Mert", "Ece", "Kaan", "Defne", "Arda", "Elif", "Can",
	"Ada", "Emir", "Nil", "Efe", "Su", "Deniz", "Bora", "Selin",
]
const EMOTES: Array[StringName] = [&"emote_dance", &"emote_wave", &"emote_jump", &"emote_yes"]
const ACC_SETS: Array = [
	{"head": "hat_cap", "face": "glasses"},
	{"neck": "scarf"},
	{"head": "beanie"},
	{"face": "sunglasses"},
	{"neck": "bowtie"},
	{"back": "wings"},
	{"back": "backpack", "head": "hat_cap"},
	{"face": "sunglasses", "back": "wings"},
]
const DRESSUP_LOOKS: Array = [
	{"pet": &"mushnub", "acc": {"head": "hat_cap", "face": "glasses"}},
	{"pet": &"shark", "acc": {"face": "sunglasses", "neck": "bowtie"}},
	{"pet": &"chicken", "acc": {"head": "beanie", "neck": "scarf"}},
	{"pet": &"ninja", "acc": {"back": "wings", "face": "glasses"}},
	{"pet": &"birb", "acc": {"back": "backpack", "head": "hat_cap"}},
	{"pet": &"yeti", "acc": {"neck": "scarf", "face": "sunglasses"}},
	{"pet": &"mushnub", "acc": {"head": "hat_cap", "face": "glasses", "back": "wings"}},
]
const BOOK_COLORS: Array[Color] = [
	Color(0.84, 0.22, 0.24), Color(0.18, 0.46, 0.82), Color(0.96, 0.74, 0.18),
	Color(0.22, 0.66, 0.38), Color(0.58, 0.30, 0.74), Color(0.94, 0.93, 0.88),
]
const CONFETTI_COLORS: Array[Color] = [
	Color(1.0, 0.84, 0.22), Color(0.25, 0.78, 1.0), Color(1.0, 0.36, 0.56),
	Color(0.42, 0.95, 0.45), Color(0.82, 0.48, 1.0),
]

const STAR_COLOR: Color = Color(1.0, 0.86, 0.42)
const STAR_CORE_COLOR: Color = Color(1.0, 0.98, 0.86)
const STAR_TRAIL: int = 36
const SPARK_COUNT: int = 44
const EMBER_COUNT: int = 56
const BURST_SPARK_COUNT: int = 24

var cam: Camera3D
var day_night: Node
var env: Environment
var frame: int = 0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Shot actors
var queue_pets: Array[Node3D] = []
var runners: Array[Dictionary] = []
var dressup_pet: Node3D
var dressup_idx: int = -1
var dressup_burst_t: float = -10.0
var dressup_sparks: Array[Dictionary] = []

var student: Node3D
var books: Array[MeshInstance3D] = []
var book_rest: Array[Transform3D] = []
var book_vel: Array[Vector3] = []
var book_spin: Array[Vector3] = []
var study_confetti: Array[Dictionary] = []

var crowd: Array[Node3D] = []
var crowd_bubbles_shown: Dictionary = {}

# Shooting star & impact
var star_parts: Array[MeshInstance3D] = []
var star_hist: Array[Vector3] = []
var flash_core: MeshInstance3D
var shock_ring: MeshInstance3D
var flash_light: OmniLight3D
var impact_sparks: Array[Dictionary] = []

# Kutbi finale
var kutbi: Node3D
var kutbi_light: OmniLight3D
var kutbi_rim: OmniLight3D
var kutbi_ring: MeshInstance3D
var kutbi_embers: Array[Dictionary] = []


func _initialize() -> void:
	rng.seed = 20261123
	await process_frame
	root.get_node("Services").set("pending_teleport", Vector2(GATHER_CENTER.x, GATHER_CENTER.z - 10.0))
	change_scene_to_file("res://scenes/main.tscn")
	for i: int in 30:
		await process_frame
	var s: Node = current_scene
	s.get_node("UI").visible = false
	var player: Node3D = s.get_node("Player")
	player.visible = false
	player.process_mode = Node.PROCESS_MODE_DISABLED

	day_night = s.get_node("DayNight")
	day_night.set_process(false)
	day_night.call("apply", 14.5)

	env = (s.get_node("Environment") as WorldEnvironment).environment
	env.glow_enabled = true
	env.glow_intensity = 1.35
	env.glow_bloom = 0.22
	env.glow_hdr_threshold = 0.85

	cam = Camera3D.new()
	cam.far = 950.0
	s.add_child(cam)
	cam.make_current()

	var RP: PackedScene = load("res://scenes/remote_player.tscn")
	_setup_queue(RP)
	_setup_runners(RP)
	_setup_dressup(RP)
	_setup_study(RP)
	_setup_gather(RP)
	_setup_star()
	_setup_kutbi(RP)

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
				_shot(str(sh[0]), t - start, float(sh[1]))
				break
			start += float(sh[1])
		await process_frame
		frame += 1
	quit()


func _setup_queue(RP: PackedScene) -> void:
	for i: int in QUEUE_LEN:
		var p: Vector3 = YEMEKHANE_DOOR + QUEUE_DIR * (i * QUEUE_GAP) + Vector3(rng.randf_range(-0.22, 0.22), 0.0, rng.randf_range(-0.18, 0.18))
		var yaw: float = atan2(-QUEUE_DIR.x, -QUEUE_DIR.z) + rng.randf_range(-0.15, 0.15)
		var last: bool = i == QUEUE_LEN - 1
		var pet_id: StringName = &"mushnub" if last else PETS[(i + 1) % PETS.size()]
		var acc: Dictionary = {"head": "hat_cap", "face": "glasses"} if last else ACC_SETS[i % ACC_SETS.size()]
		queue_pets.append(_spawn(RP, pet_id, "", acc, p, yaw))


func _setup_runners(RP: PackedScene) -> void:
	# Ortabahçe'de koşturan canlı petler (drone dalışında kampüs canlı görünsün)
	for i: int in 10:
		var angle: float = TAU * float(i) / 10.0
		var rad: float = rng.randf_range(8.0, 26.0)
		var center: Vector3 = COURTYARD + Vector3(rng.randf_range(-14.0, 14.0), 0.0, rng.randf_range(-14.0, 14.0))
		var p: Vector3 = center + Vector3(cos(angle) * rad, 0.0, sin(angle) * rad)
		var node: Node3D = _spawn(RP, PETS[i % PETS.size()], "", ACC_SETS[i % ACC_SETS.size()], p, angle + PI * 0.5)
		(node.get("visual") as Node).call("set_locomotion", 5.5)
		runners.append({"node": node, "center": center, "rad": rad, "angle": angle, "speed": rng.randf_range(0.32, 0.55) * (1.0 if i % 2 == 0 else -1.0)})


func _setup_dressup(RP: PackedScene) -> void:
	dressup_pet = _spawn(RP, &"mushnub", "", {"head": "hat_cap", "face": "glasses"}, DRESSUP_SPOT, 0.0)
	for i: int in BURST_SPARK_COUNT:
		var m: MeshInstance3D = _make_glow_sphere(rng.randf_range(0.04, 0.09), CONFETTI_COLORS[i % CONFETTI_COLORS.size()], 5.0)
		var dir: Vector3 = Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(0.2, 1.4), rng.randf_range(-1.0, 1.0)).normalized()
		dressup_sparks.append({"node": m, "vel": dir * rng.randf_range(2.2, 4.8)})


func _setup_study(RP: PackedScene) -> void:
	student = _spawn(RP, &"mushnub", "", {"face": "glasses"}, STUDY_SPOT, PI)
	# 3 kitap kulesi (sağ, sol, hafif arka-yan) — daha zengin kompozisyon
	var stacks: Array = [Vector3(-0.78, 0.0, 0.06), Vector3(0.78, 0.0, 0.06), Vector3(-0.55, 0.0, 0.62)]
	for s_idx: int in stacks.size():
		var off: Vector3 = stacks[s_idx]
		var count: int = 12 if s_idx < 2 else 9
		var h: float = 0.0
		for i: int in count:
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
			var base: Vector3 = student.global_position + off + Vector3(rng.randf_range(-0.03, 0.03), h + th * 0.5, rng.randf_range(-0.03, 0.03))
			bm.global_transform = Transform3D(Basis(Vector3.UP, rng.randf_range(-0.28, 0.28)), base)
			h += th
			books.append(bm)
			book_rest.append(bm.global_transform)
			var side: float = -1.0 if off.x < 0.0 else 1.0
			book_vel.append(Vector3(side * rng.randf_range(2.0, 4.4), rng.randf_range(3.6, 6.4), rng.randf_range(-2.2, 2.2)))
			book_spin.append(Vector3(rng.randf_range(-8.0, 8.0), rng.randf_range(-8.0, 8.0), rng.randf_range(-8.0, 8.0)))

	for i: int in 28:
		var m: MeshInstance3D = _make_glow_sphere(rng.randf_range(0.04, 0.08), CONFETTI_COLORS[i % CONFETTI_COLORS.size()], 4.0)
		var dir: Vector3 = Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(0.4, 1.5), rng.randf_range(-1.0, 1.0)).normalized()
		study_confetti.append({"node": m, "vel": dir * rng.randf_range(2.5, 5.8)})


func _setup_gather(RP: PackedScene) -> void:
	for i: int in NAMES.size():
		var ring: int = 0 if i < 8 else 1
		var idx_in_ring: int = i if ring == 0 else i - 8
		var total_in_ring: int = 8
		var a: float = TAU * float(idx_in_ring) / float(total_in_ring) + (0.35 if ring == 1 else 0.0) + rng.randf_range(-0.15, 0.15)
		var r: float = rng.randf_range(2.8, 4.8) if ring == 0 else rng.randf_range(5.6, 8.8)
		var p: Vector3 = GATHER_CENTER + Vector3(cos(a) * r, 0.0, sin(a) * r)
		crowd.append(_spawn(RP, PETS[i % PETS.size()], NAMES[i], ACC_SETS[i % ACC_SETS.size()], p, atan2(GATHER_CENTER.x - p.x, GATHER_CENTER.z - p.z)))


func _setup_star() -> void:
	for i: int in STAR_TRAIL:
		var k: float = 1.0 - float(i) / float(STAR_TRAIL)
		var col: Color = STAR_COLOR.lerp(STAR_CORE_COLOR, pow(k, 3.0))
		star_parts.append(_make_glow_sphere(lerpf(0.35, 3.4, k * k), col, lerpf(3.0, 10.0, k), clampf(k, 0.12, 1.0)))

	flash_core = _make_glow_sphere(1.0, STAR_CORE_COLOR, 10.0, 0.95)

	# Şok dalgası halkası (torus)
	shock_ring = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.82
	torus.outer_radius = 1.0
	torus.rings = 32
	torus.ring_segments = 12
	var rmat: StandardMaterial3D = StandardMaterial3D.new()
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmat.albedo_color = Color(STAR_COLOR.r, STAR_COLOR.g, STAR_COLOR.b, 0.9)
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

	for i: int in SPARK_COUNT:
		var m: MeshInstance3D = _make_glow_sphere(rng.randf_range(0.35, 0.85), STAR_COLOR.lerp(STAR_CORE_COLOR, rng.randf()), 7.0, 0.95)
		var ang: float = rng.randf_range(0.0, TAU)
		var spd: float = rng.randf_range(12.0, 36.0)
		impact_sparks.append({"node": m, "vel": Vector3(cos(ang) * spd, rng.randf_range(10.0, 30.0), sin(ang) * spd)})


func _setup_kutbi(RP: PackedScene) -> void:
	kutbi = _spawn(RP, &"kutbi", "", {}, KUTBI_SPOT, 0.0)
	kutbi.visible = false

	kutbi_light = OmniLight3D.new()
	kutbi_light.light_color = STAR_COLOR
	kutbi_light.omni_range = 8.0
	kutbi_light.light_energy = 0.0
	current_scene.add_child(kutbi_light)

	kutbi_rim = OmniLight3D.new()
	kutbi_rim.light_color = Color(0.55, 0.72, 1.0)
	kutbi_rim.omni_range = 7.0
	kutbi_rim.light_energy = 0.0
	current_scene.add_child(kutbi_rim)

	# Altın ışık çemberi (Kutbi'nin altında parlayan pedestal halkası)
	kutbi_ring = MeshInstance3D.new()
	var ring_mesh: TorusMesh = TorusMesh.new()
	ring_mesh.inner_radius = 1.05
	ring_mesh.outer_radius = 1.18
	ring_mesh.rings = 40
	ring_mesh.ring_segments = 10
	var kmat: StandardMaterial3D = StandardMaterial3D.new()
	kmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	kmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	kmat.albedo_color = Color(STAR_COLOR.r, STAR_COLOR.g, STAR_COLOR.b, 0.85)
	kmat.emission_enabled = true
	kmat.emission = STAR_COLOR
	kmat.emission_energy_multiplier = 5.5
	ring_mesh.material = kmat
	kutbi_ring.mesh = ring_mesh
	kutbi_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	kutbi_ring.visible = false
	current_scene.add_child(kutbi_ring)

	# Yükselen yıldız tozu tanecikleri
	for i: int in EMBER_COUNT:
		var col: Color = STAR_COLOR if i % 3 != 0 else Color(0.75, 0.88, 1.0)
		var m: MeshInstance3D = _make_glow_sphere(rng.randf_range(0.025, 0.06), col, 5.5, 0.9)
		kutbi_embers.append({
			"node": m,
			"ang": rng.randf_range(0.0, TAU),
			"rad": rng.randf_range(0.85, 2.8),
			"y0": rng.randf_range(-0.2, 2.4),
			"rise": rng.randf_range(0.35, 0.85),
			"spin": rng.randf_range(0.4, 1.2) * (1.0 if i % 2 == 0 else -1.0),
		})


func _spawn(scene: PackedScene, pet: StringName, nick: String, acc: Dictionary, pos: Vector3, yaw: float) -> Node3D:
	var n: Node3D = scene.instantiate()
	current_scene.add_child(n)
	n.call("apply_profile", {"pet": str(pet), "name": nick, "acc": acc})
	n.global_position = _ground(pos)
	n.rotation.y = yaw
	n.set_process(false)
	return n


func _ground(p: Vector3) -> Vector3:
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(p + Vector3.UP * 50.0, p + Vector3.DOWN * 10.0)
	var hit: Dictionary = current_scene.get_world_3d().direct_space_state.intersect_ray(q)
	return hit["position"] if not hit.is_empty() else p


func _make_glow_sphere(radius: float, col: Color, energy: float = 5.0, alpha: float = 1.0) -> MeshInstance3D:
	var m: MeshInstance3D = MeshInstance3D.new()
	var sp: SphereMesh = SphereMesh.new()
	sp.radius = radius
	sp.height = radius * 2.0
	sp.radial_segments = 14
	sp.rings = 8
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


func _show_bubble(rp: Node3D, text: String, dur: float = 3.0) -> void:
	var b: Node = rp.get_node_or_null("ChatBubble")
	if b != null:
		b.call("show_message", text, dur)


func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _ease_out_back(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	var c1: float = 1.70158
	var c3: float = c1 + 1.0
	return 1.0 + c3 * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)


func _shot(shot_name: String, t: float, dur: float) -> void:
	var k: float = clampf(t / dur, 0.0, 1.0)
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.fov = 58.0

	match shot_name:
		"queue":
			day_night.call("apply", 14.8)
			var back: Vector3 = queue_pets[QUEUE_LEN - 1].global_position
			var front: Vector3 = queue_pets[0].global_position
			var side: Vector3 = Vector3(-QUEUE_DIR.z, 0.0, QUEUE_DIR.x)
			var e: float = _ease(k)
			cam.fov = lerpf(64.0, 50.0, e)
			cam.global_position = back + QUEUE_DIR * lerpf(9.5, 2.4, e) + side * lerpf(2.8, 1.05, e) + Vector3.UP * lerpf(4.2, 1.15, e)
			cam.look_at(front.lerp(back, lerpf(0.25, 0.96, e)) + Vector3.UP * 0.65)
			if absf(t - 0.5) < 0.5 / FPS:
				_show_bubble(queue_pets[QUEUE_LEN - 4], "Sıra hiç ilerlemiyor...", 2.5)
				(queue_pets[QUEUE_LEN - 4].get("visual") as Node).call("play_emote", &"emote_jump")
			if absf(t - 1.85) < 0.5 / FPS:
				(queue_pets[QUEUE_LEN - 1].get("visual") as Node).call("play_emote", &"emote_no")

		"drone":
			day_night.call("apply", 16.4)
			# Koşan petleri hareket ettir
			for r_info: Dictionary in runners:
				r_info["angle"] = float(r_info["angle"]) + float(r_info["speed"]) / FPS
				var ang: float = float(r_info["angle"])
				var rad: float = float(r_info["rad"])
				var center: Vector3 = r_info["center"]
				var np: Vector3 = _ground(center + Vector3(cos(ang) * rad, 0.0, sin(ang) * rad))
				var n: Node3D = r_info["node"]
				var prev: Vector3 = n.global_position
				n.global_position = np
				var dv: Vector3 = np - prev
				if dv.length_squared() > 0.0001:
					n.rotation.y = atan2(dv.x, dv.z)
			var e: float = _ease(k)
			cam.keep_aspect = Camera3D.KEEP_WIDTH
			cam.fov = lerpf(80.0, 66.0, e)
			var cam_ang: float = lerpf(deg_to_rad(-18.0), deg_to_rad(-88.0), e)
			var cam_r: float = lerpf(255.0, 95.0, e)
			cam.global_position = COURTYARD + Vector3(sin(cam_ang) * cam_r, lerpf(210.0, 52.0, e), -cos(cam_ang) * cam_r)
			cam.look_at(COURTYARD + Vector3(0.0, lerpf(4.0, 2.0, e), lerpf(24.0, 10.0, e)))

		"dressup":
			day_night.call("apply", 17.3)  # Sıcak altın saat!
			# Her 0.5 sn'de (beat'te) yeni pet & aksesuar!
			var step_idx: int = mini(int(t / 0.5), DRESSUP_LOOKS.size() - 1)
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
			var pop_s: float = lerpf(0.65, 1.0, _ease_out_back(dt_pop / 0.24))
			dressup_pet.scale = Vector3.ONE * pop_s
			dressup_pet.rotation.y = lerpf(-0.4, 0.4, sin(t * 2.1) * 0.5 + 0.5)

			# Parıltı patlaması
			var origin: Vector3 = dressup_pet.global_position + Vector3.UP * 0.75
			for sp: Dictionary in dressup_sparks:
				var m: MeshInstance3D = sp["node"]
				if dt_pop < 0.46:
					m.visible = true
					var v: Vector3 = sp["vel"]
					m.global_position = origin + v * dt_pop + Vector3.DOWN * 3.8 * dt_pop * dt_pop
					var sc: float = clampf(1.0 - dt_pop / 0.46, 0.0, 1.0)
					m.scale = Vector3.ONE * sc
				else:
					m.visible = false

			var c: Vector3 = dressup_pet.global_position + Vector3.UP * 0.65
			var orbit: float = lerpf(-0.65, 0.75, _ease(k))
			var dist: float = lerpf(3.4, 2.55, _ease(k))
			cam.fov = 52.0
			cam.global_position = c + Vector3(sin(orbit) * dist, lerpf(0.7, 0.35, k), cos(orbit) * dist)
			cam.look_at(c + Vector3.UP * 0.08)

		"study":
			day_night.call("apply", 17.5)
			for sp: Dictionary in dressup_sparks:
				(sp["node"] as MeshInstance3D).visible = false
			var st: Vector3 = student.global_position
			if absf(t - 0.1) < 0.5 / FPS:
				(student.get("visual") as Node).call("play_emote", &"emote_no")
			var burst: float = 1.5
			if absf(t - burst) < 0.5 / FPS:
				(student.get("visual") as Node).call("play_emote", &"emote_dance")

			# Kitaplar yerçekimi + zıplama ile savrulur
			for i: int in books.size():
				var dt: float = t - burst - float(i % 10) * 0.015
				if dt <= 0.0:
					books[i].global_transform = book_rest[i]
				else:
					var p0: Vector3 = book_rest[i].origin
					var v: Vector3 = book_vel[i]
					var p: Vector3 = p0 + v * dt + Vector3.DOWN * 5.8 * dt * dt
					var floor_y: float = st.y + 0.05
					if p.y < floor_y:
						# Hafif sekme
						var over: float = floor_y - p.y
						p.y = floor_y + maxf(0.0, over * 0.25 - over * over * 0.08)
					var rot_v: Vector3 = book_spin[i]
					var b: Basis = book_rest[i].basis
					if p.y > floor_y + 0.02:
						b = b.rotated(Vector3.RIGHT, rot_v.x * dt).rotated(Vector3.UP, rot_v.y * dt).rotated(Vector3.FORWARD, rot_v.z * dt)
					books[i].global_transform = Transform3D(b, p)

			# Konfeti parıltısı
			var c_dt: float = t - burst
			for cf: Dictionary in study_confetti:
				var m: MeshInstance3D = cf["node"]
				if c_dt > 0.0 and c_dt < 1.6:
					m.visible = true
					var v: Vector3 = cf["vel"]
					m.global_position = st + Vector3.UP * 0.8 + v * c_dt + Vector3.DOWN * 3.2 * c_dt * c_dt
					m.scale = Vector3.ONE * clampf(1.0 - c_dt / 1.6, 0.0, 1.0)
				else:
					m.visible = false

			# Patlama anında hafif kamera sarsıntısı (punch)
			var shake: Vector3 = Vector3.ZERO
			if c_dt > 0.0 and c_dt < 0.25:
				var amp: float = (1.0 - c_dt / 0.25) * 0.12
				shake = Vector3(sin(t * 75.0) * amp, cos(t * 62.0) * amp, 0.0)

			var c: Vector3 = st + Vector3.UP * 0.7
			cam.fov = lerpf(56.0, 62.0, _ease(clampf((t - burst) / 0.8, 0.0, 1.0)))
			cam.global_position = c + Vector3(lerpf(0.7, -0.55, k), lerpf(0.85, 1.35, k), lerpf(-3.2, -4.5, _ease(k))) + shake
			cam.look_at(c + Vector3.UP * lerpf(0.05, 0.45, k))

		"gather":
			for cf: Dictionary in study_confetti:
				(cf["node"] as MeshInstance3D).visible = false
			if frame % 16 == 0:
				for i: int in crowd.size():
					if (i + frame / 16) % 3 == 0:
						(crowd[i].get("visual") as Node).call("play_emote", EMOTES[(i + frame) % EMOTES.size()])
			# Sırayla konuşma baloncukları açılır
			var bubbles: Array = [
				[0.25, 0, "Ortabahçe'ye gel!"],
				[0.95, 3, "Selam YTÜ!"],
				[1.70, 5, "Kahve molası!"],
				[2.45, 7, "Süper görünüyorsun!"],
			]
			for b_item: Array in bubbles:
				var key: String = str(b_item[1])
				if t >= float(b_item[0]) and not crowd_bubbles_shown.has(key):
					crowd_bubbles_shown[key] = true
					_show_bubble(crowd[int(b_item[1])], str(b_item[2]), 3.5)

			var c: Vector3 = _ground(GATHER_CENTER) + Vector3.UP * 0.9
			var ang: float = lerpf(0.55, -0.35, _ease(k))
			var r: float = lerpf(5.2, 13.5, _ease(k))
			cam.fov = lerpf(56.0, 64.0, e_or_k(k))
			cam.global_position = c + Vector3(sin(ang) * r, lerpf(1.4, 6.2, _ease(k)), cos(ang) * r)
			cam.look_at(c + Vector3.UP * lerpf(0.2, 1.8, k))
			# Altın saatten (17.7) lacivert geceye (21.5) yumuşak geçiş
			day_night.call("apply", lerpf(17.7, 21.5, _ease(k)))

		"star":
			day_night.call("apply", 22.0)
			cam.keep_aspect = Camera3D.KEEP_WIDTH
			cam.fov = lerpf(70.0, 62.0, _ease(k))
			cam.global_position = COURTYARD + Vector3(lerpf(-10.0, 4.0, k), lerpf(40.0, 32.0, k), lerpf(148.0, 128.0, _ease(k)))
			cam.look_at(COURTYARD + Vector3(0.0, lerpf(36.0, 10.0, _ease(k)), lerpf(-130.0, -40.0, _ease(k))))

			var impact_t: float = 2.35
			var fall: float = clampf(t / impact_t, 0.0, 1.0)
			var a: Vector3 = COURTYARD + Vector3(-165.0, 165.0, -300.0)
			var b: Vector3 = COURTYARD + Vector3(24.0, 82.0, -145.0)
			var land: Vector3 = _ground(KUTBI_SPOT) + Vector3.UP * 1.1
			var head: Vector3 = a.lerp(b, fall).lerp(b.lerp(land, fall), fall)
			star_hist.push_front(head)
			if star_hist.size() > STAR_TRAIL:
				star_hist.resize(STAR_TRAIL)
			for i: int in STAR_TRAIL:
				star_parts[i].visible = fall < 1.0 and i < star_hist.size()
				if star_parts[i].visible:
					star_parts[i].global_position = star_hist[i]

			# Çarpma patlaması + şok dalgası halkası + kıvılcımlar
			var fk: float = clampf((t - impact_t) / 1.1, 0.0, 1.0)
			var post_t: float = t - impact_t
			flash_core.visible = t >= impact_t
			shock_ring.visible = t >= impact_t
			if t >= impact_t:
				flash_core.global_position = land
				flash_core.scale = Vector3.ONE * lerpf(1.2, 34.0, _ease(fk))
				(flash_core.mesh.surface_get_material(0) as StandardMaterial3D).albedo_color.a = lerpf(0.95, 0.0, fk)

				shock_ring.global_position = land + Vector3.UP * 0.4
				var ring_s: float = lerpf(2.0, 48.0, _ease(fk))
				shock_ring.scale = Vector3(ring_s, 1.0, ring_s)
				(shock_ring.mesh.surface_get_material(0) as StandardMaterial3D).albedo_color.a = lerpf(0.95, 0.0, fk)

				flash_light.global_position = land + Vector3.UP * 4.0
				flash_light.light_energy = 26.0 * (1.0 - fk)
			else:
				flash_light.light_energy = 0.0

			for sp: Dictionary in impact_sparks:
				var m: MeshInstance3D = sp["node"]
				if post_t > 0.0 and post_t < 1.15:
					m.visible = true
					var v: Vector3 = sp["vel"]
					m.global_position = land + v * post_t + Vector3.DOWN * 18.0 * post_t * post_t
					m.scale = Vector3.ONE * clampf(1.0 - post_t / 1.15, 0.0, 1.0)
				else:
					m.visible = false

		"kutbi":
			day_night.call("apply", 22.0)
			dressup_pet.visible = false
			for r_info: Dictionary in runners:
				(r_info["node"] as Node3D).visible = false
			flash_core.visible = false
			shock_ring.visible = false
			flash_light.light_energy = 0.0
			for sp: Dictionary in impact_sparks:
				(sp["node"] as MeshInstance3D).visible = false
			for p_s: MeshInstance3D in star_parts:
				p_s.visible = false

			kutbi.visible = true
			var kp: Vector3 = kutbi.global_position
			var grow: float = _ease_out_back(clampf(t / 0.85, 0.0, 1.0))
			kutbi.scale = Vector3.ONE * lerpf(0.05, 1.08, grow)
			kutbi_light.global_position = kp + Vector3(0.4, 1.1, 1.6)
			kutbi_light.light_energy = lerpf(4.5, 1.4, clampf(t / 1.0, 0.0, 1.0))
			kutbi_rim.global_position = kp + Vector3(-1.4, 1.5, -1.6)
			kutbi_rim.light_energy = 2.0

			# Altın pedestal halkası (yavaşça döner ve nefes alır)
			kutbi_ring.visible = true
			kutbi_ring.global_position = kp + Vector3.UP * 0.08
			var pulse: float = 1.0 + sin(t * 3.5) * 0.06
			kutbi_ring.scale = Vector3(pulse * grow, 1.0, pulse * grow)
			kutbi_ring.rotation.y = t * 0.8

			# Yükselen yıldız tozları
			for em: Dictionary in kutbi_embers:
				var m: MeshInstance3D = em["node"]
				m.visible = true
				var ang: float = float(em["ang"]) + float(em["spin"]) * t
				var rad: float = float(em["rad"])
				var y: float = fposmod(float(em["y0"]) + float(em["rise"]) * t, 3.2)
				m.global_position = kp + Vector3(cos(ang) * rad, y, sin(ang) * rad)
				var alpha_k: float = sin(clampf(y / 3.2, 0.0, 1.0) * PI)
				m.scale = Vector3.ONE * (0.4 + 0.8 * alpha_k)

			if absf(t - 0.75) < 0.5 / FPS:
				(kutbi.get("visual") as Node).call("play_emote", &"emote_wave")
			if absf(t - 2.35) < 0.5 / FPS:
				(kutbi.get("visual") as Node).call("play_emote", &"emote_dance")

			var c: Vector3 = kp + Vector3.UP * 0.68
			var orbit: float = lerpf(-0.42, 0.36, _ease(k))
			var dist: float = lerpf(3.6, 2.25, _ease(k))
			cam.fov = lerpf(56.0, 48.0, _ease(k))
			cam.global_position = c + Vector3(sin(orbit) * dist, lerpf(0.25, 0.05, k), cos(orbit) * dist)
			cam.look_at(c + Vector3.UP * 0.14)


func e_or_k(k: float) -> float:
	return _ease(k)
