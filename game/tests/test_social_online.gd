extends RefCounted
## Online sosyal iletişim yenilikleri testleri:
## - Türkçe küfür/spam filtresi + 80 karakter serbest sohbet + 📍 Konum pini
## - Kafa üstü oyuncu nicki + dokununca açılan Oyuncu Profili kartı + Arkadaş Ekle / İstek Kutusu
## - Kafe kapısından girince otomatik açılan Kafe Sohbet Salonu + Kalabalık Grup Kurma + Arkadaşlar arası Özel (DM)

const ChatFilter := preload("res://src/net/chat_filter.gd")
const FakeNet := preload("res://src/net/fake_network_service.gd")
const CafeZones := preload("res://src/world/cafe_social_zones.gd")
const CharacterRegistry := preload("res://src/characters/character_registry.gd")
const AccessoryRegistry := preload("res://src/characters/accessory_registry.gd")


func _ensure_registries() -> void:
	if Services.characters == null:
		Services.characters = CharacterRegistry.new()
		Services.characters.load_from_dir("res://data/characters")
	if Services.accessories == null:
		Services.accessories = AccessoryRegistry.new()
		Services.accessories.load_from_dir("res://data/accessories")


func test_turkish_chat_filter_and_length() -> String:
	for bad: String in ["selam amk", "0r0spu çocuğu", "SIKTIR git", "aaaaaaaabbbbbbbbb"]:
		var r_bad: Dictionary = ChatFilter.sanitize_free_text(bad)
		if bool(r_bad.get("ok", true)):
			return "Engellenmesi gereken mesaj geçti: %s" % bad
	for clean: String in ["Hokka'da kahve içelim mi?", "Sınav çok iyiydi!", "Ortabahçe'de buluşalım"]:
		var r_ok: Dictionary = ChatFilter.sanitize_free_text(clean)
		if not bool(r_ok.get("ok", false)):
			return "Temiz mesaj engellendi (%s): %s" % [clean, r_ok.get("reason", "")]
	var long_r: Dictionary = ChatFilter.sanitize_free_text("merhaba ".repeat(20))
	if not bool(long_r.get("ok", false)) or str(long_r["text"]).length() > ChatFilter.MAX_FREE_LEN:
		return "Uzun mesaj 80 karaktere kırpılmalıydı"
	return ""


func test_location_pin_roundtrip() -> String:
	var pin: ChatMessage = ChatMessage.location_pin("Hokka Kafe", Vector2(-69.0, -114.5), "campus")
	pin.sender_id = "u1"
	pin.sender_name = "Talha"
	var back: ChatMessage = ChatMessage.from_dict(pin.to_dict())
	if not back.has_pin or back.pin_place != "Hokka Kafe" or back.sender_name != "Talha":
		return "Konum pini roundtrip hatalı"
	if back.pin_pos.distance_to(Vector2(-69.0, -114.5)) > 0.2:
		return "Konum pini koordinatı bozuldu: %s" % back.pin_pos
	return ""


func test_player_overhead_nick_and_profile_friend_flow() -> String:
	_ensure_registries()
	var prev_net: Node = Services.net
	var fake: FakeNet = FakeNet.new()
	Services.net = fake

	var p_scene: PackedScene = load("res://scenes/player.tscn") as PackedScene
	var player: Node3D = p_scene.instantiate() as Node3D
	(Engine.get_main_loop() as SceneTree).root.add_child(player)
	player.call("set_display_name", "TalhaYTU")
	var nlbl: Label3D = player.get_node_or_null("NameLabel") as Label3D
	if nlbl == null or nlbl.text != "TalhaYTU":
		player.free()
		Services.net = prev_net
		fake.free()
		return "Oyuncu kafa üstü nick etiketi güncellenmedi"

	var cm_scene: PackedScene = load("res://scenes/ui/chat_menu.tscn") as PackedScene
	var chat_menu: Control = cm_scene.instantiate() as Control
	(Engine.get_main_loop() as SceneTree).root.add_child(chat_menu)
	if not chat_menu.is_node_ready():
		chat_menu.call("_ready")

	# Başka bir oyuncunun profilini aç ve arkadaş ekle
	chat_menu.call("open_player_profile", "peer_42", "Zeynep", "yeti")
	var popup: Control = chat_menu.get_node_or_null("PlayerProfilePopup") as Control
	if popup == null or not popup.visible:
		chat_menu.free()
		player.free()
		Services.net = prev_net
		fake.free()
		return "Oyuncu profil kartı açılmadı"

	var add_btn: Button = popup.find_child("PrimaryFriendButton", true, false) as Button
	if add_btn == null or not add_btn.text.contains("Arkadaş Ekle"):
		chat_menu.free()
		player.free()
		Services.net = prev_net
		fake.free()
		return "Profil kartında 'Arkadaş Ekle' butonu görünmedi"
	add_btn.pressed.emit()
	if fake.sent_socials.is_empty() or str(fake.sent_socials[-1].get("act", "")) != "friend_req":
		chat_menu.free()
		player.free()
		Services.net = prev_net
		fake.free()
		return "Arkadaşlık isteği ağa gönderilmedi"

	# Gelen arkadaşlık isteği İstek Kutusu rozetini yakmalı; kabul edilince Özel (DM) açılmalı
	fake.simulate_social({
		"friends": [],
		"incoming": [{"id": "peer_99", "name": "Mert"}],
		"outgoing": [{"id": "peer_42", "name": "Zeynep"}],
	})
	var badge: Label = chat_menu.find_child("SocialBadge", true, false) as Label
	if badge == null or not badge.visible or badge.text != "1":
		chat_menu.free()
		player.free()
		Services.net = prev_net
		fake.free()
		return "İstek kutusu bildirim rozeti güncellenmedi"

	fake.simulate_social({
		"friends": [{"id": "peer_42", "name": "Zeynep"}],
		"incoming": [],
		"outgoing": [],
	})
	chat_menu.call("_on_open_dm_from_profile", "peer_42", "Zeynep")
	var sent_dm: bool = chat_menu.call("send_free_text", "Merhaba Zeynep!")
	if not sent_dm or fake.sent_chats.is_empty() or fake.sent_chats[-1].channel != "dm:peer_42":
		chat_menu.free()
		player.free()
		Services.net = prev_net
		fake.free()
		return "Arkadaşla özel (DM) mesaj gönderilemedi"

	chat_menu.free()
	player.free()
	Services.net = prev_net
	fake.free()
	return ""


