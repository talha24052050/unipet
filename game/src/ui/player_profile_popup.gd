extends Control
## Gelişmiş Oyuncu Profili Kartı v2:
## - ✓ Doğrulanmış YTÜ Öğrencisi (@std.yildiz.edu.tr / @yildiz.edu.tr) rozeti + Bölüm bilgisi
## - 🎯 Kampüs Misafiri / YKS Adayı (Hedef YTÜ) rozeti + Statü etiketi
## - Kısa durum/bio yazısı, seçili pet, kampüs keşif ilerlemesi (n/47) ve Arkadaşlık / Özel Mesaj aksiyonları.

signal open_dm_requested(peer_id: String, peer_name: String)

var target_id: String = ""
var target_name: String = ""
var target_pet: String = ""
var target_ytu_verified: bool = false
var target_role: String = ""
var target_bio: String = ""
var target_discovered: int = 0

var _backdrop: ColorRect
var _verified_pill: PanelContainer
var _verified_label: Label
var _nick_label: Label
var _role_label: Label
var _bio_label: Label
var _sub_label: Label
var _status_label: Label
var _primary_btn: Button
var _secondary_btn: Button


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group(&"joystick_blocker")
	_build_ui()
	if Services.net != null and Services.net.has_signal("social_updated"):
		Services.net.social_updated.connect(func(_d: Dictionary) -> void:
			if visible:
				_refresh_state())


func _build_ui() -> void:
	if _nick_label != null:
		return
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.02, 0.04, 0.08, 0.62)
	_backdrop.gui_input.connect(func(ev: InputEvent) -> void:
		if (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) or (ev is InputEventScreenTouch and ev.pressed):
			close_card())
	add_child(_backdrop)

	var card: PanelContainer = PanelContainer.new()
	card.name = "ProfileCard"
	card.anchor_left = 0.5
	card.anchor_top = 0.5
	card.anchor_right = 0.5
	card.anchor_bottom = 0.5
	card.offset_left = -265.0
	card.offset_top = -255.0
	card.offset_right = 265.0
	card.offset_bottom = 255.0
	var st: StyleBoxFlat = StyleBoxFlat.new()
	st.bg_color = Color(0.10, 0.13, 0.20, 0.98)
	st.border_width_left = 2
	st.border_width_top = 2
	st.border_width_right = 2
	st.border_width_bottom = 2
	st.border_color = Color(0.35, 0.56, 0.86, 0.92)
	st.set_corner_radius_all(22)
	card.add_theme_stylebox_override("panel", st)
	add_child(card)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 18)
	card.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 9)
	margin.add_child(vbox)

	var header: HBoxContainer = HBoxContainer.new()
	vbox.add_child(header)

	var badge_title: Label = Label.new()
	badge_title.text = "👤 KAMPÜS KİMLİĞİ"
	badge_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	badge_title.add_theme_font_size_override("font_size", 19)
	badge_title.add_theme_color_override("font_color", Color(0.68, 0.82, 0.98))
	header.add_child(badge_title)

	var close_btn: Button = Button.new()
	close_btn.name = "CloseProfileButton"
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(52, 52)
	close_btn.add_theme_font_size_override("font_size", 22)
	close_btn.pressed.connect(func() -> void:
		Sfx.play(&"ui_click")
		close_card())
	header.add_child(close_btn)

	_verified_pill = PanelContainer.new()
	_verified_pill.name = "VerificationBadge"
	_verified_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(_verified_pill)

	_verified_label = Label.new()
	_verified_label.name = "VerificationLabel"
	_verified_label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	_verified_label.add_theme_font_size_override("font_size", 17)
	_verified_pill.add_child(_verified_label)

	_nick_label = Label.new()
	_nick_label.name = "ProfileNickLabel"
	_nick_label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	_nick_label.add_theme_font_size_override("font_size", 30)
	_nick_label.add_theme_color_override("font_color", Color(0.98, 0.99, 1.0))
	vbox.add_child(_nick_label)

	_role_label = Label.new()
	_role_label.name = "ProfileRoleLabel"
	_role_label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	_role_label.add_theme_font_size_override("font_size", 19)
	_role_label.add_theme_color_override("font_color", Color(0.62, 0.88, 1.0))
	vbox.add_child(_role_label)

	_bio_label = Label.new()
	_bio_label.name = "ProfileBioLabel"
	_bio_label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	_bio_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bio_label.add_theme_font_size_override("font_size", 18)
	_bio_label.add_theme_color_override("font_color", Color(0.88, 0.90, 0.95))
	vbox.add_child(_bio_label)

	_sub_label = Label.new()
	_sub_label.name = "ProfileStatsLabel"
	_sub_label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	_sub_label.add_theme_font_size_override("font_size", 18)
	_sub_label.add_theme_color_override("font_color", Color(0.75, 0.82, 0.90))
	vbox.add_child(_sub_label)

	_status_label = Label.new()
	_status_label.name = "ProfileFriendStatus"
	_status_label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 18)
	_status_label.add_theme_color_override("font_color", Color(0.96, 0.82, 0.36))
	vbox.add_child(_status_label)

	_primary_btn = Button.new()
	_primary_btn.name = "PrimaryFriendButton"
	_primary_btn.custom_minimum_size = Vector2(0, 62)
	_primary_btn.add_theme_font_size_override("font_size", 22)
	_primary_btn.pressed.connect(_on_primary_pressed)
	vbox.add_child(_primary_btn)

	_secondary_btn = Button.new()
	_secondary_btn.name = "SecondaryFriendButton"
	_secondary_btn.custom_minimum_size = Vector2(0, 50)
	_secondary_btn.add_theme_font_size_override("font_size", 18)
	_secondary_btn.pressed.connect(_on_secondary_pressed)
	vbox.add_child(_secondary_btn)


