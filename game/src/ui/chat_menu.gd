extends Control
## Çok kanallı Sosyal & Sohbet Merkezi:
## - Kampüs Geneli (serbest yazılı sohbet + Türkçe filtre + hazır cümleler + emote + 📍 Konum/Buluşma pini)
## - ☕ Kafe Salonları (kafe kapısından girince otomatik açılır; içeridekilerin profilini açıp arkadaş ekleme)
## - 👥 Kalabalık / Özel Gruplar (grup kurma, katılma, grup içi sohbet)
## - 🔒 Özel Mesaj (DM — yalnızca kabul edilmiş arkadaşlar arasında)
## - 🔔 İstek Kutusu & Profilim (gelen arkadaşlık isteklerini kabul/reddetme + kendi nickini düzenleme)

const ChatCatalog := preload("res://src/net/chat_catalog.gd")
const ChatFilter := preload("res://src/net/chat_filter.gd")
const LocalProfile := preload("res://src/core/local_profile.gd")
const ProfilePopupScript := preload("res://src/ui/player_profile_popup.gd")
const CafeZones := preload("res://src/world/cafe_social_zones.gd")

const COOLDOWN_TIME: float = 1.5
const MAX_HISTORY_PER_CHANNEL: int = 45
const LIVE_FEED_MAX: int = 4
const LIVE_FEED_TTL: float = 14.0
const PLACES_PATH: String = "res://data/places.json"

var _catalog: RefCounted
var _cooldown: float = 0.0
var _preset_buttons: Array[Button] = []
var _emote_buttons: Array[Button] = []

## Seçili sekme: "campus" | "cafe" | "group" | "dm" | "inbox"
var active_tab: String = "campus"
var current_cafe_id: String = ""
var current_cafe_name: String = ""
var current_group_id: String = ""
var current_dm_peer_id: String = ""
var current_dm_peer_name: String = ""
## Alt içerik görünümü: "feed" | "presets" | "emotes"
var _sub_mode: String = "feed"
var _unread_dms: int = 0
## channel_key -> Array[ChatMessage]
var _history: Dictionary = {}
var _live_items: Array[Dictionary] = []  # [{"node": Control, "ttl": float}]
var _places_cache: Array = []

@onready var _chat_button: Button = %ChatButton
@onready var _panel_overlay: Control = %PanelOverlay
@onready var _backdrop: Control = %Backdrop
@onready var _presets_tab_button: Button = %PresetsTabButton
@onready var _emotes_tab_button: Button = %EmotesTabButton
@onready var _close_button: Button = %CloseButton
@onready var _presets_scroll: ScrollContainer = %PresetsScroll
@onready var _emotes_scroll: ScrollContainer = %EmotesScroll
@onready var _presets_list: VBoxContainer = %PresetsList
@onready var _emotes_grid: GridContainer = %EmotesGrid

var _main_box: VBoxContainer
var _header_box: HBoxContainer
var _feed_mode_btn: Button
var _channel_bar: HBoxContainer
var _tab_btns: Dictionary = {}
var _context_box: VBoxContainer
var _feed_scroll: ScrollContainer
var _feed_list: VBoxContainer
var _inbox_scroll: ScrollContainer
var _inbox_box: VBoxContainer
var _composer_box: VBoxContainer
var _free_input: LineEdit
var _send_btn: Button
var _pin_btn: Button
var _status_lbl: Label
var _badge_lbl: Label
var _hud_feed_box: VBoxContainer
var _profile_popup: Control


func _ready() -> void:
	_ensure_nodes()
	if _catalog == null:
		_catalog = ChatCatalog.new()
	_load_places_cache()
	_build_social_extensions()
	_populate_items()
	_connect_signals()
	if _panel_overlay != null:
		_panel_overlay.add_to_group(&"joystick_blocker")
	close_panel()
	_refresh_all_ui()


func _ensure_nodes() -> void:
	if _chat_button == null:
		_chat_button = get_node_or_null("%ChatButton") if has_node("%ChatButton") else get_node_or_null("ChatButton")
	if _panel_overlay == null:
		_panel_overlay = get_node_or_null("%PanelOverlay") if has_node("%PanelOverlay") else get_node_or_null("PanelOverlay")
	if _backdrop == null:
		_backdrop = get_node_or_null("%Backdrop") if has_node("%Backdrop") else get_node_or_null("PanelOverlay/Backdrop")
	if _presets_tab_button == null:
		_presets_tab_button = get_node_or_null("%PresetsTabButton") if has_node("%PresetsTabButton") else get_node_or_null("PanelOverlay/PanelContainer/MarginContainer/MainBox/HeaderBox/PresetsTabButton")
	if _emotes_tab_button == null:
		_emotes_tab_button = get_node_or_null("%EmotesTabButton") if has_node("%EmotesTabButton") else get_node_or_null("PanelOverlay/PanelContainer/MarginContainer/MainBox/HeaderBox/EmotesTabButton")
	if _close_button == null:
		_close_button = get_node_or_null("%CloseButton") if has_node("%CloseButton") else get_node_or_null("PanelOverlay/PanelContainer/MarginContainer/MainBox/HeaderBox/CloseButton")
	if _presets_scroll == null:
		_presets_scroll = get_node_or_null("%PresetsScroll") if has_node("%PresetsScroll") else get_node_or_null("PanelOverlay/PanelContainer/MarginContainer/MainBox/PresetsScroll")
	if _emotes_scroll == null:
		_emotes_scroll = get_node_or_null("%EmotesScroll") if has_node("%EmotesScroll") else get_node_or_null("PanelOverlay/PanelContainer/MarginContainer/MainBox/EmotesScroll")
	if _presets_list == null:
		_presets_list = get_node_or_null("%PresetsList") if has_node("%PresetsList") else get_node_or_null("PanelOverlay/PanelContainer/MarginContainer/MainBox/PresetsScroll/PresetsList")
	if _emotes_grid == null:
		_emotes_grid = get_node_or_null("%EmotesGrid") if has_node("%EmotesGrid") else get_node_or_null("PanelOverlay/PanelContainer/MarginContainer/MainBox/EmotesScroll/EmotesGrid")
	if _main_box == null and _panel_overlay != null:
		_main_box = _panel_overlay.get_node_or_null("PanelContainer/MarginContainer/MainBox") as VBoxContainer
	if _header_box == null and _main_box != null:
		_header_box = _main_box.get_node_or_null("HeaderBox") as HBoxContainer


func _load_places_cache() -> void:
	if not _places_cache.is_empty() or not FileAccess.file_exists(PLACES_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PLACES_PATH))
	if parsed is Dictionary:
		_places_cache = (parsed as Dictionary).get("places", [])


