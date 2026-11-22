extends SceneTree
## Uçtan uca: oyun sahnesinden haritaya ve pet seçimine gidip dönünce (1) konum korunuyor mu, (2) odaya yeniden
## katılınıyor mu, (3) başka oyuncu hâlâ görüyor mu. Gerçek Nakama gerekir (CI e2e işi / server/local-nakama.ps1).
## Hata 2026-11-22 (Talha, arkadaşla online test): haritaya girip çıkınca yer değişiyor; pet seçiminde bağlantı kopuyor.
## Kullanım: godot --headless --path game -s <repo>/tools/e2e/scene_roundtrip.gd
var Nk: GDScript
var Map: GDScript
var seen: Dictionary = {}

func _wait_online(sec: float) -> String:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000):
		await create_timer(0.25).timeout
		if current_scene != null and current_scene.has_node("UI/ConnectionLabel"):
			var s: String = (current_scene.get_node("UI/ConnectionLabel") as Label).text
			if s.begins_with("Çevrimiçi") and not str(root.get_node("Services").get("net").get("_match_id")).is_empty():
				return s
	return "BAĞLI DEĞİL"

func _pos() -> Vector3:
	return (current_scene.get_node("Player") as Node3D).global_position

func _initialize() -> void:
	await process_frame
	Nk = load("res://src/net/nakama_network_service.gd")
	Map = load("res://src/ui/campus_map.gd")
	var svc: Node = root.get_node("Services")
	svc.get("auth").call("quick_sign_in")
	svc.call("use_server", {"host": "127.0.0.1", "port": 7350, "ssl": false})
	# gözlemci (arkadaş) aynı süreçte ikinci istemci
	var obs: Node = Nk.new()
	obs.set("custom_id_override", "mock-gozlemci")
	root.add_child(obs)
	obs.player_joined.connect(func(id: String, _s: Dictionary) -> void: seen[id] = true)
	obs.player_left.connect(func(id: String) -> void: seen.erase(id))
	obs.connected.connect(func() -> void: obs.join_zone("kampus"))
	obs.connect_to_server("mock-token")
	change_scene_to_file("res://scenes/main.tscn")
	print("1) ilk bağlantı: ", await _wait_online(30))
	var me: String = str(svc.get("net").call("local_player_id"))
	(current_scene.get_node("Player") as Node3D).global_position = Vector3(30, 0.5, 40)
	await create_timer(1.0).timeout
	var before: Vector3 = _pos()
	# harita aç-kapa
	Map.open_from(self, before)
	await create_timer(1.5).timeout
	(current_scene as Node).call("close")
	var r2: String = await _wait_online(30)
	print("2) haritadan dönüş: ", r2)
	if r2 == "BAĞLI DEĞİL":
		print("SAHNE GİDİŞ-DÖNÜŞ BAŞARISIZ"); quit(1); return
	await create_timer(1.0).timeout
	print("   konum farkı (m): %.2f" % _pos().distance_to(before))
	# pet seçimi ve geri
	change_scene_to_file("res://scenes/ui/pet_select.tscn")
	await create_timer(6.0).timeout
	(current_scene as Node).call("start_game")
	var r3: String = await _wait_online(30)
	print("3) pet seçiminden dönüş: ", r3)
	if r3 == "BAĞLI DEĞİL":
		print("SAHNE GİDİŞ-DÖNÜŞ BAŞARISIZ"); quit(1); return
	await create_timer(2.0).timeout
	print("   konum farkı (m): %.2f" % _pos().distance_to(before))
	print("   gözlemci beni görüyor mu: ", seen.has(me))
	var ok: bool = seen.has(me) and _pos().distance_to(before) < 0.5
	print("SAHNE GİDİŞ-DÖNÜŞ GEÇTİ" if ok else "SAHNE GİDİŞ-DÖNÜŞ BAŞARISIZ")
	quit(0 if ok else 1)
