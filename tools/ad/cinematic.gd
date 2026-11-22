extends SceneTree
## Reklam filmi için oyun içi sinematik (Movie Maker ile kayıt).
## Kullanım:
##   godot --path game --write-movie <çıktı>.avi --fixed-fps 30 --resolution 1080x1920 -s <repo>/tools/ad/cinematic.gd
## Çekimler (SHOTS; build_ad.py aynı zamanları kullanır):
##   queue    Yemekhane önünde petlerden uzun kuyruk, kamera kuyruk boyunca kayar, sonda üzgün maskot (gündüz)
##   drone    Ortabahçe'nin tamamı geniş açıyla, avlu etrafında dönüp alçalarak
##   dance    Yemekhane önünde maskot dans ediyor
##   gather   Büfede toplanan petler emote atıyor, gece çöküyor
##   star     Gece Ortabahçe: kayan yıldız iz bırakarak avluya düşer, ışık patlaması (Kutbi'nin gelişi)

const FPS: float = 30.0
const SHOTS: Array = [["queue", 2.8], ["drone", 4.6], ["dance", 2.0], ["gather", 2.4], ["star", 3.2]]
## Kuyruk Yemekhane cephesi boyunca uzanan yaya yolunun üstünde (greybox: (-75.4,-76.7)→(-59.5,-101.0))
const YEMEKHANE_DOOR: Vector3 = Vector3(-72.0, 0.0, -82.0)
const QUEUE_DIR: Vector3 = Vector3(0.548, 0.0, -0.837)
const QUEUE_LEN: int = 12
const QUEUE_GAP: float = 1.6
const DANCE_SPOT: Vector3 = Vector3(-60.0, 0.0, -80.0)
const GATHER_CENTER: Vector3 = Vector3(-4.0, 0.0, 56.0)
const COURTYARD: Vector3 = Vector3(12.0, 0.0, 20.0)
const DRONE_FOV: float = 78.0
const PETS: Array[StringName] = [&"mushnub", &"shark", &"chicken", &"ninja", &"birb", &"yeti"]
const NAMES: PackedStringArray = ["Zeynep", "Mert", "Ece", "Kaan", "Defne", "Arda", "Elif", "Can", "Ada", "Emir", "Nil", "Efe", "Su", "Deniz"]
const EMOTES: Array[StringName] = [&"emote_dance", &"emote_wave", &"emote_jump", &"emote_yes"]
const ACC_SETS: Array = [{"head": "hat_cap", "face": "glasses"}, {"neck": "scarf"}, {"head": "beanie"}, {"face": "sunglasses"},
	{"neck": "bowtie"}, {"back": "wings"}, {"back": "backpack", "head": "hat_cap"}, {}]
const STAR_TRAIL: int = 28
const STAR_COLOR: Color = Color(1.0, 0.85, 0.45)

var cam: Camera3D
var day_night: Node
var env: Environment
var hero: Node3D
var queue_pets: Array[Node3D] = []
var crowd: Array[Node3D] = []
var star_parts: Array[MeshInstance3D] = []
var star_hist: Array[Vector3] = []
var flash: MeshInstance3D
var flash_light: OmniLight3D
var frame: int = 0


func _initialize() -> void:
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
	day_night.call("apply", 15.0)
	env = (s.get_node("Environment") as WorldEnvironment).environment
	env.glow_enabled = true  # kayan yıldız parlasın
	env.glow_intensity = 1.2
	env.glow_bloom = 0.15
	cam = Camera3D.new()
	cam.far = 900.0
	s.add_child(cam)
	cam.make_current()
	var RP: PackedScene = load("res://scenes/remote_player.tscn")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 2405
	# kuyruk: kapıdan dışarı, son sırada maskot
	for i: int in QUEUE_LEN:
		var p: Vector3 = YEMEKHANE_DOOR + QUEUE_DIR * (i * QUEUE_GAP) + Vector3(rng.randf_range(-0.25, 0.25), 0, rng.randf_range(-0.2, 0.2))
		var yaw: float = atan2(-QUEUE_DIR.x, -QUEUE_DIR.z)
		var last: bool = i == QUEUE_LEN - 1
		queue_pets.append(_spawn(RP, &"mushnub" if last else PETS[(i + 1) % PETS.size()], "",
			{"head": "hat_cap", "face": "glasses"} if last else ACC_SETS[i % ACC_SETS.size()], p, yaw))
	hero = _spawn(RP, &"mushnub", "", {"head": "hat_cap", "face": "glasses"}, DANCE_SPOT, 0.6)
	for i: int in NAMES.size():
		var a: float = TAU * float(i) / NAMES.size() + rng.randf_range(-0.2, 0.2)
		var r: float = rng.randf_range(3.5, 8.5)
		var p: Vector3 = GATHER_CENTER + Vector3(cos(a) * r, 0.0, sin(a) * r)
		crowd.append(_spawn(RP, PETS[i % PETS.size()], NAMES[i], ACC_SETS[i % ACC_SETS.size()], p, atan2(GATHER_CENTER.x - p.x, GATHER_CENTER.z - p.z)))
	_make_star()
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


func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _emissive(size: float, alpha: float = 1.0) -> MeshInstance3D:
	var m: MeshInstance3D = MeshInstance3D.new()
	var sp: SphereMesh = SphereMesh.new()
	sp.radius = size
	sp.height = size * 2.0
	sp.radial_segments = 10
	sp.rings = 6
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(STAR_COLOR.r, STAR_COLOR.g, STAR_COLOR.b, alpha)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = STAR_COLOR
	mat.emission_energy_multiplier = 6.0
	sp.material = mat
	m.mesh = sp
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.visible = false
	current_scene.add_child(m)
	return m