func _build_social_extensions() -> void:
	if _main_box == null or _channel_bar != null:
		return

	# 1) Sağ-alt kibar canlı sohbet akışı (Ye/Dinlen/Oyna sütununun solunda, sıfır çakışma!)
	_hud_feed_box = VBoxContainer.new()
	_hud_feed_box.name = "HudLiveFeed"
	_hud_feed_box.anchor_left = 1.0
	_hud_feed_box.anchor_top = 1.0
	_hud_feed_box.anchor_right = 1.0
	_hud_feed_box.anchor_bottom = 1.0
	_hud_feed_box.offset_left = -568.0
	_hud_feed_box.offset_top = -250.0
	_hud_feed_box.offset_right = -152.0
	_hud_feed_box.offset_bottom = -26.0
	_hud_feed_box.alignment = BoxContainer.ALIGNMENT_END
	_hud_feed_box.add_theme_constant_override("separation", 6)
	_hud_feed_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud_feed_box)
	move_child(_hud_feed_box, 0)

	if _panel_overlay != null:
		_panel_overlay.z_index = 25

	# 2) ChatButton üstünde kırmızı bildirim rozeti (İstek Kutusu + okunmamış özel mesajlar)
	if _chat_button != null:
		_badge_lbl = Label.new()
		_badge_lbl.name = "SocialBadge"
		_badge_lbl.visible = false
		_badge_lbl.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
		_badge_lbl.vertical_alignment = VerticalAlignment.VERTICAL_ALIGNMENT_CENTER
		_badge_lbl.position = Vector2(58, -6)
		_badge_lbl.custom_minimum_size = Vector2(36, 32)
		_badge_lbl.add_theme_font_size_override("font_size", 18)
		_badge_lbl.add_theme_color_override("font_color", Color.WHITE)
		var bst: StyleBoxFlat = StyleBoxFlat.new()
		bst.bg_color = Color(0.90, 0.20, 0.24, 0.98)
		bst.set_corner_radius_all(16)
		_badge_lbl.add_theme_stylebox_override("normal", bst)
		_chat_button.add_child(_badge_lbl)

	# 3) Üst kanal şeridi: Kampüs | Kafe | Gruplar | Özel | İstekler
	_channel_bar = HBoxContainer.new()
	_channel_bar.name = "ChannelBar"
	_channel_bar.add_theme_constant_override("separation", 6)
	_main_box.add_child(_channel_bar)
	_main_box.move_child(_channel_bar, 0)

	var tab_defs: Array = [
		["campus", "🌍 Kampüs"],
		["cafe", "☕ Kafe"],
		["group", "👥 Grup"],
		["dm", "🔒 Özel"],
		["inbox", "🔔 İstekler"],
	]
	for td: Array in tab_defs:
		var tid: String = str(td[0])
		var tb: Button = Button.new()
		tb.name = "Tab_%s" % tid
		tb.text = str(td[1])
		tb.custom_minimum_size = Vector2(0, 56)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.add_theme_font_size_override("font_size", 20)
		tb.pressed.connect(func() -> void:
			Sfx.play(&"ui_click")
			select_tab(tid))
		_channel_bar.add_child(tb)
		_tab_btns[tid] = tb

	var top_close: Button = Button.new()
	top_close.name = "TopBarCloseButton"
	top_close.text = "✕"
	top_close.custom_minimum_size = Vector2(56, 56)
	top_close.add_theme_font_size_override("font_size", 22)
	top_close.pressed.connect(_on_close_button_pressed)
	_channel_bar.add_child(top_close)

	# 4) HeaderBox içine "💬 Sohbet" görünüm butonu ekle (Cümleler ve Emote'lar 96px olarak korunur!)
	if _header_box != null:
		_feed_mode_btn = Button.new()
		_feed_mode_btn.name = "FeedModeButton"
		_feed_mode_btn.text = "💬 Sohbet"
		_feed_mode_btn.custom_minimum_size = Vector2(0, 96)
		_feed_mode_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_feed_mode_btn.add_theme_font_size_override("font_size", 28)
		_feed_mode_btn.pressed.connect(func() -> void:
			Sfx.play(&"ui_click")
			show_feed_mode())
		_header_box.add_child(_feed_mode_btn)
		_header_box.move_child(_feed_mode_btn, 0)

	# 5) Dinamik bağlam çubuğu (Kafe içeridekiler / Grup oluştur & katıl / Arkadaş seçimi)
	_context_box = VBoxContainer.new()
	_context_box.name = "ContextBox"
	_context_box.add_theme_constant_override("separation", 6)
	_main_box.add_child(_context_box)
	_main_box.move_child(_context_box, 2)

	# 6) Canlı mesaj geçmişi (ChatFeedScroll)
	_feed_scroll = ScrollContainer.new()
	_feed_scroll.name = "ChatFeedScroll"
	_feed_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_feed_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_main_box.add_child(_feed_scroll)
	_main_box.move_child(_feed_scroll, 3)

	_feed_list = VBoxContainer.new()
	_feed_list.name = "ChatFeedList"
	_feed_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_feed_list.add_theme_constant_override("separation", 8)
	_feed_scroll.add_child(_feed_list)

	# 7) İstek Kutusu & Profilim sekmesi görünümü
	_inbox_scroll = ScrollContainer.new()
	_inbox_scroll.name = "InboxScroll"
	_inbox_scroll.visible = false
	_inbox_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_inbox_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_main_box.add_child(_inbox_scroll)

	_inbox_box = VBoxContainer.new()
	_inbox_box.name = "InboxBox"
	_inbox_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inbox_box.add_theme_constant_override("separation", 10)
	_inbox_scroll.add_child(_inbox_box)

	# 8) Alt serbest mesaj yazma + 📍 Konum Pini çubuğu
	_composer_box = VBoxContainer.new()
	_composer_box.name = "ComposerBox"
	_composer_box.add_theme_constant_override("separation", 6)
	_main_box.add_child(_composer_box)

	_status_lbl = Label.new()
	_status_lbl.name = "FilterStatusLabel"
	_status_lbl.visible = false
	_status_lbl.add_theme_font_size_override("font_size", 18)
	_status_lbl.add_theme_color_override("font_color", Color(1.0, 0.78, 0.36))
	_composer_box.add_child(_status_lbl)

	var comp_row: HBoxContainer = HBoxContainer.new()
	comp_row.add_theme_constant_override("separation", 8)
	_composer_box.add_child(comp_row)

	_free_input = LineEdit.new()
	_free_input.name = "FreeChatInput"
	_free_input.placeholder_text = "Mesaj yaz (maks. 80 kr)..."
	_free_input.max_length = ChatFilter.MAX_FREE_LEN
	_free_input.custom_minimum_size = Vector2(0, 64)
	_free_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_free_input.add_theme_font_size_override("font_size", 22)
	_free_input.text_submitted.connect(func(_t: String) -> void: send_free_from_input())
	comp_row.add_child(_free_input)

	_send_btn = Button.new()
	_send_btn.name = "SendFreeButton"
	_send_btn.text = "Gönder"
	_send_btn.custom_minimum_size = Vector2(112, 64)
	_send_btn.add_theme_font_size_override("font_size", 22)
	_send_btn.pressed.connect(func() -> void: send_free_from_input())
	comp_row.add_child(_send_btn)

	_pin_btn = Button.new()
	_pin_btn.name = "PinLocationButton"
	_pin_btn.text = "📍 Konum"
	_pin_btn.custom_minimum_size = Vector2(124, 64)
	_pin_btn.add_theme_font_size_override("font_size", 20)
	_pin_btn.pressed.connect(func() -> void: send_location_pin())
	comp_row.add_child(_pin_btn)

	# 9) Oyuncu Profili açılır penceresi (3B dünyada veya sohbette isme dokununca açılır)
	_profile_popup = ProfilePopupScript.new()
	_profile_popup.name = "PlayerProfilePopup"
	_profile_popup.z_index = 35
	_profile_popup.connect("open_dm_requested", _on_open_dm_from_profile)
	add_child(_profile_popup)