func show_for_player(pid: String, dname: String, pet_id: String = "", extra: Dictionary = {}) -> void:
	if pid.is_empty():
		return
	_build_ui()
	target_id = pid
	target_name = dname if not dname.is_empty() else pid.substr(0, 6)
	target_pet = pet_id
	target_ytu_verified = bool(extra.get("ytu", false))
	target_role = str(extra.get("role", ""))
	target_bio = str(extra.get("bio", ""))
	target_discovered = int(extra.get("disc", 0))
	visible = true
	_refresh_state()


func close_card() -> void:
	visible = false


func _relation_state() -> String:
	if Services.net == null:
		return "none"
	if target_id == Services.net.local_player_id():
		return "self"
	var st: Dictionary = Services.net.social_state
	for f: Dictionary in st.get("friends", []):
		if str(f.get("id", "")) == target_id:
			return "friend"
	for inc: Dictionary in st.get("incoming", []):
		if str(inc.get("id", "")) == target_id:
			return "incoming"
	for out: Dictionary in st.get("outgoing", []):
		if str(out.get("id", "")) == target_id:
			return "outgoing"
	return "none"


func _refresh_state() -> void:
	var pill_st: StyleBoxFlat = StyleBoxFlat.new()
	pill_st.set_corner_radius_all(14)
	pill_st.content_margin_left = 14.0
	pill_st.content_margin_right = 14.0
	pill_st.content_margin_top = 5.0
	pill_st.content_margin_bottom = 5.0
	pill_st.border_width_left = 2
	pill_st.border_width_top = 2
	pill_st.border_width_right = 2
	pill_st.border_width_bottom = 2
	if target_ytu_verified:
		pill_st.bg_color = Color(0.08, 0.24, 0.56, 0.96)
		pill_st.border_color = Color(0.98, 0.82, 0.32, 0.98)
		_verified_label.text = "✓ DOĞRULANMIŞ YTÜ ÖĞRENCİSİ"
		_verified_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.56))
	else:
		pill_st.bg_color = Color(0.16, 0.24, 0.34, 0.94)
		pill_st.border_color = Color(0.46, 0.78, 0.96, 0.88)
		_verified_label.text = "🎯 KAMPÜS MİSAFİRİ / ADAY ÖĞRENCİ"
		_verified_label.add_theme_color_override("font_color", Color(0.76, 0.92, 1.0))
	_verified_pill.add_theme_stylebox_override("panel", pill_st)

	_nick_label.text = ("✓ @%s" if target_ytu_verified else "@%s") % target_name
	var eff_role: String = target_role
	if eff_role.is_empty():
		eff_role = "YTÜ Davutpaşa Öğrencisi" if target_ytu_verified else "🎯 YKS Adayı / Kampüs Misafiri"
	_role_label.text = ("🎓 Bölüm: %s" % eff_role) if target_ytu_verified else ("🏷 Statü: %s" % eff_role)

	_bio_label.visible = not target_bio.is_empty()
	_bio_label.text = "“%s”" % target_bio

	var pet_txt: String = target_pet.capitalize() if not target_pet.is_empty() else "Kampüs Dostu"
	_sub_label.text = "🐾 Pet: %s   ·   🗺 Kampüs Keşfi: %d/47" % [pet_txt, clampi(target_discovered, 0, 47)]

	var rel: String = _relation_state()
	match rel:
		"self":
			_status_label.text = "Bu senin kampüs kartın (İstekler sekmesinden düzenleyebilirsin)"
			_primary_btn.visible = false
			_secondary_btn.visible = false
		"friend":
			_status_label.text = "✓ Arkadaşsınız (Özel sohbet açık)"
			_primary_btn.visible = true
			_primary_btn.disabled = false
			_primary_btn.text = "🔒 Özel Mesaj Gönder"
			_secondary_btn.visible = true
			_secondary_btn.text = "Arkadaşlıktan Çıkar"
		"incoming":
			_status_label.text = "🔔 Sana arkadaşlık isteği gönderdi!"
			_primary_btn.visible = true
			_primary_btn.disabled = false
			_primary_btn.text = "✓ İsteği Kabul Et"
			_secondary_btn.visible = true
			_secondary_btn.text = "✕ İsteği Reddet"
		"outgoing":
			_status_label.text = "⏳ Arkadaşlık isteği bekleniyor"
			_primary_btn.visible = true
			_primary_btn.disabled = true
			_primary_btn.text = "⏳ İstek Gönderildi"
			_secondary_btn.visible = false
		_:
			_status_label.text = "Henüz arkadaş değilsiniz"
			_primary_btn.visible = true
			_primary_btn.disabled = false
			_primary_btn.text = "➕ Arkadaş Ekle"
			_secondary_btn.visible = false


func _on_primary_pressed() -> void:
	Sfx.play(&"ui_click")
	if Services.net == null:
		return
	var rel: String = _relation_state()
	match rel:
		"none":
			Services.net.send_social({"act": "friend_req", "to": target_id, "name": target_name})
		"incoming":
			Services.net.send_social({"act": "friend_accept", "from": target_id})
		"friend":
			var pid: String = target_id
			var pname: String = target_name
			close_card()
			open_dm_requested.emit(pid, pname)


func _on_secondary_pressed() -> void:
	Sfx.play(&"ui_click")
	if Services.net == null:
		return
	var rel: String = _relation_state()
	if rel == "incoming":
		Services.net.send_social({"act": "friend_decline", "from": target_id})
	elif rel == "friend":
		Services.net.send_social({"act": "friend_remove", "id": target_id})