func _make_star() -> void:
	for i: int in STAR_TRAIL:
		var k: float = 1.0 - float(i) / STAR_TRAIL
		star_parts.append(_emissive(lerpf(0.5, 3.2, k * k), clampf(k, 0.15, 1.0)))  # kamera ~150 m uzakta: iri
	flash = _emissive(1.0, 0.9)
	flash_light = OmniLight3D.new()
	flash_light.light_color = STAR_COLOR
	flash_light.omni_range = 90.0
	flash_light.light_energy = 0.0
	current_scene.add_child(flash_light)


func _shot(shot_name: String, t: float, dur: float) -> void:
	var k: float = clampf(t / dur, 0.0, 1.0)
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.fov = 62.0
	match shot_name:
		"queue":
			day_night.call("apply", 15.0)
			# Kuyruğun sonundan kapıya doğru bakış: önce uzaktan uzun sıra, sonra sondaki üzgün maskota yaklaşma
			var back: Vector3 = queue_pets[QUEUE_LEN - 1].global_position
			var front: Vector3 = queue_pets[0].global_position
			var side: Vector3 = Vector3(-QUEUE_DIR.z, 0.0, QUEUE_DIR.x)
			var e: float = _ease(k)
			cam.global_position = back + QUEUE_DIR * lerpf(9.0, 2.6, e) + side * lerpf(2.5, 1.2, e) + Vector3.UP * lerpf(4.5, 1.3, e)
			cam.look_at(front.lerp(back, lerpf(0.3, 0.92, e)) + Vector3.UP * 0.7)
			if absf(t - dur * 0.72) < 0.5 / FPS:
				(queue_pets[QUEUE_LEN - 1].get("visual") as Node).call("play_emote", &"emote_no")
		"drone":
			var e: float = _ease(k)
			cam.keep_aspect = Camera3D.KEEP_WIDTH
			cam.fov = DRONE_FOV
			var ang: float = lerpf(deg_to_rad(-10.0), deg_to_rad(-80.0), e)
			var r: float = lerpf(300.0, 190.0, e)
			cam.global_position = COURTYARD + Vector3(sin(ang) * r, lerpf(260.0, 120.0, e), -cos(ang) * r)
			cam.look_at(COURTYARD + Vector3(0.0, 0.0, lerpf(30.0, 10.0, e)))
		"dance":
			if absf(t) < 0.5 / FPS or absf(t - 1.0) < 0.5 / FPS:
				(hero.get("visual") as Node).call("play_emote", &"emote_dance")
			var c: Vector3 = hero.global_position + Vector3.UP * 0.9
			var ang: float = lerpf(-0.9, 0.6, _ease(k))
			var r: float = lerpf(4.2, 3.2, k)
			cam.global_position = c + Vector3(sin(ang) * r, lerpf(1.6, 1.0, k), cos(ang) * r)
			cam.look_at(c)
		"gather":
			if frame % 18 == 0:
				for i: int in crowd.size():
					if (i + frame / 18) % 3 == 0:
						(crowd[i].get("visual") as Node).call("play_emote", EMOTES[(i + frame) % EMOTES.size()])
			var c: Vector3 = _ground(GATHER_CENTER) + Vector3.UP * 1.0
			var ang: float = lerpf(0.4, -0.2, k)
			var r: float = lerpf(5.5, 15.0, _ease(k))
			cam.global_position = c + Vector3(sin(ang) * r, lerpf(1.6, 8.0, _ease(k)), cos(ang) * r)
			cam.look_at(c + Vector3.UP * lerpf(0.0, 3.0, k))
			day_night.call("apply", lerpf(15.0, 21.5, _ease((k - 0.35) / 0.65)))
		"star":
			day_night.call("apply", 22.0)
			# ağaçların üstünden: avlu, Kışla'nın kuzey kanadı ve gökyüzü; yıldız sol üstten süzülüp avluya iner
			cam.keep_aspect = Camera3D.KEEP_WIDTH
			cam.fov = 70.0
			cam.global_position = COURTYARD + Vector3(0.0, lerpf(42.0, 36.0, k), 150.0)
			cam.look_at(COURTYARD + Vector3(0.0, lerpf(40.0, 12.0, _ease(k)), -150.0))
			var fall: float = clampf(t / 2.2, 0.0, 1.0)
			var a: Vector3 = COURTYARD + Vector3(-170.0, 170.0, -320.0)
			var b: Vector3 = COURTYARD + Vector3(20.0, 90.0, -160.0)
			var land: Vector3 = _ground(COURTYARD + Vector3(4.0, 0.0, 10.0)) + Vector3.UP * 1.2
			var head: Vector3 = a.lerp(b, fall).lerp(b.lerp(land, fall), fall)  # ikinci derece eğri
			star_hist.push_front(head)
			if star_hist.size() > STAR_TRAIL:
				star_hist.resize(STAR_TRAIL)
			for i: int in STAR_TRAIL:
				star_parts[i].visible = fall < 1.0 and i < star_hist.size()
				if star_parts[i].visible:
					star_parts[i].global_position = star_hist[i]
			var fk: float = clampf((t - 2.2) / 0.9, 0.0, 1.0)  # iniş patlaması
			flash.visible = t >= 2.2
			flash.global_position = land
			flash.scale = Vector3.ONE * lerpf(1.0, 38.0, _ease(fk))
			(flash.mesh.surface_get_material(0) as StandardMaterial3D).albedo_color.a = lerpf(1.0, 0.0, fk)
			flash_light.global_position = land + Vector3.UP * 2.0
			flash_light.light_energy = 18.0 * (1.0 - fk) if t >= 2.2 else 0.0
