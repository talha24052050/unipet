extends SceneTree
## Google Play mağaza ekran görüntüleri (dikey 1080x1920). Gerçek oyun sahnesi + HUD, çevreye örnek oyuncular.
## Kullanım (pencereli, render gerekir):
##   godot --path game --resolution 1080x1920 -s <repo>/tools/store/screenshots.gd -- <çıktı klasörü>
## Çıktı: 01_ortabahce.png ... (docs/store/screenshots/)

const PETS: Array[StringName] = [&"mushnub", &"shark", &"chicken", &"ninja", &"birb", &"yeti"]
const NAMES: PackedStringArray = ["Zeynep", "Mert", "Ece", "Kaan", "Defne", "Arda", "Elif", "Can"]
const ACC_SETS: Array = [
	{"head": "hat_cap", "face": "glasses"}, {"neck": "scarf"}, {"head": "beanie"}, {"face": "sunglasses"},
	{"head": "flower_crown"}, {"back": "backpack"}, {"neck": "bowtie"}, {"head": "crown_star"},
]
const BUBBLES: PackedStringArray = ["Selam! 👋", "Hokka'da buluşalım mı?", "Ring geliyor!", "Petin çok tatlı 😍"]

## [ad, oyuncu xz, bakış yönü (yaw), saat, kalabalık]
const SHOTS: Array = [
	["01_ortabahce", Vector2(-4.0, 50.0), 0.0, 15.0, 7],
	["02_yemekhane", Vector2(-60.0, -70.0), 2.6, 12.5, 6],
	["03_tarihi_hamam", Vector2(30.0, -150.0), 2.3, 16.5, 4],
	["04_stadyum", Vector2(-300.0, 20.0), 1.4, 17.5, 5],
	["05_aksam_kampus", Vector2(-4.0, 30.0), 0.0, 18.4, 6],
]

var out_dir: String = ""
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _initialize() -> void:
	rng.seed = 2026
	var args: PackedStringArray = OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else ProjectSettings.globalize_path("res://../docs/store/screenshots")
	DirAccess.make_dir_recursive_absolute(out_dir)
	# Pencere ekrandan büyük olamıyor (dikey 1920 > ekran): kenarlıksız pencereyi ekran dışına taşacak boyuta zorla.
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_position(Vector2i(0, 0))
	DisplayServer.window_set_size(Vector2i(1080, 1920))
	await process_frame
	await process_frame
	print("pencere: ", DisplayServer.window_get_size(), " görüntü: ", root.get_visible_rect().size)
	var services: Node = root.get_node("Services")
	var RP: PackedScene = load("res://scenes/remote_player.tscn")
	for sh: Array in SHOTS:
		var at: Vector2 = sh[1]
		services.set("pending_teleport", at)
		services.set("return_position", Vector3.INF)
		change_scene_to_file("res://scenes/main.tscn")
		for i: int in 90:
			await process_frame
		var s: Node = current_scene
		var player: Node3D = s.get_node("Player")
		player.rotation.y = float(sh[2])
		player.call("set_display_name", "Yıldız")
		for lbl: String in ["UI/PerfLabel", "UI/ConnectionLabel"]:
			var l: CanvasItem = s.get_node_or_null(lbl)
			if l != null:
				l.visible = false
				l.set_process(false)
		var cam: Node = s.get_node("FollowCamera")
		cam.set("yaw", float(sh[2]))
		cam.set("pitch", deg_to_rad(-30.0))
		cam.set("distance", 9.0)
		var dn: Node = s.get_node_or_null("DayNight")
		if dn != null:
			dn.set_process(false)
			dn.call("apply", float(sh[3]))
		_crowd(RP, player.global_position, float(sh[2]), int(sh[4]))
		for i: int in 75:
			await process_frame
		var img: Image = root.get_viewport().get_texture().get_image()
		var path: String = out_dir.path_join(str(sh[0]) + ".png")
		img.save_png(path)
		print("kaydedildi: ", path, " ", img.get_size())
	quit()


## Oyuncunun önüne, kameranın göreceği yarım çembere örnek oyuncular.
func _crowd(RP: PackedScene, center: Vector3, yaw: float, n: int) -> void:
	var fwd: Vector3 = Vector3(-sin(yaw), 0.0, -cos(yaw))
	for i: int in n:
		# Oyuncunun çevresinde tam çember: kamera hangi yöne bakarsa baksın kalabalık kadrajda
		var a: float = TAU * float(i) / float(n) + rng.randf_range(-0.2, 0.2)
		var dir: Vector3 = fwd.rotated(Vector3.UP, a)
		var p: Vector3 = center + dir * rng.randf_range(2.6, 4.2)
		var node: Node3D = RP.instantiate()
		current_scene.add_child(node)
		node.call("apply_profile", {"pet": str(PETS[i % PETS.size()]), "name": NAMES[i % NAMES.size()], "acc": ACC_SETS[i % ACC_SETS.size()]})
		node.global_position = _ground(p)
		node.look_at(Vector3(center.x, node.global_position.y, center.z), Vector3.UP, true)
		node.set_process(false)
		node.visible = true  # uzak oyuncu ilk konum gelene kadar gizli kalır
		if i % 3 == 0:
			var b: Node = node.get_node_or_null("ChatBubble")
			if b != null:
				b.call("show_message", BUBBLES[(i / 3) % BUBBLES.size()], 30.0)


func _ground(p: Vector3) -> Vector3:
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(p + Vector3.UP * 50.0, p + Vector3.DOWN * 20.0)
	var hit: Dictionary = current_scene.get_world_3d().direct_space_state.intersect_ray(q)
	return hit["position"] if not hit.is_empty() else p