func _connect_signals() -> void:
	if _chat_button != null and not _chat_button.pressed.is_connected(_on_chat_button_pressed):
		_chat_button.pressed.connect(_on_chat_button_pressed)
	if _close_button != null and not _close_button.pressed.is_connected(_on_close_button_pressed):
		_close_button.pressed.connect(_on_close_button_pressed)
	if _presets_tab_button != null and not _presets_tab_button.pressed.is_connected(_on_presets_tab_pressed):
		_presets_tab_button.pressed.connect(_on_presets_tab_pressed)
	if _emotes_tab_button != null and not _emotes_tab_button.pressed.is_connected(_on_emotes_tab_pressed):
		_emotes_tab_button.pressed.connect(_on_emotes_tab_pressed)
	if _backdrop != null and not _backdrop.gui_input.is_connected(_on_backdrop_gui_input):
		_backdrop.gui_input.connect(_on_backdrop_gui_input)
	if Services.net != null:
		if not Services.net.chat_received.is_connected(_on_chat_received):
			Services.net.chat_received.connect(_on_chat_received)
		if Services.net.has_signal("social_updated") and not Services.net.social_updated.is_connected(_on_social_updated):
			Services.net.social_updated.connect(_on_social_updated)
	# Sahnedeki PetInteraction sinyalini bağla (3B oyuncuya dokununca profil kartı açılsın)
	var scene_root: Node = get_tree().current_scene if is_inside_tree() else null
	if scene_root == null and get_parent() != null and get_parent().get_parent() != null:
		scene_root = get_parent().get_parent()
	if scene_root != null:
		var pi: Node = scene_root.get_node_or_null("PetInteraction")
		if pi != null and pi.has_signal("profile_requested") and not pi.is_connected("profile_requested", open_player_profile):
			pi.connect("profile_requested", open_player_profile)


func open_player_profile(pid: String, dname: String, pet_id: String = "", extra: Dictionary = {}) -> void:
	_ensure_nodes()
	_build_social_extensions()
	var merged: Dictionary = extra.duplicate()
	if merged.is_empty():
		var my_id: String = Services.net.local_player_id() if Services.net != null else ""
		if not my_id.is_empty() and pid == my_id:
			var prof: RefCounted = LocalProfile.load_or_default()
			if pet_id.is_empty():
				pet_id = str(prof.get("pet_id"))
			merged = {
				"ytu": bool(prof.get("is_ytu_verified")),
				"role": str(prof.get("role_tag")),
				"bio": str(prof.get("bio")),
				"disc": (prof.get("discovered") as PackedStringArray).size(),
			}
		else:
			var ns: Node = _find_scene_node("NetworkSync")
			if ns != null and ns.has_method("get_remote_player"):
				var rp: Node = ns.call("get_remote_player", pid)
				if rp != null:
					if pet_id.is_empty() and "character_id" in rp:
						pet_id = str(rp.get("character_id"))
					if dname.is_empty() and "display_name" in rp:
						dname = str(rp.get("display_name"))
					merged = {
						"ytu": bool(rp.get("is_ytu_verified")) if "is_ytu_verified" in rp else false,
						"role": str(rp.get("role_tag")) if "role_tag" in rp else "",
						"bio": str(rp.get("bio")) if "bio" in rp else "",
						"disc": int(rp.get("discovered_count")) if "discovered_count" in rp else 0,
					}
	if _profile_popup != null and _profile_popup.has_method("show_for_player"):
		_profile_popup.call("show_for_player", pid, dname, pet_id, merged)


func _on_open_dm_from_profile(peer_id: String, peer_name: String) -> void:
	current_dm_peer_id = peer_id
	current_dm_peer_name = peer_name
	_unread_dms = 0
	open_panel()
	select_tab("dm")


func on_cafe_entered(cafe_id: String, cafe_name: String) -> void:
	current_cafe_id = cafe_id
	current_cafe_name = cafe_name
	Sfx.play(&"ui_click")
	open_panel()
	select_tab("cafe")
	_show_status("☕ %s salonuna girdin — içerideki herkesle sohbet edebilirsin!" % cafe_name, Color(0.55, 0.95, 0.72))


func on_cafe_exited(_cafe_id: String) -> void:
	current_cafe_id = ""
	current_cafe_name = ""
	if active_tab == "cafe":
		select_tab("campus")
	else:
		_refresh_all_ui()


func select_tab(tab_id: String) -> void:
	active_tab = tab_id
	if tab_id == "dm":
		_unread_dms = 0
		if current_dm_peer_id.is_empty() and Services.net != null:
			var frs: Array = Services.net.social_state.get("friends", [])
			if not frs.is_empty():
				current_dm_peer_id = str(frs[0].get("id", ""))
				current_dm_peer_name = str(frs[0].get("name", current_dm_peer_id))
	if tab_id != "inbox" and _sub_mode != "feed":
		_sub_mode = "feed"
	_refresh_all_ui()


func show_feed_mode() -> void:
	_sub_mode = "feed"
	if active_tab == "inbox":
		active_tab = "campus"
	_refresh_all_ui()


func show_presets_tab() -> void:
	_ensure_nodes()
	_sub_mode = "presets"
	if active_tab == "inbox":
		active_tab = "campus"
	_refresh_all_ui()


func show_emotes_tab() -> void:
	_ensure_nodes()
	_sub_mode = "emotes"
	if active_tab == "inbox":
		active_tab = "campus"
	_refresh_all_ui()


func _active_channel_key() -> String:
	match active_tab:
		"cafe":
			return ("cafe:%s" % current_cafe_id) if not current_cafe_id.is_empty() else "campus"
		"group":
			return ("group:%s" % current_group_id) if not current_group_id.is_empty() else ""
		"dm":
			return ("dm:%s" % current_dm_peer_id) if not current_dm_peer_id.is_empty() else ""
		_:
			return "campus"


func _storage_key_for_incoming(msg: ChatMessage) -> String:
	if msg.channel.begins_with("dm:"):
		var my_id: String = Services.net.local_player_id() if Services.net != null else "local"
		var peer: String = msg.channel.trim_prefix("dm:")
		if peer == my_id:
			peer = msg.sender_id
		return "dm:%s" % peer
	return msg.channel if not msg.channel.is_empty() else "campus"


func _on_chat_button_pressed() -> void:
	Sfx.play(&"ui_click")
	toggle_panel()


func _on_close_button_pressed() -> void:
	Sfx.play(&"ui_click")
	close_panel()


func _on_presets_tab_pressed() -> void:
	Sfx.play(&"ui_click")
	show_presets_tab()


func _on_emotes_tab_pressed() -> void:
	Sfx.play(&"ui_click")
	show_emotes_tab()


func _on_social_updated(data: Dictionary) -> void:
	if data.has("joined_group"):
		current_group_id = str(data["joined_group"])
	elif bool(data.get("left_group", false)):
		current_group_id = ""
	if data.has("text") and not str(data["text"]).is_empty():
		var ok: bool = bool(data.get("ok", true))
		_show_status(str(data["text"]), Color(0.55, 0.95, 0.72) if ok else Color(1.0, 0.55, 0.50))
		var hud: Node = _find_scene_node("CareHud")
		if hud != null and hud.has_method("show_toast") and not is_panel_open():
			hud.call("show_toast", str(data["text"]), 3.5)
	_refresh_all_ui()


