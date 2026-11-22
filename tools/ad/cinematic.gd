extends SceneTree
## Reklam filmi için oyun içi sinematik (Movie Maker ile kayıt).
## Kullanım:
##   godot --path game --write-movie <çıktı>.avi --fixed-fps 30 --resolution 1080x1920 -s <repo>/tools/ad/cinematic.gd
## Çekimler (toplam ~6.6 sn):
##   A 0.0–2.4  Drone: Kışla'nın üstünden Ortabahçe'ye süzülme (gündüz)
##   B 2.4–4.4  Yemekhane önünde maskot pet dans ediyor, kamera etrafında dönüyor
##   C 4.4–6.6  Ortabahçe büfesinde toplanan petler emote atıyor, kamera yükselip geri çekiliyor; sonunda gece çöküyor

const FPS: float = 30.0
const T_A: float = 2.4
const T_B: float = 4.4
const T_END: float = 6.6
const NIGHT_START: float = 5.7
const YEMEKHANE_FRONT: Vector3 = Vector3(-60.0, 0.0, -80.0)
const KIOSK: Vector3 = Vector3(-5.8, 0.0, 47.2)
const GATHER_CENTER: Vector3 = Vector3(-4.0, 0.0, 56.0)
const PETS: Array[StringName] = [&"mushnub", &"shark", &"chicken", &"ninja", &"birb", &"yeti"]
const NAMES: PackedStringArray = ["Zeynep", "Mert", "Ece", "Kaan", "Defne", "Arda", "Elif", "Can", "Ada", "Emir", "Nil", "Efe", "Su", "Deniz"]
const EMOTES: Array[StringName] = [&"emote_dance", &"emote_wave", &"emote_jump", &"emote_yes"]
const ACC_SETS: Array = [{"head": "hat_cap", "face": "glasses"}, {"neck": "scarf"}, {"head": "beanie"}, {"face": "sunglasses"},
	{"neck": "bowtie"}, {"back": "wings"}, {"back": "backpack", "head": "hat_cap"}, {}]

var cam: Camera3D
var day_night: Node
var hero: Node3D
var crowd: Array[Node3D] = []
var frame: int = 0


func _initialize() -> void:
	await process_frame
	root.get_node("Services").set("pending_teleport", Vector2(KIOSK.x, KIOSK.z + 20.0))
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
	cam = Camera3D.new()
	cam.fov = 62.0
	cam.far = 900.0
	s.add_child(cam)
	cam.make_current()
	var RP: PackedScene = load("res://scenes/remote_player.tscn")
	hero = _spawn(RP, &"mushnub", "", {"head": "hat_cap", "face": "glasses"}, YEMEKHANE_FRONT, 0.6)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 2405
	for i: int in NAMES.size():
		var a: float = TAU * float(i) / NAMES.size() + rng.randf_range(-0.2, 0.2)
		var r: float = rng.randf_range(3.5, 8.5)
		var p: Vector3 = GATHER_CENTER + Vector3(cos(a) * r, 0.0, sin(a) * r)
		var yaw: float = atan2(GATHER_CENTER.x - p.x, GATHER_CENTER.z - p.z)
		crowd.append(_spawn(RP, PETS[i % PETS.size()], NAMES[i], ACC_SETS[i % ACC_SETS.size()], p, yaw))
	# Sinematikte uzak ağaç/prop görünme mesafesi sınırı kalksın (drone çekiminde aşamalı belirme olmasın)
	for g: Node in s.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).visibility_range_end = 0.0
	for i: int in 20:  # modeller/animasyonlar yerleşsin
		await process_frame
	while true:
		var t: float = frame / FPS
		if t > T_END:
			break
		_shot(t)
		await process_frame
		frame += 1
	quit()


func _spawn(scene: PackedScene, pet: StringName, nick: String, acc: Dictionary, pos: Vector3, yaw: float) -> Node3D:
	var n: Node3D = scene.instantiate()
	current_scene.add_child(n)
	n.call("apply_profile", {"pet": str(pet), "name": nick, "acc": acc})
	n.global_position = _ground(pos)
	n.rotation.y = yaw
	n.set_process(false)  # ağdan konum beklemesin
	return n


func _ground(p: Vector3) -> Vector3:
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(p + Vector3.UP * 50.0, p + Vector3.DOWN * 10.0)
	var hit: Dictionary = current_scene.get_world_3d().direct_space_state.intersect_ray(q)
	return hit["position"] if not hit.is_empty() else p


func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _shot(t: float) -> void:
	if t < T_A:
		var k: float = _ease(t / T_A)
		var from: Vector3 = Vector3(30.0, 150.0, -330.0)
		var to: Vector3 = Vector3(5.0, 48.0, -120.0)
		cam.global_position = from.lerp(to, k)
		cam.look_at(Vector3(0.0, 0.0, 40.0).lerp(Vector3(-5.0, 0.0, 30.0), k))
	elif t < T_B:
		var k: float = (t - T_A) / (T_B - T_A)
		if absf(t - T_A) < 0.5 / FPS or absf(t - (T_A + 1.0)) < 0.5 / FPS:
			(hero.get("visual") as Node).call("play_emote", &"emote_dance")
		var c: Vector3 = hero.global_position + Vector3.UP * 0.9
		var ang: float = lerpf(-0.9, 0.6, _ease(k))
		var r: float = lerpf(4.2, 3.2, k)
		cam.global_position = c + Vector3(sin(ang) * r, lerpf(1.6, 1.0, k), cos(ang) * r)
		cam.look_at(c)
	else:
		var k: float = (t - T_B) / (T_END - T_B)
		if frame % 18 == 0:  # petler sırayla emote atsın
			for i: int in crowd.size():
				if (i + frame / 18) % 3 == 0:
					(crowd[i].get("visual") as Node).call("play_emote", EMOTES[(i + frame) % EMOTES.size()])
		var c: Vector3 = _ground(GATHER_CENTER) + Vector3.UP * 1.0
		var ang: float = lerpf(0.4, -0.2, k)
		var r: float = lerpf(5.5, 15.0, _ease(k))
		cam.global_position = c + Vector3(sin(ang) * r, lerpf(1.6, 8.0, _ease(k)), cos(ang) * r)
		cam.look_at(c + Vector3.UP * lerpf(0.0, 3.0, k))
		if t > NIGHT_START:
			day_night.call("apply", lerpf(15.0, 21.5, _ease((t - NIGHT_START) / (T_END - NIGHT_START))))
