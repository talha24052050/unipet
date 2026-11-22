extends RefCounted
## NetworkSync ve RemotePlayer senkronizasyon testleri.

const NetworkSync := preload("res://src/net/network_sync.gd")
const FakeNet := preload("res://src/net/fake_network_service.gd")
const RemotePlayerScene := preload("res://scenes/remote_player.tscn")
const CharacterRegistry := preload("res://src/characters/character_registry.gd")
const AccessoryRegistry := preload("res://src/characters/accessory_registry.gd")
const OfflineNetworkService := preload("res://src/net/offline_network_service.gd")


func _ensure_services() -> void:
	if Services.characters == null:
		Services.characters = CharacterRegistry.new()
		Services.characters.load_from_dir("res://data/characters")
	if Services.accessories == null:
		Services.accessories = AccessoryRegistry.new()
		Services.accessories.load_from_dir("res://data/accessories")
	if Services.net == null:
		var net_inst: OfflineNetworkService = OfflineNetworkService.new()
		Services.net = net_inst
		Services.add_child(net_inst)


func _setup_sync(fake_net: Node) -> Node:
	var sync: Node = NetworkSync.new()
	var root: Node = (Engine.get_main_loop() as SceneTree).root
	sync.set("net", fake_net)
	root.add_child(sync)
	if not sync.is_node_ready():
		sync.call("_ready")
	return sync


func test_join_creates_remote_player() -> String:
	_ensure_services()
	var fake_net: Node = FakeNet.new()
	var sync: Node = _setup_sync(fake_net)

	fake_net.call("simulate_connected")
	fake_net.call("simulate_room_joined", "ortabahce-1")
	fake_net.call("simulate_player_joined", "remote_user_42", {"pos": Vector3(1, 0, 1), "yaw": 0.0, "anim": "idle"})

	var rp: Node3D = sync.call("get_remote_player", "remote_user_42")
	if rp == null:
		sync.free()
		fake_net.free()
		return "player_joined sonrası RemotePlayer oluşmadı"

	var label: Label3D = rp.get_node_or_null("NameLabel")
	var text: String = label.text if label != null else ""
	if text != "remote":
		sync.free()
		fake_net.free()
		return "NameLabel ilk 6 karakteri göstermedi: %s" % text

	sync.free()
	fake_net.free()
	return ""


func test_same_id_twice_single_node() -> String:
	_ensure_services()
	var fake_net: Node = FakeNet.new()
	var sync: Node = _setup_sync(fake_net)

	fake_net.call("simulate_player_joined", "user_same", {})
	var first_node: Node3D = sync.call("get_remote_player", "user_same")
	fake_net.call("simulate_player_joined", "user_same", {})
	var second_node: Node3D = sync.call("get_remote_player", "user_same")

	var all_players: Dictionary = sync.call("get_remote_players")
	var count: int = all_players.size()
	if first_node != second_node or count != 1:
		sync.free()
		fake_net.free()
		return "Aynı id iki kez geldiğinde tek düğüm kalmalı, boyut: %d" % count

	sync.free()
	fake_net.free()
	return ""


func test_local_id_skipped() -> String:
	_ensure_services()
	var fake_net: Node = FakeNet.new()
	fake_net.set("local_id", "my_local_id")
	var sync: Node = _setup_sync(fake_net)

	fake_net.call("simulate_player_joined", "my_local_id", {})
	if sync.call("get_remote_player", "my_local_id") != null:
		sync.free()
		fake_net.free()
		return "Yerel oyuncu id'si atlanmalıydı ancak RemotePlayer oluşturuldu"

	sync.free()
	fake_net.free()
	return ""


func test_left_removes_node() -> String:
	_ensure_services()
	var fake_net: Node = FakeNet.new()
	var sync: Node = _setup_sync(fake_net)

	fake_net.call("simulate_player_joined", "user_leave", {})
	if sync.call("get_remote_player", "user_leave") == null:
		sync.free()
		fake_net.free()
		return "Önce RemotePlayer oluşmalıydı"

	fake_net.call("simulate_player_left", "user_leave")
	if sync.call("get_remote_player", "user_leave") != null:
		sync.free()
		fake_net.free()
		return "player_left sonrası RemotePlayer silinmedi"

	sync.free()
	fake_net.free()
	return ""