func test_cafe_door_auto_opens_cafe_chat() -> String:
	_ensure_registries()
	var prev_net: Node = Services.net
	var fake: FakeNet = FakeNet.new()
	Services.net = fake

	var cm_scene: PackedScene = load("res://scenes/ui/chat_menu.tscn") as PackedScene
	var chat_menu: Control = cm_scene.instantiate() as Control
	(Engine.get_main_loop() as SceneTree).root.add_child(chat_menu)
	if not chat_menu.is_node_ready():
		chat_menu.call("_ready")

	var zones: Node3D = CafeZones.new()
	zones.set("chat_menu", chat_menu)
	(Engine.get_main_loop() as SceneTree).root.add_child(zones)

	# Hokka Kafe kapısından içeri girince sohbet ekranı otomatik 'cafe' sekmesinde açılmalı!
	zones.call("check_position", Vector2(-69.0, -114.5))
	var ok_enter: bool = (
		chat_menu.call("is_panel_open")
		and str(chat_menu.get("active_tab")) == "cafe"
		and str(chat_menu.get("current_cafe_id")) == "hokka"
		and not fake.sent_socials.is_empty()
		and str(fake.sent_socials[-1].get("act", "")) == "enter_cafe"
	)
	# Kapıdan uzaklaşınca salondan çıkmalı
	zones.call("check_position", Vector2(0.0, 0.0))
	var ok_exit: bool = str(zones.get("active_cafe_id")).is_empty() and str(fake.sent_socials[-1].get("act", "")) == "leave_cafe"

	zones.free()
	chat_menu.free()
	Services.net = prev_net
	fake.free()
	if not ok_enter:
		return "Kafe kapısından girince kafe sohbet ekranı otomatik açılmadı"
	if not ok_exit:
		return "Kafeden uzaklaşınca salondan çıkış tetiklenmedi"
	return ""


func test_ytu_verified_and_visitor_profile_badges() -> String:
	_ensure_registries()
	var cm_scene: PackedScene = load("res://scenes/ui/chat_menu.tscn") as PackedScene
	var chat_menu: Control = cm_scene.instantiate() as Control
	(Engine.get_main_loop() as SceneTree).root.add_child(chat_menu)
	if not chat_menu.is_node_ready():
		chat_menu.call("_ready")

	chat_menu.call("open_player_profile", "ytu_1", "Talha", "kutbi", {
		"ytu": true,
		"role": "Bilgisayar Müh.",
		"bio": "ARTLAB Zirvesi'ndeyim!",
		"disc": 28,
	})
	var popup: Control = chat_menu.get_node_or_null("PlayerProfilePopup") as Control
	var v_lbl: Label = popup.find_child("VerificationLabel", true, false) as Label
	var r_lbl: Label = popup.find_child("ProfileRoleLabel", true, false) as Label
	var ok_ytu: bool = v_lbl != null and v_lbl.text.contains("DOĞRULANMIŞ YTÜ") and r_lbl != null and r_lbl.text.contains("Bilgisayar Müh.")

	chat_menu.call("open_player_profile", "vis_2", "EceYKS", "birb", {
		"ytu": false,
		"role": "🎯 YKS Adayı (Hedef YTÜ)",
		"bio": "Davutpaşa kampüsünü geziyorum",
		"disc": 7,
	})
	var ok_vis: bool = v_lbl != null and v_lbl.text.contains("KAMPÜS MİSAFİRİ") and r_lbl != null and r_lbl.text.contains("YKS Adayı")
	chat_menu.free()
	if not ok_ytu or not ok_vis:
		return "YTÜ doğrulanmış öğrenci ve YKS misafir profil rozetleri beklendiği gibi oluşmadı"
	return ""