func _on_chat_received(msg: ChatMessage) -> void:
	if msg == null:
		return
	var is_mine: bool = Services.net != null and msg.sender_id == Services.net.local_player_id()
	if not is_mine:
		Sfx.play(&"chat_receive")

	var text_display: String = _display_text_for(msg)
	if text_display.is_empty():
		return

	var key: String = _storage_key_for_incoming(msg)
	var arr: Array = _history.get(key, [])
	arr.append(msg)
	if arr.size() > MAX_HISTORY_PER_CHANNEL:
		arr.pop_front()
	_history[key] = arr

	if key.begins_with("dm:") and not is_mine and (not is_panel_open() or active_tab != "dm"):
		_unread_dms += 1

	_push_hud_live_card(msg, text_display)
	if is_panel_open() and _active_channel_key() == key:
		_rebuild_feed_list()
	_update_badge()


func _display_text_for(msg: ChatMessage) -> String:
	if _catalog == null:
		_catalog = ChatCatalog.new()
	match msg.kind:
		ChatMessage.Kind.PRESET:
			return _catalog.preset_text(msg.payload)
		ChatMessage.Kind.EMOTE:
			var lbl: String = _catalog.emote_label(msg.payload)
			return ("* %s *" % lbl) if not lbl.is_empty() else ""
		ChatMessage.Kind.FREE:
			if not Config.FREE_CHAT_ENABLED:
				return ""
			return msg.payload.strip_edges()
	return ""


func _resolve_sender_nick(msg: ChatMessage) -> String:
	if not msg.sender_name.is_empty():
		return msg.sender_name
	if Services.net != null and msg.sender_id == Services.net.local_player_id():
		var prof: RefCounted = LocalProfile.load_or_default()
		var dn: String = str(prof.get("display_name"))
		return dn if not dn.is_empty() else "Sen"
	var ns: Node = _find_scene_node("NetworkSync")
	if ns != null and ns.has_method("get_remote_player"):
		var rp: Node = ns.call("get_remote_player", msg.sender_id)
		if rp != null:
			var rname: String = str(rp.get("display_name"))
			if not rname.is_empty():
				return rname
	return msg.sender_id.substr(0, 6) if not msg.sender_id.is_empty() else "Oyuncu"


func _channel_badge_prefix(ch: String) -> String:
	if ch.begins_with("cafe:"):
		return "☕ %s" % CafeZones.cafe_name_for(ch.trim_prefix("cafe:"))
	if ch.begins_with("group:"):
		return "👥 Grup"
	if ch.begins_with("dm:"):
		return "🔒 Özel"
	return "🌍"


func _push_hud_live_card(msg: ChatMessage, body_text: String) -> void:
	if _hud_feed_box == null:
		return
	var panel: PanelContainer = PanelContainer.new()
	var pst: StyleBoxFlat = StyleBoxFlat.new()
	pst.bg_color = Color(0.08, 0.11, 0.16, 0.84)
	pst.set_corner_radius_all(12)
	pst.content_margin_left = 10
	pst.content_margin_right = 10
	pst.content_margin_top = 6
	pst.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", pst)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	panel.add_child(row)

	var nick: String = _resolve_sender_nick(msg)
	var sender_btn: Button = Button.new()
	sender_btn.flat = true
	sender_btn.text = "[%s] @%s:" % [_channel_badge_prefix(msg.channel), nick]
	sender_btn.add_theme_font_size_override("font_size", 17)
	sender_btn.add_theme_color_override("font_color", Color(0.62, 0.84, 1.0))
	var sid: String = msg.sender_id
	sender_btn.pressed.connect(func() -> void: open_player_profile(sid, nick))
	row.add_child(sender_btn)

	var lbl: Label = Label.new()
	lbl.text = body_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 17)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	row.add_child(lbl)

	if msg.has_pin:
		var go_btn: Button = Button.new()
		go_btn.text = "🧭 Hedefle"
		go_btn.custom_minimum_size = Vector2(92, 36)
		go_btn.add_theme_font_size_override("font_size", 15)
		var target_xz: Vector2 = msg.pin_pos
		go_btn.pressed.connect(func() -> void: _mark_pin_waypoint(target_xz, msg.pin_place))
		row.add_child(go_btn)

	_hud_feed_box.add_child(panel)
	_live_items.append({"node": panel, "ttl": LIVE_FEED_TTL})
	while _live_items.size() > LIVE_FEED_MAX:
		var old: Dictionary = _live_items.pop_front()
		if is_instance_valid(old["node"]):
			(old["node"] as Node).queue_free()


func _mark_pin_waypoint(target_xz: Vector2, place_label: String) -> void:
	Sfx.play(&"ui_click")
	var CampusMapRef := load("res://src/ui/campus_map.gd") as GDScript
	var stop_nm: String = ""
	if CampusMapRef != null and CampusMapRef.has_method("nearest_bus_stop"):
		var ns_info: Dictionary = CampusMapRef.call("nearest_bus_stop", target_xz)
		stop_nm = str(ns_info.get("name", ""))
	if Services != null and Services.has_method("set_waypoint"):
		Services.set_waypoint(target_xz, place_label, stop_nm)
	close_panel()
	var hud: Node = _find_scene_node("CareHud")
	if hud != null and hud.has_method("show_toast"):
		var stop_txt: String = (" — 🚌 En yakın durak: %s" % stop_nm) if not stop_nm.is_empty() else ""
		hud.call("show_toast", "🧭 %s hedef olarak işaretlendi%s" % [place_label, stop_txt], 3.5)


func _populate_items() -> void:
	_ensure_nodes()
	if _catalog == null:
		_catalog = ChatCatalog.new()

	if _presets_list != null:
		for child: Node in _presets_list.get_children():
			child.queue_free()
		_preset_buttons.clear()

		for item: Dictionary in _catalog.presets():
			var btn: Button = Button.new()
			btn.text = item.get("text", "")
			btn.custom_minimum_size = Vector2(0, 96)
			btn.add_theme_font_size_override("font_size", 28)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			var id: String = str(item.get("id", ""))
			btn.pressed.connect(func() -> void: send_preset(id))
			_presets_list.add_child(btn)
			_preset_buttons.append(btn)

	if _emotes_grid != null:
		for child: Node in _emotes_grid.get_children():
			child.queue_free()
		_emote_buttons.clear()

		for item: Dictionary in _catalog.emotes():
			var btn: Button = Button.new()
			btn.text = item.get("label", "")
			btn.custom_minimum_size = Vector2(0, 96)
			btn.add_theme_font_size_override("font_size", 28)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var id: String = str(item.get("id", ""))
			btn.pressed.connect(func() -> void: send_emote(id))
			_emotes_grid.add_child(btn)
			_emote_buttons.append(btn)


func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta
		if _cooldown <= 0.0:
			_cooldown = 0.0
			_update_cooldown_ui()

	if not _live_items.is_empty():
		var kept: Array[Dictionary] = []
		for it: Dictionary in _live_items:
			var ttl: float = float(it["ttl"]) - delta
			var nd: Control = it["node"] as Control
			if ttl > 0.0 and is_instance_valid(nd):
				if ttl < 2.0:
					nd.modulate.a = ttl / 2.0
				it["ttl"] = ttl
				kept.append(it)
			elif is_instance_valid(nd):
				nd.queue_free()
		_live_items = kept


