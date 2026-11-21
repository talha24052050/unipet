extends RefCounted
## Hazır cümleler + emote kataloğu, chat menüsü ve chat baloncuğu testleri.

const ChatCatalog := preload("res://src/net/chat_catalog.gd")
const OfflineNetworkService := preload("res://src/net/offline_network_service.gd")
const CharacterRegistry := preload("res://src/characters/character_registry.gd")
const AccessoryRegistry := preload("res://src/characters/accessory_registry.gd")

const VALID_EMOTE_ANIMS: Array[StringName] = [
	&"emote_wave",
	&"emote_jump",
	&"emote_yes",
	&"emote_no",
	&"emote_dance"
]


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


func test_catalog_loads() -> String:
	var catalog: RefCounted = ChatCatalog.new()
	if catalog.presets().is_empty():
		return "Katalog preset listesi boş"
	if catalog.emotes().is_empty():
		return "Katalog emote listesi boş"
	return ""


func test_preset_count_between_12_and_16() -> String:
	var catalog: RefCounted = ChatCatalog.new()
	var count: int = catalog.presets().size()
	if count < 12 or count > 16:
		return "Preset sayısı 12-16 arasında olmalı, %d bulundu" % count
	return ""


func test_unknown_ids_return_empty() -> String:
	var catalog: RefCounted = ChatCatalog.new()
	if not catalog.preset_text("sahte_id_999").is_empty():
		return "Bilinmeyen preset id boş dönmedi: %s" % catalog.preset_text("sahte_id_999")
	if catalog.emote_anim("sahte_id_999") != &"":
		return "Bilinmeyen emote id boş dönmedi: %s" % catalog.emote_anim("sahte_id_999")
	return ""


func test_all_emote_anims_valid() -> String:
	var catalog: RefCounted = ChatCatalog.new()
	for emote: Dictionary in catalog.emotes():
		var anim: StringName = emote.get("anim", &"")
		if not VALID_EMOTE_ANIMS.has(anim):
			return "Geçersiz emote animasyonu: %s (beklenenler: %s)" % [anim, str(VALID_EMOTE_ANIMS)]
		var label: String = emote.get("label", "")
		if label.strip_edges().is_empty():
			return "Emote etiketi boş: %s" % str(emote)
	return ""


func test_chat_menu_scene_loads() -> String:
	_ensure_services()
	var scene: PackedScene = load("res://scenes/ui/chat_menu.tscn")
	if scene == null:
		return "chat_menu.tscn yüklenemedi"
	var inst: Node = scene.instantiate()
	if inst == null:
		return "chat_menu.tscn instantiate edilemedi"

	(Engine.get_main_loop() as SceneTree).root.add_child(inst)
	if not inst.is_node_ready():
		inst.call("_ready")

	var chat_btn: Button = inst.get_node_or_null("ChatButton")
	if chat_btn == null:
		inst.free()
		return "ChatButton düğümü bulunamadı"

	var min_size: Vector2 = chat_btn.custom_minimum_size
	if min_size.x < 96.0 or min_size.y < 96.0:
		var err := "ChatButton custom_minimum_size ≥ 96 px olmalı: %s" % min_size
		inst.free()
		return err

	var font_size: int = chat_btn.get_theme_font_size("font_size")
	if font_size < 28:
		var err := "ChatButton yazı boyutu ≥ 28 px olmalı: %d" % font_size
		inst.free()
		return err

	var presets_tab_btn: Button = inst.get_node_or_null("%PresetsTabButton")
	if presets_tab_btn != null and presets_tab_btn.custom_minimum_size.y < 96.0:
		inst.free()
		return "PresetsTabButton yüksekliği ≥ 96 px olmalı"

	var emotes_tab_btn: Button = inst.get_node_or_null("%EmotesTabButton")
	if emotes_tab_btn != null and emotes_tab_btn.custom_minimum_size.y < 96.0:
		inst.free()
		return "EmotesTabButton yüksekliği ≥ 96 px olmalı"

	# Preset butonlarının mobil boyut kontrolü
	var presets_list: VBoxContainer = inst.get_node_or_null("%PresetsList")
	if presets_list != null:
		for child: Node in presets_list.get_children():
			if child is Button:
				if (child as Button).custom_minimum_size.y < 96.0:
					inst.free()
					return "Preset butonu yüksekliği ≥ 96 px olmalı"
				if (child as Button).get_theme_font_size("font_size") < 28:
					inst.free()
					return "Preset butonu yazı boyutu ≥ 28 px olmalı"

	# Emote butonlarının mobil boyut kontrolü
	var emotes_grid: GridContainer = inst.get_node_or_null("%EmotesGrid")
	if emotes_grid != null:
		for child: Node in emotes_grid.get_children():
			if child is Button:
				if (child as Button).custom_minimum_size.y < 96.0:
					inst.free()
					return "Emote butonu yüksekliği ≥ 96 px olmalı"
				if (child as Button).get_theme_font_size("font_size") < 28:
					inst.free()
					return "Emote butonu yazı boyutu ≥ 28 px olmalı"

	inst.free()
	return ""


