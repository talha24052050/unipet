extends RefCounted

const ZoneCatalog := preload("res://src/world/zone_catalog.gd")
const CampusTransit := preload("res://src/world/campus_transit.gd")
const LocalProfile := preload("res://src/core/local_profile.gd")
const CharacterRegistry := preload("res://src/characters/character_registry.gd")
const AccessoryRegistry := preload("res://src/characters/accessory_registry.gd")


func _ensure_registries() -> void:
	if Services.characters == null:
		Services.characters = CharacterRegistry.new()
		Services.characters.load_from_dir("res://data/characters")
	if Services.accessories == null:
		Services.accessories = AccessoryRegistry.new()
		Services.accessories.load_from_dir("res://data/accessories")


func test_game_starts_at_a_kapisi() -> String:
	var cat: RefCounted = ZoneCatalog.load_default()
	var sp: Vector2 = cat.get_zone("kampus")["spawn"]
	if sp.distance_to(Vector2(764.89, 566.52)) > 5.0:
		return "Oyun başlangıç noktası A Kapısı durağında değil: %s" % sp
	return ""


func test_ring_41at_fleet_boarding_onboarding_and_auto_alight() -> String:
	_ensure_registries()
	var saved_prof: RefCounted = LocalProfile.load_or_default()
	var prev_seen: bool = bool(saved_prof.get("onboarding_seen"))
	saved_prof.set("onboarding_seen", false)
	saved_prof.call("save")

	var player: Node3D = (load("res://scenes/player.tscn") as PackedScene).instantiate() as Node3D
	(Engine.get_main_loop() as SceneTree).root.add_child(player)
	if not player.is_node_ready():
		player.call("_ready")
	player.position = Vector3(764.89, 0.5, 566.52)

	var transit: Node3D = CampusTransit.new()
	transit.set("use_wall_clock", false)  # t=0: Ring #1 A Kapısı'nda bekliyor
	transit.set("player", player)
	(Engine.get_main_loop() as SceneTree).root.add_child(transit)
	transit.call("build")

	var stops: Array = transit.get("stops")
	var buses: Array = transit.call("get_live_buses")
	if stops.size() < 11:
		transit.free()
		player.free()
		return "En az 11 kampüs Ring/41AT durağı olmalıydı: %d" % stops.size()
	if buses.size() != 5:
		transit.free()
		player.free()
		return "t=0 anında 4 Mavi Ring + 1 sembolik 41AT olmak üzere 5 aktif otobüs olmalıydı: %d" % buses.size()
	var has_41at: bool = false
	for b: Dictionary in buses:
		if bool(b.get("is_41at", false)):
			has_41at = true
	if not has_41at:
		transit.free()
		player.free()
		return "Sembolik 41AT otobüsü filoda bulunamadı"

	# Durakta bekleyen Ring #1'in kayar kapıları açık olmalı
	var raw_buses: Array = transit.get("_buses")
	if float(raw_buses[0].get("door_open", 0.0)) < 0.9:
		transit.free()
		player.free()
		return "A Kapısı'nda bekleyen Ring #1'in kapıları açık değil"

	# A Kapısı'nda bekleyen Ring #1'e biniş ve ilk biniş tanıtım turu kontrolü
	var boarded: bool = transit.call("board_nearest_bus")
	var onboarding_shown: bool = transit.call("is_onboarding_visible")
	if not boarded or not onboarding_shown:
		transit.free()
		player.free()
		return "A Kapısı'nda Ring'e biniş veya ilk biniş Tanıtım Turu açılmadı (boarded=%s, tour=%s)" % [boarded, onboarding_shown]

	# İneceği durağı 2. durak (İlhan Varank Kütüphanesi, index=1) seç ve otobüsü ilerlet -> durakta otomatik inmeli!
	transit.call("_finish_onboarding")
	transit.call("set_target_stop_index", 1)
	for _step: int in 600:
		transit.call("_process", 0.25)
		if int(transit.get("riding_bus_idx")) == -1:
			break

	var alighted_ok: bool = int(transit.get("riding_bus_idx")) == -1
	var p_end: Vector3 = player.global_position if player.is_inside_tree() else player.position
	var end_xz: Vector2 = Vector2(p_end.x, p_end.z)
	var stop1_xz: Vector2 = stops[1]["shelter_pos"]
	var dist_to_stop1: float = end_xz.distance_to(stop1_xz)

	var restore_p: RefCounted = LocalProfile.load_or_default()
	restore_p.set("onboarding_seen", prev_seen)
	restore_p.call("save")
	transit.free()
	player.free()

	if not alighted_ok or dist_to_stop1 > 12.0:
		return "Seçilen durakta otomatik iniş gerçekleşmedi (alighted=%s, dist=%.1f)" % [alighted_ok, dist_to_stop1]
	return ""