func _unhandled_key_input(event: InputEvent) -> void:
	if is_panel_open() and event.is_action_pressed("ui_cancel"):
		close_panel()
		get_viewport().set_input_as_handled()


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close_panel()
	elif event is InputEventScreenTouch and event.pressed:
		close_panel()


func open_panel() -> void:
	_ensure_nodes()
	if _panel_overlay != null:
		_panel_overlay.visible = true
	if _hud_feed_box != null:
		_hud_feed_box.visible = false
	_sub_mode = "feed"
	_refresh_all_ui()


func close_panel() -> void:
	_ensure_nodes()
	if _panel_overlay != null:
		_panel_overlay.visible = false
	if _hud_feed_box != null:
		_hud_feed_box.visible = true


func toggle_panel() -> void:
	if is_panel_open():
		close_panel()
	else:
		open_panel()


func is_panel_open() -> bool:
	_ensure_nodes()
	return _panel_overlay != null and _panel_overlay.visible


func send_preset(id: String) -> bool:
	if _cooldown > 0.0:
		return false
	var ch: String = _active_channel_key()
	if ch.is_empty():
		ch = "campus"
	if Services.net != null:
		Services.net.send_chat(ChatMessage.preset(id, ch))
	Sfx.play(&"chat_send")
	_start_cooldown()
	close_panel()
	return true


func send_emote(id: String) -> bool:
	if _cooldown > 0.0:
		return false
	var ch: String = _active_channel_key()
	if ch.is_empty():
		ch = "campus"
	if Services.net != null:
		Services.net.send_chat(ChatMessage.emote(id, ch))
	Sfx.play(&"chat_send")
	_start_cooldown()
	close_panel()
	return true


func send_free_text(raw_text: String) -> bool:
	if _cooldown > 0.0:
		_show_status("Çok hızlı yazıyorsun, 1 sn bekle.", Color(1.0, 0.78, 0.36))
		return false
	if not Config.FREE_CHAT_ENABLED:
		_show_status("Serbest sohbet şu an kapalı.", Color(1.0, 0.55, 0.50))
		return false
	var ch: String = _active_channel_key()
	if ch.is_empty():
		if active_tab == "dm":
			_show_status("Özel mesaj için önce bir arkadaş seçmelisin.", Color(1.0, 0.65, 0.45))
		elif active_tab == "group":
			_show_status("Grup mesajı için önce bir grup kur veya bir gruba katıl.", Color(1.0, 0.65, 0.45))
		return false
	var check: Dictionary = ChatFilter.sanitize_free_text(raw_text)
	if not bool(check.get("ok", false)):
		_show_status(str(check.get("reason", "Mesaj gönderilemedi.")), Color(1.0, 0.55, 0.50))
		return false
	if Services.net != null:
		Services.net.send_chat(ChatMessage.free_text(str(check["text"]), ch))
	Sfx.play(&"chat_send")
	_start_cooldown()
	if _free_input != null:
		_free_input.text = ""
	if _status_lbl != null:
		_status_lbl.visible = false
	return true


func send_free_from_input() -> bool:
	if _free_input == null:
		return false
	return send_free_text(_free_input.text)


func send_location_pin() -> bool:
	if _cooldown > 0.0:
		return false
	var player: Node3D = _find_scene_node("Player") as Node3D
	var pxz: Vector2 = Vector2(player.global_position.x, player.global_position.z) if player != null else Vector2.ZERO
	var place_name: String = nearest_place_name(pxz)
	var ch: String = _active_channel_key()
	if ch.is_empty():
		ch = "campus"
	if Services.net != null:
		Services.net.send_chat(ChatMessage.location_pin(place_name, pxz, ch))
	Sfx.play(&"chat_send")
	_start_cooldown()
	_show_status("📍 %s konumu paylaşıldı!" % place_name, Color(0.55, 0.95, 0.72))
	return true


func nearest_place_name(pxz: Vector2) -> String:
	_load_places_cache()
	var best_name: String = "Ortabahçe"
	var best_d: float = INF
	for p: Dictionary in _places_cache:
		var raw: Array = p.get("pos", [0.0, 0.0])
		if raw.size() >= 2:
			var d: float = pxz.distance_to(Vector2(float(raw[0]), float(raw[1])))
			if d < best_d:
				best_d = d
				best_name = str(p.get("name", "Kampüs")).get_slice("/", 0).strip_edges()
	return best_name


func _refresh_all_ui() -> void:
	_ensure_nodes()
	_update_badge()
	if _channel_bar == null:
		return

	# Kanal sekme vurguları ve canlı sayaçlar
	var inc_count: int = (Services.net.social_state.get("incoming", []) as Array).size() if Services.net != null else 0
	if _tab_btns.has("cafe"):
		(_tab_btns["cafe"] as Button).text = ("☕ %s" % current_cafe_name.get_slice(" ", 0)) if not current_cafe_id.is_empty() else "☕ Kafe"
	if _tab_btns.has("inbox"):
		(_tab_btns["inbox"] as Button).text = ("🔔 İstek (%d)" % inc_count) if inc_count > 0 else "🔔 İstekler"
	if _tab_btns.has("dm"):
		(_tab_btns["dm"] as Button).text = ("🔒 Özel (%d)" % _unread_dms) if _unread_dms > 0 else "🔒 Özel"

	for tid: String in _tab_btns:
		var b: Button = _tab_btns[tid]
		b.modulate = Color(1.0, 0.95, 0.72, 1.0) if tid == active_tab else Color(0.75, 0.80, 0.88, 1.0)

	var is_inbox: bool = active_tab == "inbox"
	if _header_box != null:
		_header_box.visible = not is_inbox
	if _context_box != null:
		_context_box.visible = not is_inbox
	if _composer_box != null:
		_composer_box.visible = not is_inbox and _sub_mode == "feed"
	if _inbox_scroll != null:
		_inbox_scroll.visible = is_inbox

	if is_inbox:
		if _feed_scroll != null:
			_feed_scroll.visible = false
		if _presets_scroll != null:
			_presets_scroll.visible = false
		if _emotes_scroll != null:
			_emotes_scroll.visible = false
		_rebuild_inbox_view()
		return

	# Alt görünüm (Sohbet Akışı vs Hazır Cümleler vs Emote'lar)
	if _feed_scroll != null:
		_feed_scroll.visible = (_sub_mode == "feed")
	if _presets_scroll != null:
		_presets_scroll.visible = (_sub_mode == "presets")
	if _emotes_scroll != null:
		_emotes_scroll.visible = (_sub_mode == "emotes")
	if _feed_mode_btn != null:
		_feed_mode_btn.modulate = Color.WHITE if _sub_mode == "feed" else Color(0.7, 0.7, 0.7, 1.0)
	if _presets_tab_button != null:
		_presets_tab_button.modulate = Color.WHITE if _sub_mode == "presets" else Color(0.7, 0.7, 0.7, 1.0)
	if _emotes_tab_button != null:
		_emotes_tab_button.modulate = Color.WHITE if _sub_mode == "emotes" else Color(0.7, 0.7, 0.7, 1.0)

	_rebuild_context_box()
	_rebuild_feed_list()