func test_chat_menu_cooldown_and_spam_prevention() -> String:
	_ensure_services()
	var scene: PackedScene = load("res://scenes/ui/chat_menu.tscn")
	var inst: Node = scene.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(inst)
	if not inst.is_node_ready():
		inst.call("_ready")

	# İlk gönderim başarılı olmalı
	var sent1: bool = inst.call("send_preset", "selam")
	if not sent1:
		inst.free()
		return "İlk preset gönderimi başarısız oldu"

	var cd: float = float(inst.call("get_cooldown"))
	if cd <= 0.0:
		inst.free()
		return "Cooldown süresi başlamadı"

	# Cooldown sırasında ikinci gönderim engellenmeli (spam önleme)
	var sent2: bool = inst.call("send_preset", "selam")
	if sent2:
		inst.free()
		return "Cooldown varken ikinci mesaj gönderildi (spam önleme çalışmadı)"

	var chat_btn: Button = inst.get_node_or_null("ChatButton")
	if chat_btn != null and not chat_btn.disabled:
		inst.free()
		return "Cooldown süresince ChatButton pasif olmalı"

	# Süre ilerletilince butonlar tekrar aktifleşmeli
	inst.call("_process", 1.6)
	var cd_after: float = float(inst.call("get_cooldown"))
	if cd_after > 0.0:
		inst.free()
		return "1.6 sn sonra cooldown sıfırlanmadı: %f" % cd_after

	if chat_btn != null and chat_btn.disabled:
		inst.free()
		return "Cooldown bitince ChatButton aktifleşmedi"

	var sent3: bool = inst.call("send_preset", "selam")
	if not sent3:
		inst.free()
		return "Cooldown bitince tekrar mesaj gönderilemedi"

	inst.free()
	return ""


func test_chat_bubble_behavior() -> String:
	var scene: PackedScene = load("res://scenes/ui/chat_bubble.tscn")
	if scene == null:
		return "chat_bubble.tscn yüklenemedi"
	var bubble: Node3D = scene.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(bubble)
	if not bubble.is_node_ready():
		bubble.call("_ready")

	if bubble.call("is_showing"):
		bubble.free()
		return "Başlangıçta baloncuk görünür olmamalı"

	bubble.call("show_message", "Selamlar!")
	if not bubble.call("is_showing"):
		bubble.free()
		return "show_message sonrası baloncuk görünür olmadı"
	var text1: String = bubble.call("current_text")
	if text1 != "Selamlar!":
		bubble.free()
		return "Baloncuk metni beklenen değil: %s" % text1

	# Yeni mesaj eskisinin yerini almalı
	bubble.call("show_message", "Yeni mesaj")
	var text2: String = bubble.call("current_text")
	if text2 != "Yeni mesaj":
		bubble.free()
		return "Yeni mesaj eskisinin yerini almadı: %s" % text2

	# 4 saniye sonra kaybolmalı
	bubble.call("_process", 4.1)
	if bubble.call("is_showing"):
		bubble.free()
		return "4 sn sonra baloncuk kaybolmadı"

	bubble.free()
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

	var chat_menu: Node = main_inst.get_node_or_null("UI/ChatMenu")
	if chat_menu == null:
		main_inst.free()
		return "main.tscn içinde UI/ChatMenu bulunamadı"
	if not chat_menu.is_node_ready():
		chat_menu.call("_ready")

	var player: Node = main_inst.get_node_or_null("Player")
	if player == null:
		main_inst.free()
		return "main.tscn içinde Player bulunamadı"
	if not player.is_node_ready():
		player.call("_ready")

	var bubble: Node = player.get_node_or_null("ChatBubble")
	if bubble == null:
		main_inst.free()
		return "Player altında ChatBubble bulunamadı"
	if not bubble.is_node_ready():
		bubble.call("_ready")

	# PRESET mesajı gelince baloncuğun gösterilmesi testi
	Services.net.send_chat(ChatMessage.preset("selam"))
	if not bubble.call("is_showing"):
		main_inst.free()
		return "ChatMessage.preset sonrası baloncuk görünür olmadı"
	var b_text: String = bubble.call("current_text")
	if b_text != "Selam!":
		main_inst.free()
		return "ChatMessage.preset sonrası baloncuk metni yanlış: %s" % b_text

	# EMOTE mesajı gelince animasyonun tetiklenmesi testi
	Services.net.send_chat(ChatMessage.emote("wave"))
	var visual: Node = player.get("visual")
	if visual == null:
		visual = player.get_node_or_null("PetVisual")
	if visual == null:
		main_inst.free()
		return "Player altında visual bulunamadı"
	var anim: StringName = visual.call("current_logical")
	if anim != &"emote_wave":
		main_inst.free()
		return "ChatMessage.emote sonrası emote oynamadı: %s" % anim

	# Bilinmeyen id'li sahte mesaj gelirse baloncuğun güncellenmemesi testi
	Services.net.send_chat(ChatMessage.preset("sahte_id_xyz"))
	if bubble.call("current_text") == "sahte_id_xyz":
		main_inst.free()
		return "Bilinmeyen preset id baloncukta gösterilmemeliydi"

	# Config.FREE_CHAT_ENABLED == false iken FREE chat mesajının gösterilmemesi testi
	Services.net.send_chat(ChatMessage.free_text("Serbest chat deneme"))
	if bubble.call("current_text") == "Serbest chat deneme":
		main_inst.free()
		return "FREE_CHAT_ENABLED false iken free text gösterilmemeliydi"

	main_inst.free()
	return ""