func test_bus_timetable_is_shared_and_periodic() -> String:
	# Aynı saatte iki ayrı istemci (iki CampusTransit) otobüsleri aynı yerde görmeli; 2 tam periyotta tüm filo (41AT dahil) aynı konuma döner.
	var a: Node3D = CampusTransit.new()
	var b: Node3D = CampusTransit.new()
	for t: Node3D in [a, b]:
		t.set("use_wall_clock", false)
		(Engine.get_main_loop() as SceneTree).root.add_child(t)
		t.call("build")
	var period: float = float(a.get("_period"))
	var err: String = ""
	if period < 120.0:
		err = "tarife periyodu çok kısa: %.1f" % period
	if err.is_empty():
		a.call("_process", 137.3)
		b.call("_process", 137.3 + 2.0 * period)  # iki tur sonrası = Mavi Ring + 41AT dahil birebir aynı konum
		var ba: Array = a.call("get_live_buses")
		var bb: Array = b.call("get_live_buses")
		if ba.size() != bb.size():
			err = "aktif otobüs sayısı farklı: %d / %d" % [ba.size(), bb.size()]
		else:
			for i: int in ba.size():
				if (ba[i]["pos"] as Vector2).distance_to(bb[i]["pos"] as Vector2) > 0.5:
					err = "otobüs %d iki istemcide farklı yerde: %s / %s" % [i, ba[i]["pos"], bb[i]["pos"]]
					break
	# 41AT döngüsünün şehir seferi yarısında kampüs dışında olmalı (yalnızca 4 Mavi Ring görünür, ama 41AT ETA > 0 döner)
	if err.is_empty():
		var c: Node3D = CampusTransit.new()
		c.set("use_wall_clock", false)
		(Engine.get_main_loop() as SceneTree).root.add_child(c)
		c.call("build")
		c.call("_process", 1.15 * period)
		var bc: Array = c.call("get_live_buses")
		var eta_ring: float = float(c.call("seconds_until_next_ring", 0))
		var eta_41at: float = float(c.call("seconds_until_next_41at", 0))
		c.free()
		if bc.size() != 4:
			err = "41AT şehir seferindeyken kampüste 4 Mavi Ring kalmalıydı: %d" % bc.size()
		elif eta_ring < 0.0 or eta_ring > period or eta_41at <= 0.0 or eta_41at > 2.0 * period:
			err = "Ring/41AT varış süreleri geçersiz (ring=%.1f, 41at=%.1f)" % [eta_ring, eta_41at]
	a.free()
	b.free()
	return err


func test_riding_bus_has_no_gravity_drift_or_camera_jitter() -> String:
	_ensure_registries()
	var player: CharacterBody3D = (load("res://scenes/player.tscn") as PackedScene).instantiate() as CharacterBody3D
	var cam_rig: Node3D = (load("res://scenes/follow_camera.tscn") as PackedScene).instantiate() as Node3D
	var transit: Node3D = CampusTransit.new()
	var tree: SceneTree = Engine.get_main_loop() as SceneTree

	tree.root.add_child(player)
	if not player.is_node_ready():
		player.call("_ready")
	player.position = Vector3(764.89, 0.5, 566.52)

	cam_rig.set("target", player)
	tree.root.add_child(cam_rig)
	if not cam_rig.is_node_ready():
		cam_rig.call("_ready")

	transit.set("use_wall_clock", false)
	transit.set("player", player)
	tree.root.add_child(transit)
	transit.call("build")

	if not bool(transit.call("board_nearest_bus")):
		transit.free(); cam_rig.free(); player.free()
		return "Otobüs binişi başarısız"

	# A Kapısı beklemesini geçip otobüsü virajlarda 180 kare (3 sn, 60 FPS) yürüt; her karede fizik -> transit -> kamera sırasını sına!
	transit.set("_sim_time", 22.0)
	transit.call("_process", 0.0)
	cam_rig.call("_process", 0.016)
	var prev_cam: Vector3 = cam_rig.position
	var err: String = ""
	for step: int in 180:
		var dt: float = 1.0 / 60.0
		player.call("_physics_process", dt)
		# Fizik adımından hemen sonra oyuncu yeraltına düşmemiş ve hız biriktirmemiş olmalı!
		if player.velocity.length() > 0.001:
			err = "Otobüste yerçekimi hızı birikti: %s" % player.velocity
			break
		transit.call("_process", dt)
		cam_rig.call("_process", dt)
		var jump: float = cam_rig.position.distance_to(prev_cam)
		if jump > 0.55:
			err = "Kamera kareler arası ani sıçradı (kare %d, jump=%.2f m)" % [step, jump]
			break
		prev_cam = cam_rig.position

	# Çift biniş denemesi çarpışmayı bozmamalı ve inişte çarpışma kesin açık kalmalı!
	if bool(transit.call("board_nearest_bus")):
		transit.free(); cam_rig.free(); player.free()
		return "Otobüste iken ikinci kez biniş kabul edilmemeli"

	transit.call("alight_bus", 0)
	var col_after: CollisionShape3D = player.get_node("Collision") as CollisionShape3D
	if col_after.disabled or bool(player.get("riding_bus")):
		transit.free(); cam_rig.free(); player.free()
		return "Otobüsten indikten sonra çarpışma kapalı kaldı veya riding_bus sıfırlanmadı"
	transit.free()
	cam_rig.free()
	player.free()
	return err