func _rebuild_context_box() -> void:
	if _context_box == null:
		return
	for ch: Node in _context_box.get_children():
		ch.queue_free()

	if active_tab == "campus":
		var info: Label = Label.new()
		var online_n: int = _online_peers_list().size() + 1
		info.text = "🌍 Kampüs Geneli Ortak Kanal (%d çevrimiçi) — İsme dokunarak profil açabilirsin." % online_n
		info.add_theme_font_size_override("font_size", 17)
		info.add_theme_color_override("font_color", Color(0.70, 0.80, 0.92))
		_context_box.add_child(info)
	elif active_tab == "cafe":
		if current_cafe_id.is_empty():
			var hint: Label = Label.new()
			hint.text = "☕ Bir kafenin (Hokka, Kayıntı, Büyük Ev, Yemekhane, Yıldız Cafe, Eskafe) kapısından içeri girdiğinde o kafenin canlı sohbet salonu otomatik açılır!"
			hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			hint.add_theme_font_size_override("font_size", 18)
			hint.add_theme_color_override("font_color", Color(0.95, 0.84, 0.52))
			_context_box.add_child(hint)
		else:
			var cafes: Dictionary = Services.net.social_state.get("cafes", {}) if Services.net != null else {}
			var members: Array = cafes.get(current_cafe_id, [])
			var title: Label = Label.new()
			title.text = "☕ %s Salonu — İçeridekiler (%d kişi, tanışmak için isme dokun):" % [current_cafe_name, maxi(1, members.size())]
			title.add_theme_font_size_override("font_size", 18)
			title.add_theme_color_override("font_color", Color(0.62, 0.94, 0.76))
			_context_box.add_child(title)

			var flow: HFlowContainer = HFlowContainer.new()
			flow.add_theme_constant_override("h_separation", 6)
			flow.add_theme_constant_override("v_separation", 6)
			_context_box.add_child(flow)
			for m: Dictionary in members:
				var mid: String = str(m.get("id", ""))
				var mname: String = str(m.get("name", "Oyuncu"))
				var mpet: String = str(m.get("pet", ""))
				var chip: Button = Button.new()
				chip.text = "👤 @%s" % mname
				chip.custom_minimum_size = Vector2(0, 42)
				chip.add_theme_font_size_override("font_size", 18)
				chip.pressed.connect(func() -> void: open_player_profile(mid, mname, mpet))
				flow.add_child(chip)
	elif active_tab == "group":
		var create_row: HBoxContainer = HBoxContainer.new()
		create_row.add_theme_constant_override("separation", 6)
		_context_box.add_child(create_row)

		var g_in: LineEdit = LineEdit.new()
		g_in.name = "GroupTitleInput"
		g_in.placeholder_text = "Kalabalık / özel grup adı..."
		g_in.max_length = ChatFilter.MAX_GROUP_NAME_LEN
		g_in.custom_minimum_size = Vector2(0, 48)
		g_in.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g_in.add_theme_font_size_override("font_size", 18)
		create_row.add_child(g_in)

		var nearby_cnt: int = _nearby_players_count(30.0)
		var g_btn: Button = Button.new()
		g_btn.name = "CreateGroupButton"
		g_btn.text = ("➕ Grup Kur (Yakında %d)" % nearby_cnt) if nearby_cnt > 0 else "➕ Özel Grup Kur"
		g_btn.custom_minimum_size = Vector2(160, 48)
		g_btn.add_theme_font_size_override("font_size", 18)
		g_btn.pressed.connect(func() -> void:
			var t: String = g_in.text.strip_edges()
			if t.is_empty():
				t = "%s Ekibi" % nearest_place_name(_local_player_xz())
			if Services.net != null:
				Services.net.send_social({"act": "create_group", "title": t}))
		create_row.add_child(g_btn)

		var groups: Array = Services.net.social_state.get("groups", []) if Services.net != null else []
		if not groups.is_empty():
			var gflow: HFlowContainer = HFlowContainer.new()
			gflow.add_theme_constant_override("h_separation", 6)
			gflow.add_theme_constant_override("v_separation", 6)
			_context_box.add_child(gflow)
			for g: Dictionary in groups:
				var gid: String = str(g.get("id", ""))
				var gtitle: String = str(g.get("title", "Grup"))
				var gmems: Array = g.get("members", [])
				var joined: bool = (gid == current_group_id)
				var gb: Button = Button.new()
				gb.text = ("✓ %s (%d) [Ayrıl]" if joined else "👥 %s (%d) [Katıl]") % [gtitle, gmems.size()]
				gb.custom_minimum_size = Vector2(0, 42)
				gb.add_theme_font_size_override("font_size", 17)
				gb.pressed.connect(func() -> void:
					if Services.net != null:
						Services.net.send_social({"act": "leave_group"} if joined else {"act": "join_group", "id": gid}))
				gflow.add_child(gb)
	elif active_tab == "dm":
		var friends: Array = Services.net.social_state.get("friends", []) if Services.net != null else []
		if friends.is_empty():
			var empty_dm: Label = Label.new()
			empty_dm.text = "🔒 Özel (Private) sohbet için arkadaş olmanız gerekir. Kafe salonunda veya 3B dünyada bir oyuncunun üstüne dokunup '➕ Arkadaş Ekle' diyebilirsin!"
			empty_dm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			empty_dm.add_theme_font_size_override("font_size", 18)
			empty_dm.add_theme_color_override("font_color", Color(0.95, 0.82, 0.48))
			_context_box.add_child(empty_dm)
		else:
			var fflow: HFlowContainer = HFlowContainer.new()
			fflow.add_theme_constant_override("h_separation", 6)
			fflow.add_theme_constant_override("v_separation", 6)
			_context_box.add_child(fflow)
			for f: Dictionary in friends:
				var fid: String = str(f.get("id", ""))
				var fname: String = str(f.get("name", fid))
				var fb: Button = Button.new()
				fb.text = ("🔒 @%s ✓" if fid == current_dm_peer_id else "👤 @%s") % fname
				fb.custom_minimum_size = Vector2(0, 44)
				fb.add_theme_font_size_override("font_size", 18)
				fb.pressed.connect(func() -> void:
					current_dm_peer_id = fid
					current_dm_peer_name = fname
					_refresh_all_ui())
				fflow.add_child(fb)


func _rebuild_feed_list() -> void:
	if _feed_list == null:
		return
	for ch: Node in _feed_list.get_children():
		ch.queue_free()

	var key: String = _active_channel_key()
	var msgs: Array = _history.get(key, []) if not key.is_empty() else []
	if msgs.is_empty():
		var empty_lbl: Label = Label.new()
		empty_lbl.text = "Henüz bu kanalda mesaj yok. İlk mesajı sen gönder!"
		empty_lbl.add_theme_font_size_override("font_size", 19)
		empty_lbl.add_theme_color_override("font_color", Color(0.62, 0.68, 0.78))
		_feed_list.add_child(empty_lbl)
		return

	for m: ChatMessage in msgs:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_feed_list.add_child(row)

		var nick: String = _resolve_sender_nick(m)
		var nb: Button = Button.new()
		nb.flat = true
		nb.text = "@%s:" % nick
		nb.add_theme_font_size_override("font_size", 20)
		nb.add_theme_color_override("font_color", Color(0.58, 0.84, 1.0))
		var sid: String = m.sender_id
		nb.pressed.connect(func() -> void: open_player_profile(sid, nick))
		row.add_child(nb)

		var tl: Label = Label.new()
		tl.text = _display_text_for(m)
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tl.add_theme_font_size_override("font_size", 20)
		tl.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0))
		row.add_child(tl)

		if m.has_pin:
			var gb: Button = Button.new()
			gb.text = "🧭 Hedefle"
			gb.custom_minimum_size = Vector2(132, 42)
			gb.add_theme_font_size_override("font_size", 18)
			var ppos: Vector2 = m.pin_pos
			var pplace: String = m.pin_place
			gb.pressed.connect(func() -> void: _mark_pin_waypoint(ppos, pplace))
			row.add_child(gb)

	if _feed_scroll != null and is_inside_tree():
		await get_tree().process_frame
		if is_instance_valid(_feed_scroll):
			_feed_scroll.scroll_vertical = int(_feed_scroll.get_v_scroll_bar().max_value)