func test_profile_updates_pet() -> String:
	_ensure_services()
	var fake_net: Node = FakeNet.new()
	var sync: Node = _setup_sync(fake_net)

	fake_net.call("simulate_player_joined", "user_prof", {})
	var rp: Node3D = sync.call("get_remote_player", "user_prof")
	if rp == null:
		sync.free()
		fake_net.free()
		return "RemotePlayer oluşamadı"

	var initial_pet: StringName = rp.get("character_id")
	if initial_pet != Config.DEFAULT_PET_ID:
		var err := "Başlangıçta varsayılan pet olmalı: %s" % initial_pet
		sync.free()
		fake_net.free()
		return err

	fake_net.call("simulate_player_profile", "user_prof", {"pet": &"shark", "acc": {&"head": &"hat_cap"}})
	var after_pet: StringName = rp.get("character_id")
	if after_pet != &"shark":
		var err := "Profil sonrası pet güncellenmedi: %s" % after_pet
		sync.free()
		fake_net.free()
		return err

	fake_net.call("simulate_player_profile", "user_prof", {"pet": &"bilinmeyen_pet_999", "acc": {}})
	var fallback_pet: StringName = rp.get("character_id")
	if fallback_pet != Config.DEFAULT_PET_ID:
		var err := "Bilinmeyen pet sonrası varsayılana dönmedi: %s" % fallback_pet
		sync.free()
		fake_net.free()
		return err

	sync.free()
	fake_net.free()
	return ""


func test_interpolation_between_states() -> String:
	_ensure_services()
	var fake_net: Node = FakeNet.new()
	var sync: Node = _setup_sync(fake_net)

	fake_net.call("simulate_player_joined", "user_interp", {})
	var rp: Node3D = sync.call("get_remote_player", "user_interp")
	if rp == null:
		sync.free()
		fake_net.free()
		return "RemotePlayer oluşmadı"

	# İlk durum: (0, 0, 0)
	fake_net.call("simulate_player_state", "user_interp", {"pos": Vector3(0, 0, 0), "yaw": 0.0, "anim": "walk"})
	var init_pos: Vector3 = rp.call("_get_current_pos")
	if not init_pos.is_equal_approx(Vector3(0, 0, 0)):
		sync.free()
		fake_net.free()
		return "İlk durum konumu hemen almalı: %s" % init_pos

	# 0.1 sn zaman ilerletip ikinci durumu gönder: (4, 0, 0)
	rp.call("_process", 0.1)
	fake_net.call("simulate_player_state", "user_interp", {"pos": Vector3(4, 0, 0), "yaw": 1.0, "anim": "walk"})

	# 0.05 sn daha ilerlet (render_time tam iki durumun ortası: factor = 0.5)
	rp.call("_process", 0.05)

	var x: float = (rp.call("_get_current_pos") as Vector3).x
	if x <= 0.5 or x >= 3.5:
		sync.free()
		fake_net.free()
		return "İki durum arasında interpolasyon yapılmadı (x=%f, beklenen ~2.0)" % x

	sync.free()
	fake_net.free()
	return ""


func test_large_jump_teleports() -> String:
	_ensure_services()
	var fake_net: Node = FakeNet.new()
	var sync: Node = _setup_sync(fake_net)

	fake_net.call("simulate_player_joined", "user_jump", {})
	var rp: Node3D = sync.call("get_remote_player", "user_jump")
	if rp == null:
		sync.free()
		fake_net.free()
		return "RemotePlayer oluşmadı"

	fake_net.call("simulate_player_state", "user_jump", {"pos": Vector3(0, 0, 0), "yaw": 0.0, "anim": "idle"})
	# 5 metreden büyük sıçrama (ör. 12 m)
	fake_net.call("simulate_player_state", "user_jump", {"pos": Vector3(12, 0, 0), "yaw": 0.0, "anim": "idle"})

	var pos: Vector3 = rp.call("_get_current_pos")
	if not pos.is_equal_approx(Vector3(12, 0, 0)):
		sync.free()
		fake_net.free()
		return "5 metreden büyük sıçramada ışınlanma gerçekleşmedi: %s" % pos

	sync.free()
	fake_net.free()
	return ""


func test_state_send_rate_limiting() -> String:
	_ensure_services()
	var fake_net: Node = FakeNet.new()
	var sync: Node = NetworkSync.new()
	var player_dummy: Node3D = Node3D.new()
	var root: Node = (Engine.get_main_loop() as SceneTree).root
	root.add_child(player_dummy)
	sync.set("player", player_dummy)
	sync.set("net", fake_net)
	root.add_child(sync)
	if not sync.is_node_ready():
		sync.call("_ready")

	fake_net.call("simulate_connected")
	fake_net.call("simulate_room_joined", "ortabahce-1")
	fake_net.call("clear_history")

	# 1 tick çalıştır: ilk durum gönderilmeli
	sync.call("_process", 0.1)
	var sent: Array = fake_net.get("sent_states")
	if sent.size() != 1:
		player_dummy.free()
		sync.free()
		fake_net.free()
		return "İlk tick durum gönderilmeliydi, gönderilen: %d" % sent.size()

	# 2. ve 3. tick: Oyuncu hareket etmedi, yeni gönderim OLMAMALI
	sync.call("_process", 0.1)
	sync.call("_process", 0.1)
	if sent.size() != 1:
		player_dummy.free()
		sync.free()
		fake_net.free()
		return "Değişmeyen durumda her tick gönderilmemeliydi, gönderilen: %d" % sent.size()

	# Oyuncu 3 cm hareket etti (> 2 cm POS_EPSILON)
	player_dummy.position = Vector3(0.03, 0.0, 0.0)
	sync.call("_process", 0.1)
	if sent.size() != 2:
		player_dummy.free()
		sync.free()
		fake_net.free()
		return "Konum değiştiğinde durum gönderilmeliydi, gönderilen: %d" % sent.size()

	# 1.0 saniye bekle (heartbeat): hareket olmasa da en az saniyede bir gönderilmeli
	sync.call("_process", 1.05)
	if sent.size() != 3:
		player_dummy.free()
		sync.free()
		fake_net.free()
		return "1 saniye heartbeat sonrasında durum gönderilmeliydi, gönderilen: %d" % sent.size()

	player_dummy.free()
	sync.free()
	fake_net.free()
	return ""