func _rebuild_inbox_view() -> void:
	if _inbox_box == null:
		return
	for ch: Node in _inbox_box.get_children():
		ch.queue_free()

	# 1) Kampüs Kimliğim (Doğrulanmış YTÜ Öğrencisi ✓ vs YKS Adayı / Kampüs Misafiri)
	var prof: RefCounted = LocalProfile.load_or_default()
	var is_ytu: bool = bool(prof.get("is_ytu_verified"))
	var nick_hdr: Label = Label.new()
	nick_hdr.text = "👤 Kampüs Kimliğim — %s" % ("✓ Doğrulanmış YTÜ Öğrencisi" if is_ytu else "🎯 YKS Adayı / Kampüs Misafiri")
	nick_hdr.add_theme_font_size_override("font_size", 20)
	nick_hdr.add_theme_color_override("font_color", Color(1.0, 0.90, 0.52) if is_ytu else Color(0.68, 0.86, 1.0))
	_inbox_box.add_child(nick_hdr)

	var verify_info_row: HBoxContainer = HBoxContainer.new()
	verify_info_row.add_theme_constant_override("separation", 8)
	_inbox_box.add_child(verify_info_row)

	var verify_hint: Label = Label.new()
	verify_hint.text = "YTÜ maili (@std.yildiz.edu.tr) ile giriş yapanlar otomatik doğrulanmış rozet alır; misafir ve YKS öğrencileri hedef/misafir statüsü seçebilir."
	verify_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	verify_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	verify_hint.add_theme_font_size_override("font_size", 15)
	verify_hint.add_theme_color_override("font_color", Color(0.72, 0.80, 0.90))
	verify_info_row.add_child(verify_hint)

	if Config.DEV_MODE:
		var toggle_ytu_btn: Button = Button.new()
		toggle_ytu_btn.name = "DevToggleYtuButton"
		toggle_ytu_btn.text = "Misafir Yap" if is_ytu else "YTÜ ✓ Yap"
		toggle_ytu_btn.custom_minimum_size = Vector2(124, 44)
		toggle_ytu_btn.add_theme_font_size_override("font_size", 16)
		toggle_ytu_btn.pressed.connect(func() -> void: _toggle_dev_ytu_verified())
		verify_info_row.add_child(toggle_ytu_btn)

	var role_row: HBoxContainer = HBoxContainer.new()
	role_row.add_theme_constant_override("separation", 8)
	_inbox_box.add_child(role_row)

	var role_lbl: Label = Label.new()
	role_lbl.text = "Bölüm:" if is_ytu else "Statü:"
	role_lbl.add_theme_font_size_override("font_size", 18)
	role_row.add_child(role_lbl)

	var role_opt: OptionButton = OptionButton.new()
	role_opt.name = "SelfRoleSelect"
	role_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	role_opt.custom_minimum_size = Vector2(0, 48)
	role_opt.add_theme_font_size_override("font_size", 18)
	var role_choices: PackedStringArray = LocalProfile.YTU_ROLES if is_ytu else LocalProfile.VISITOR_ROLES
	var cur_role: String = str(prof.get("role_tag"))
	var sel_idx: int = 0
	for ri: int in role_choices.size():
		role_opt.add_item(role_choices[ri], ri)
		if role_choices[ri] == cur_role:
			sel_idx = ri
	role_opt.select(sel_idx)
	role_row.add_child(role_opt)

	var bio_in: LineEdit = LineEdit.new()
	bio_in.name = "SelfBioInput"
	bio_in.text = str(prof.get("bio"))
	bio_in.placeholder_text = "Kısa durum/hedef yazısı (örn: ARTLAB için geldim / YKS 2027 hedef YTÜ!)..."
	bio_in.max_length = LocalProfile.BIO_MAX
	bio_in.custom_minimum_size = Vector2(0, 48)
	bio_in.add_theme_font_size_override("font_size", 18)
	_inbox_box.add_child(bio_in)

	var nick_row: HBoxContainer = HBoxContainer.new()
	nick_row.add_theme_constant_override("separation", 8)
	_inbox_box.add_child(nick_row)

	var nick_in: LineEdit = LineEdit.new()
	nick_in.name = "SelfNickInput"
	nick_in.text = str(prof.get("display_name"))
	nick_in.placeholder_text = "Takma adın (1-16 karakter)..."
	nick_in.max_length = LocalProfile.NAME_MAX
	nick_in.custom_minimum_size = Vector2(0, 52)
	nick_in.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nick_in.add_theme_font_size_override("font_size", 19)
	nick_row.add_child(nick_in)

	var save_nick_btn: Button = Button.new()
	save_nick_btn.name = "SaveNickButton"
	save_nick_btn.text = "Profili Kaydet"
	save_nick_btn.custom_minimum_size = Vector2(158, 52)
	save_nick_btn.add_theme_font_size_override("font_size", 19)
	save_nick_btn.pressed.connect(func() -> void:
		var chosen_role: String = role_opt.get_item_text(role_opt.selected) if role_opt.item_count > 0 else ""
		_save_self_profile(nick_in.text, chosen_role, bio_in.text))
	nick_row.add_child(save_nick_btn)

	# 2) Gelen Arkadaşlık İstekleri (İstek Kutusu)
	var st: Dictionary = Services.net.social_state if Services.net != null else {}
	var incoming: Array = st.get("incoming", [])
	var inc_hdr: Label = Label.new()
	inc_hdr.text = "🔔 Arkadaşlık İstek Kutusu (%d)" % incoming.size()
	inc_hdr.add_theme_font_size_override("font_size", 22)
	inc_hdr.add_theme_color_override("font_color", Color(0.98, 0.84, 0.42))
	_inbox_box.add_child(inc_hdr)

	if incoming.is_empty():
		var no_inc: Label = Label.new()
		no_inc.text = "Bekleyen arkadaşlık isteği yok."
		no_inc.add_theme_font_size_override("font_size", 18)
		no_inc.add_theme_color_override("font_color", Color(0.65, 0.72, 0.80))
		_inbox_box.add_child(no_inc)
	else:
		for req: Dictionary in incoming:
			var rid: String = str(req.get("id", ""))
			var rname: String = str(req.get("name", rid))
			var rrow: HBoxContainer = HBoxContainer.new()
			rrow.add_theme_constant_override("separation", 8)
			_inbox_box.add_child(rrow)

			var rlbl: Label = Label.new()
			rlbl.text = "👤 @%s arkadaş olmak istiyor" % rname
			rlbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rlbl.add_theme_font_size_override("font_size", 20)
			rrow.add_child(rlbl)

			var acc_b: Button = Button.new()
			acc_b.text = "✓ Kabul Et"
			acc_b.custom_minimum_size = Vector2(130, 52)
			acc_b.add_theme_font_size_override("font_size", 19)
			acc_b.pressed.connect(func() -> void:
				if Services.net != null:
					Services.net.send_social({"act": "friend_accept", "from": rid}))
			rrow.add_child(acc_b)

			var dec_b: Button = Button.new()
			dec_b.text = "✕ Reddet"
			dec_b.custom_minimum_size = Vector2(110, 52)
			dec_b.add_theme_font_size_override("font_size", 19)
			dec_b.pressed.connect(func() -> void:
				if Services.net != null:
					Services.net.send_social({"act": "friend_decline", "from": rid}))
			rrow.add_child(dec_b)

	# 3) Mevcut Arkadaşlar listesi
	var friends: Array = st.get("friends", [])
	var fr_hdr: Label = Label.new()
	fr_hdr.text = "🤝 Arkadaşlarım (%d)" % friends.size()
	fr_hdr.add_theme_font_size_override("font_size", 20)
	fr_hdr.add_theme_color_override("font_color", Color(0.62, 0.92, 0.74))
	_inbox_box.add_child(fr_hdr)
	for f: Dictionary in friends:
		var fid: String = str(f.get("id", ""))
		var fname: String = str(f.get("name", fid))
		var frow: HBoxContainer = HBoxContainer.new()
		frow.add_theme_constant_override("separation", 8)
		_inbox_box.add_child(frow)
		var flbl: Label = Label.new()
		flbl.text = "• @%s" % fname
		flbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		flbl.add_theme_font_size_override("font_size", 19)
		frow.add_child(flbl)
		var dm_b: Button = Button.new()
		dm_b.text = "🔒 Özel Yaz"
		dm_b.custom_minimum_size = Vector2(132, 46)
		dm_b.add_theme_font_size_override("font_size", 18)
		dm_b.pressed.connect(func() -> void: _on_open_dm_from_profile(fid, fname))
		frow.add_child(dm_b)


func _toggle_dev_ytu_verified() -> void:
	var prof: RefCounted = LocalProfile.load_or_default()
	var next_ytu: bool = not bool(prof.get("is_ytu_verified"))
	prof.set("is_ytu_verified", next_ytu)
	prof.set("role_tag", LocalProfile.YTU_ROLES[0] if next_ytu else LocalProfile.VISITOR_ROLES[0])
	prof.call("save")
	var player: Node = _find_scene_node("Player")
	if player != null and player.has_method("apply_profile"):
		player.call("apply_profile", prof)
	var ns: Node = _find_scene_node("NetworkSync")
	if ns != null and ns.has_method("send_local_profile"):
		ns.call("send_local_profile")
	Sfx.play(&"ui_click")
	_rebuild_inbox_view()


func _save_self_nick(raw_nick: String) -> void:
	var prof: RefCounted = LocalProfile.load_or_default()
	_save_self_profile(raw_nick, str(prof.get("role_tag")), str(prof.get("bio")))


func _save_self_profile(raw_nick: String, raw_role: String, raw_bio: String) -> void:
	var cleaned: String = LocalProfile.clean_name(raw_nick)
	if cleaned.is_empty() or ChatFilter.is_offensive(cleaned):
		_show_status("Geçerli bir takma ad girin.", Color(1.0, 0.55, 0.50))
		return
	var clean_bio: String = raw_bio.strip_edges().substr(0, LocalProfile.BIO_MAX)
	if not clean_bio.is_empty() and ChatFilter.is_offensive(clean_bio):
		_show_status("Durum yazısında uygunsuz ifade kullanılamaz.", Color(1.0, 0.55, 0.50))
		return
	var prof: RefCounted = LocalProfile.load_or_default()
	prof.set("display_name", cleaned)
	prof.set("role_tag", raw_role.strip_edges().substr(0, 32))
	prof.set("bio", clean_bio)
	prof.call("save")
	var player: Node = _find_scene_node("Player")
	if player != null:
		if player.has_method("apply_profile"):
			player.call("apply_profile", prof)
		elif player.has_method("set_display_name"):
			player.call("set_display_name", cleaned)
	var ns: Node = _find_scene_node("NetworkSync")
	if ns != null and ns.has_method("send_local_profile"):
		ns.call("send_local_profile")
	elif Services.net != null:
		Services.net.send_profile(prof.get("pet_id"), prof.get("accessories"), cleaned, {
			"ytu": bool(prof.get("is_ytu_verified")),
			"role": str(prof.get("role_tag")),
			"bio": clean_bio,
			"disc": (prof.get("discovered") as PackedStringArray).size(),
		})
	Sfx.play(&"ui_click")
	_rebuild_inbox_view()


func _online_peers_list() -> Array:
	var out: Array = []
	var ns: Node = _find_scene_node("NetworkSync")
	if ns != null and ns.has_method("get_remote_players"):
		var rps: Dictionary = ns.call("get_remote_players")
		for pid: Variant in rps:
			out.append(rps[pid])
	return out


func _nearby_players_count(radius: float) -> int:
	var p_xz: Vector2 = _local_player_xz()
	var n: int = 0
	for rp: Variant in _online_peers_list():
		if rp is Node3D and Vector2((rp as Node3D).global_position.x, (rp as Node3D).global_position.z).distance_to(p_xz) <= radius:
			n += 1
	return n


func _local_player_xz() -> Vector2:
	var p: Node3D = _find_scene_node("Player") as Node3D
	return Vector2(p.global_position.x, p.global_position.z) if p != null else Vector2.ZERO


func _find_scene_node(node_name: String) -> Node:
	if is_inside_tree() and get_tree().current_scene != null:
		var found: Node = get_tree().current_scene.get_node_or_null(node_name)
		if found != null:
			return found
	if get_parent() != null and get_parent().get_parent() != null:
		return get_parent().get_parent().get_node_or_null(node_name)
	return null


func _show_status(txt: String, col: Color) -> void:
	if _status_lbl != null:
		_status_lbl.text = txt
		_status_lbl.add_theme_color_override("font_color", col)
		_status_lbl.visible = true


func _update_badge() -> void:
	if _badge_lbl == null:
		return
	var inc_n: int = (Services.net.social_state.get("incoming", []) as Array).size() if Services.net != null else 0
	var total: int = inc_n + _unread_dms
	_badge_lbl.visible = total > 0
	if total > 0:
		_badge_lbl.text = str(total)


func _start_cooldown() -> void:
	_cooldown = COOLDOWN_TIME
	_update_cooldown_ui()


func _update_cooldown_ui() -> void:
	_ensure_nodes()
	var is_passive: bool = _cooldown > 0.0
	if _chat_button != null:
		_chat_button.disabled = is_passive
	if _send_btn != null:
		_send_btn.disabled = is_passive
	if _pin_btn != null:
		_pin_btn.disabled = is_passive
	for btn: Button in _preset_buttons:
		btn.disabled = is_passive
	for btn: Button in _emote_buttons:
		btn.disabled = is_passive


func get_cooldown() -> float:
	return _cooldown