func test_disconnect_clears_players_and_reconnects() -> String:
	_ensure_services()
	var fake_net: Node = FakeNet.new()
	var sync: Node = _setup_sync(fake_net)

	fake_net.call("simulate_connected")
	fake_net.call("simulate_room_joined", "ortabahce-1")
	fake_net.call("simulate_player_joined", "user_dc1", {})
	fake_net.call("simulate_player_joined", "user_dc2", {})

	if (sync.call("get_remote_players") as Dictionary).size() != 2:
		sync.free()
		fake_net.free()
		return "Başlangıçta 2 oyuncu olmalıydı"

	# Bağlantı koptu: tüm uzak oyuncular silinmeli
	fake_net.call("simulate_disconnected", "test dc")
	if not (sync.call("get_remote_players") as Dictionary).is_empty():
		sync.free()
		fake_net.free()
		return "Disconnected sonrası uzak oyuncular temizlenmedi"

	# İlk bekleme (RECONNECT_DELAY) dolmadan yeniden bağlanma çağrısı OLMAMALI
	var first_delay: float = float(sync.get_script().get("RECONNECT_DELAY"))
	var initial_calls: int = int(fake_net.get("connect_calls"))
	sync.call("_process", first_delay - 1.0)
	if int(fake_net.get("connect_calls")) != initial_calls:
		sync.free()
		fake_net.free()
		return "ilk bekleme dolmadan yeniden bağlanma denenmemeli"

	# Bekleme dolunca yeniden bağlanma çağrılmalı
	sync.call("_process", 1.2)
	if int(fake_net.get("connect_calls")) <= initial_calls:
		sync.free()
		fake_net.free()
		return "bekleme dolunca yeniden bağlanma denenmedi"

	sync.free()
	fake_net.free()
	return ""


func test_main_scene_integration() -> String:
	_ensure_services()
	var scene: PackedScene = load("res://scenes/main.tscn")
	if scene == null:
		return "main.tscn yüklenemedi"
	var main_inst: Node = scene.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(main_inst)
	if not main_inst.is_node_ready():
		main_inst.call("_ready")

	var sync: Node = main_inst.get_node_or_null("NetworkSync")
	if sync == null:
		main_inst.free()
		return "main.tscn içinde NetworkSync bulunamadı"

	# Bir uzak oyuncu ekle
	var fake_net: Node = FakeNet.new()
	sync.set("net", fake_net)
	fake_net.call("simulate_connected")
	fake_net.call("simulate_room_joined", "ortabahce-1")
	fake_net.call("simulate_player_joined", "remote_chat_peer", {})

	# main_script::_find_player_node uzak oyuncuyu bulmalı
	var found: Node3D = main_inst.call("_find_player_node", "remote_chat_peer")
	if found == null:
		main_inst.free()
		fake_net.free()
		return "_find_player_node uzak oyuncuyu bulamadı"

	var bubble: Node = found.get_node_or_null("ChatBubble")
	if bubble == null:
		main_inst.free()
		fake_net.free()
		return "RemotePlayer altında ChatBubble bulunamadı"

	# Uzak oyuncudan PRESET chat gelince baloncuğu açılmalı
	Services.net.chat_received.emit(ChatMessage.from_dict({
		"kind": int(ChatMessage.Kind.PRESET),
		"payload": "selam",
		"sender_id": "remote_chat_peer"
	}))

	if not bubble.call("is_showing"):
		main_inst.free()
		fake_net.free()
		return "Uzak oyuncunun chat baloncuğu mesajı göstermedi"

	# Uzak oyuncudan EMOTE gelince emote oynamalı
	Services.net.chat_received.emit(ChatMessage.from_dict({
		"kind": int(ChatMessage.Kind.EMOTE),
		"payload": "wave",
		"sender_id": "remote_chat_peer"
	}))

	var vis: Node = found.get("visual")
	var anim_played: StringName = vis.call("current_logical") if vis != null else &""
	if anim_played != &"emote_wave":
		main_inst.free()
		fake_net.free()
		return "Uzak oyuncuda emote oynamadı: %s" % anim_played

	main_inst.free()
	fake_net.free()
	return ""
