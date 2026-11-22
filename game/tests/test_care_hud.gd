extends RefCounted
## CareHud arayüzü testleri:
## - Sahne ve düğümlerin yüklenmesi, mobil kuralları (≥96px butonlar, ≥26px yazılar)
## - care_updated ile çubuk değerleri ve renkleri (>50 yeşil, 20-50 sarı, <20 kırmızı)
## - Ruh hali "sad" iken doğru uyarı (acıktı / yoruldu / sıkıldı)
## - Bekleme süresi hesabı ve pasif buton durumu
## - Yemek yerinden uzakta Ye butonu pasif/soluk ve uyarı toast'ı
## - Eylem başarı animasyonları ve hata toast'ı
## - main.tscn UI altına CareHud entegrasyonu

const PetCareRules := preload("res://src/care/pet_care_rules.gd")
const CareHudScript := preload("res://src/ui/care_hud.gd")
const NetworkService := preload("res://src/net/network_service.gd")

const CARE_HUD_SCENE_PATH: String = "res://scenes/ui/care_hud.tscn"


class MockCareNet extends NetworkService:
	var last_action: String = ""

	func send_care_action(action: String) -> void:
		last_action = action


class MockVisual extends Node3D:
	var last_emote: StringName = &""

	func play_emote(anim: StringName) -> bool:
		last_emote = anim
		return true


class MockPlayer extends Node3D:
	var visual: MockVisual

	func _init() -> void:
		visual = MockVisual.new()
		add_child(visual)


func _make_hud() -> Control:
	var scene: PackedScene = load(CARE_HUD_SCENE_PATH)
	if scene == null:
		return null
	var inst: Control = scene.instantiate() as Control
	(Engine.get_main_loop() as SceneTree).root.add_child(inst)
	return inst


func _cleanup(hud: Node, extra: Node = null) -> void:
	if extra != null and is_instance_valid(extra):
		if extra.get_parent() != null:
			extra.get_parent().remove_child(extra)
		extra.free()
	if hud != null and is_instance_valid(hud):
		if hud.get_parent() != null:
			hud.get_parent().remove_child(hud)
		hud.free()


func test_scene_loads_and_mobile_rules() -> String:
	var hud: Control = _make_hud()
	if hud == null:
		return "care_hud.tscn yüklenemedi"

	# Düğümler mevcut mu?
	var food_bar: ProgressBar = hud.get_node_or_null("%FoodBar") as ProgressBar
	var joy_bar: ProgressBar = hud.get_node_or_null("%JoyBar") as ProgressBar
	var energy_bar: ProgressBar = hud.get_node_or_null("%EnergyBar") as ProgressBar
	if food_bar == null or joy_bar == null or energy_bar == null:
		_cleanup(hud)
		return "Durum çubukları bulunamadı"

	var eat_btn: Button = hud.get_node_or_null("%EatButton") as Button
	var rest_btn: Button = hud.get_node_or_null("%RestButton") as Button
	var play_btn: Button = hud.get_node_or_null("%PlayButton") as Button
	if eat_btn == null or rest_btn == null or play_btn == null:
		_cleanup(hud)
		return "Eylem butonları bulunamadı"

	var mood_label: Label = hud.get_node_or_null("%MoodWarningLabel") as Label
	var toast_container: Control = hud.get_node_or_null("%ToastContainer") as Control
	var toast_label: Label = hud.get_node_or_null("%ToastLabel") as Label
	if mood_label == null or toast_container == null or toast_label == null:
		_cleanup(hud)
		return "Uyarı veya toast düğümleri bulunamadı"

	# Mobil boyut kuralları: Butonlar ≥ 96 px
	var buttons: Array[Button] = [eat_btn, rest_btn, play_btn]
	for btn: Button in buttons:
		if btn.custom_minimum_size.x < 96.0 or btn.custom_minimum_size.y < 96.0:
			var err: String = "Buton boyutu ≥ 96px olmalı (%s: %s)" % [btn.name, btn.custom_minimum_size]
			_cleanup(hud)
			return err
		var font_size: int = btn.get_theme_font_size("font_size")
		if font_size < 26:
			var err: String = "Buton yazı boyutu ≥ 26px olmalı (%s: %d)" % [btn.name, font_size]
			_cleanup(hud)
			return err
		if btn.mouse_filter != Control.MOUSE_FILTER_STOP:
			_cleanup(hud)
			return "Buton dokunuşları oyuna geçmemeli (mouse_filter MOUSE_FILTER_STOP olmalı)"

	# Mobil yazı boyutları: Yazılar ≥ 26 px
	var labels: Array[Label] = [
		hud.get_node("%FoodLabel") as Label,
		hud.get_node("%JoyLabel") as Label,
		hud.get_node("%EnergyLabel") as Label,
		mood_label,
		toast_label
	]
	for lbl: Label in labels:
		var font_size: int = lbl.get_theme_font_size("font_size")
		if font_size < 26:
			var err: String = "Etiket yazı boyutu ≥ 26px olmalı (%s: %d)" % [lbl.name, font_size]
			_cleanup(hud)
			return err

	# Çubuk paneli dokunuşu durdurmalı
	var bars_panel: PanelContainer = hud.get_node("%BarsPanel") as PanelContainer
	if bars_panel.mouse_filter != Control.MOUSE_FILTER_STOP:
		_cleanup(hud)
		return "BarsPanel dokunuşları oyuna geçmemeli"

	_cleanup(hud)
	return ""


func test_care_updated_updates_bars() -> String:
	var hud: Control = _make_hud()
	if hud == null:
		return "care_hud.tscn yüklenemedi"

	# food: 85 (yeşil), joy: 45 (sarı), energy: 15 (kırmızı)
	hud.call("_on_care_updated", {"food": 85.0, "joy": 45.0, "energy": 15.0, "t": 1000}, true, "")

	var food_bar: ProgressBar = hud.get_node("%FoodBar") as ProgressBar
	var joy_bar: ProgressBar = hud.get_node("%JoyBar") as ProgressBar
	var energy_bar: ProgressBar = hud.get_node("%EnergyBar") as ProgressBar

	if food_bar.value != 85.0:
		_cleanup(hud)
		return "Food bar değeri 85.0 olmalı, %f" % food_bar.value
	if joy_bar.value != 45.0:
		_cleanup(hud)
		return "Joy bar değeri 45.0 olmalı, %f" % joy_bar.value
	if energy_bar.value != 15.0:
		_cleanup(hud)
		return "Energy bar değeri 15.0 olmalı, %f" % energy_bar.value

	var food_lbl: Label = hud.get_node("%FoodLabel") as Label
	var joy_lbl: Label = hud.get_node("%JoyLabel") as Label
	var energy_lbl: Label = hud.get_node("%EnergyLabel") as Label

	if not food_lbl.text.contains("85"):
		_cleanup(hud)
		return "Food etiketi yüzdeyi içermiyor: %s" % food_lbl.text
	if not joy_lbl.text.contains("45"):
		_cleanup(hud)
		return "Joy etiketi yüzdeyi içermiyor: %s" % joy_lbl.text
	if not energy_lbl.text.contains("15"):
		_cleanup(hud)
		return "Energy etiketi yüzdeyi içermiyor: %s" % energy_lbl.text

	# Renk kontrolü (> 50 yeşil, 20-50 sarı, < 20 kırmızı)
	var food_style: StyleBoxFlat = food_bar.get_theme_stylebox("fill") as StyleBoxFlat
	var joy_style: StyleBoxFlat = joy_bar.get_theme_stylebox("fill") as StyleBoxFlat
	var energy_style: StyleBoxFlat = energy_bar.get_theme_stylebox("fill") as StyleBoxFlat

	if food_style == null or food_style.bg_color != CareHudScript.COLOR_GREEN:
		_cleanup(hud)
		return "Food bar rengi yeşil olmalı: %s" % (food_style.bg_color if food_style else "null")
	if joy_style == null or joy_style.bg_color != CareHudScript.COLOR_YELLOW:
		_cleanup(hud)
		return "Joy bar rengi sarı olmalı: %s" % (joy_style.bg_color if joy_style else "null")
	if energy_style == null or energy_style.bg_color != CareHudScript.COLOR_RED:
		_cleanup(hud)
		return "Energy bar rengi kırmızı olmalı: %s" % (energy_style.bg_color if energy_style else "null")

	_cleanup(hud)
	return ""


func test_low_stat_mood_warning() -> String:
	var hud: Control = _make_hud()
	if hud == null:
		return "care_hud.tscn yüklenemedi"

	# Yüksek değerlerde uyarı görünmemeli
	hud.call("_on_care_updated", {"food": 80.0, "joy": 80.0, "energy": 80.0, "t": 1000}, true, "")
	if hud.call("is_mood_warning_visible"):
		_cleanup(hud)
		return "Normal durumda ruh hali uyarısı gizli olmalı"

	# Tokluk düşük (< 20) -> "Petin acıktı"
	hud.call("_on_care_updated", {"food": 10.0, "joy": 70.0, "energy": 70.0, "t": 1000}, true, "")
	if not hud.call("is_mood_warning_visible"):
		_cleanup(hud)
		return "Tokluk düşükken uyarı görünmeli"
	if not (hud.call("get_mood_warning_text") as String).contains("acıktı"):
		_cleanup(hud)
		return "Tokluk düşükken 'acıktı' uyarısı bekleniyordu: %s" % hud.call("get_mood_warning_text")

	# Enerji düşük (< 20) -> "Petin yoruldu"
	hud.call("_on_care_updated", {"food": 70.0, "joy": 70.0, "energy": 10.0, "t": 1000}, true, "")
	if not (hud.call("get_mood_warning_text") as String).contains("yoruldu"):
		_cleanup(hud)
		return "Enerji düşükken 'yoruldu' uyarısı bekleniyordu: %s" % hud.call("get_mood_warning_text")

	# Mutluluk düşük (< 20) -> "Petin sıkıldı"
	hud.call("_on_care_updated", {"food": 70.0, "joy": 10.0, "energy": 70.0, "t": 1000}, true, "")
	if not (hud.call("get_mood_warning_text") as String).contains("sıkıldı"):
		_cleanup(hud)
		return "Mutluluk düşükken 'sıkıldı' uyarısı bekleniyordu: %s" % hud.call("get_mood_warning_text")

	# Tekrar düzelince gizlenmeli
	hud.call("_on_care_updated", {"food": 60.0, "joy": 60.0, "energy": 60.0, "t": 1000}, true, "")
	if hud.call("is_mood_warning_visible"):
		_cleanup(hud)
		return "Değerler yükselince uyarı gizlenmeli"

	_cleanup(hud)
	return ""


func test_cooldown_calculation_and_passive() -> String:
	var hud: Control = _make_hud()
	if hud == null:
		return "care_hud.tscn yüklenemedi"

	var eat_btn: Button = hud.get_node("%EatButton") as Button
	var now: int = int(Time.get_unix_time_from_system())

	# Eylemin cooldown'ı 600 sn ("eat")
	hud.call("set_action_time", "eat", now - 100)
	var remaining: float = hud.call("get_cooldown_remaining", "eat")
	if remaining < 490.0 or remaining > 510.0:
		_cleanup(hud)
		return "Kalan süre ~500 sn olmalı: %f" % remaining

	if not eat_btn.disabled:
		_cleanup(hud)
		return "Bekleme süresinde buton pasif (disabled) olmalı"
	if not eat_btn.text.contains("s"):
		_cleanup(hud)
		return "Bekleme süresinde buton kalan saniyeyi göstermeli: %s" % eat_btn.text

	# Bekleme süresi bittiğinde
	hud.call("set_action_time", "eat", now - 601)
	remaining = hud.call("get_cooldown_remaining", "eat")
	if remaining != 0.0:
		_cleanup(hud)
		return "Bekleme bitince kalan süre 0 olmalı: %f" % remaining

	_cleanup(hud)
	return ""


func test_eat_button_away_from_spot() -> String:
	var hud: Control = _make_hud()
	if hud == null:
		return "care_hud.tscn yüklenemedi"

	var dummy_player: MockPlayer = MockPlayer.new()
	dummy_player.position = Vector3.ZERO # Ortabahçe ortası, yemek yeri değil
	(Engine.get_main_loop() as SceneTree).root.add_child(dummy_player)
	hud.player = dummy_player
	hud.call("_update_buttons")

	# Yemek yerinden uzakta Ye butonu pasif/soluk olmalı
	if hud.call("is_eat_active"):
		_cleanup(hud, dummy_player)
		return "Yemek yerinden uzaktayken is_eat_active false olmalı"

	var eat_btn: Button = hud.get_node("%EatButton") as Button
	if eat_btn.modulate.a >= 1.0:
		_cleanup(hud, dummy_player)
		return "Yemek yerinden uzaktayken Ye butonu soluk olmalı (modulate.a < 1.0)"

	# Dokununca kısa uyarı toast olarak çıkmalı ve eylem gönderilmemeli
	var mock_net: MockCareNet = MockCareNet.new()
	var prev_net = Services.net
	Services.net = mock_net

	hud.call("_on_eat_pressed")
	if mock_net.last_action != "":
		Services.net = prev_net
		mock_net.free()
		_cleanup(hud, dummy_player)
		return "Uzakta Ye butonuna basılınca ağa eylem gitmemeli"

	if not hud.call("is_toast_visible"):
		Services.net = prev_net
		mock_net.free()
		_cleanup(hud, dummy_player)
		return "Uzakta Ye butonuna dokununca uyarı toast'ı çıkmalı"

	var toast_text: String = hud.call("get_toast_text")
	if not toast_text.contains("Yemekhane"):
		Services.net = prev_net
		mock_net.free()
		_cleanup(hud, dummy_player)
		return "Uyarı metni doğru değil: %s" % toast_text

	# Yemek yerine yaklaşınca (Yemekhane: x=-103.5, z=-95.2)
	dummy_player.position = Vector3(-103.5, 0.0, -95.2)
	hud.call("_update_buttons")

	if not hud.call("is_eat_active"):
		Services.net = prev_net
		mock_net.free()
		_cleanup(hud, dummy_player)
		return "Yemek yerindeyken is_eat_active true olmalı"

	if eat_btn.modulate.a < 1.0:
		Services.net = prev_net
		mock_net.free()
		_cleanup(hud, dummy_player)
		return "Yemek yerindeyken Ye butonu tam opak olmalı (modulate.a == 1.0)"

	# Yakındayken basınca ağa eylem gitmeli
	hud.call("_on_eat_pressed")
	if mock_net.last_action != "eat":
		Services.net = prev_net
		mock_net.free()
		_cleanup(hud, dummy_player)
		return "Yemek yerindeyken basınca 'eat' eylemi gönderilmeli"

	Services.net = prev_net
	mock_net.free()
	_cleanup(hud, dummy_player)
	return ""


func test_care_actions_send_and_emote_feedback() -> String:
	var hud: Control = _make_hud()
	if hud == null:
		return "care_hud.tscn yüklenemedi"

	var dummy_player: MockPlayer = MockPlayer.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(dummy_player)
	hud.player = dummy_player

	var mock_net: MockCareNet = MockCareNet.new()
	var prev_net = Services.net
	Services.net = mock_net

	# Oyna basınca send_care_action("play") gitmeli
	hud.call("_on_play_pressed")
	if mock_net.last_action != "play":
		Services.net = prev_net
		mock_net.free()
		_cleanup(hud, dummy_player)
		return "Oyna basılınca 'play' gönderilmedi"

	# Başarılı cevap gelince emote_dance oynamalı
	hud.call("_on_care_updated", {"food": 75.0, "joy": 95.0, "energy": 70.0, "t": 1000}, true, "")
	if dummy_player.visual.last_emote != &"emote_dance":
		Services.net = prev_net
		mock_net.free()
		_cleanup(hud, dummy_player)
		return "Oyna başarılı olunca emote_dance oynatılmalı, %s oynadı" % dummy_player.visual.last_emote

	# Dinlen basınca send_care_action("rest") gitmeli
	hud.call("_on_rest_pressed")
	if mock_net.last_action != "rest":
		Services.net = prev_net
		mock_net.free()
		_cleanup(hud, dummy_player)
		return "Dinlen basılınca 'rest' gönderilmedi"

	# Dinlen başarılı gelince emote_yes oynamalı
	hud.call("_on_care_updated", {"food": 75.0, "joy": 95.0, "energy": 100.0, "t": 1000}, true, "")
	if dummy_player.visual.last_emote != &"emote_yes":
		Services.net = prev_net
		mock_net.free()
		_cleanup(hud, dummy_player)
		return "Dinlen başarılı olunca emote_yes oynatılmalı, %s oynadı" % dummy_player.visual.last_emote

	# Başarısız cevap gelince (ok=false) reason toast gösterilmeli
	hud.call("_on_care_updated", {}, false, "biraz bekle")
	if not hud.call("is_toast_visible") or hud.call("get_toast_text") != "biraz bekle":
		Services.net = prev_net
		mock_net.free()
		_cleanup(hud, dummy_player)
		return "Hata cevabında toast gösterilmedi veya metin yanlış"

	Services.net = prev_net
	mock_net.free()
	_cleanup(hud, dummy_player)
	return ""


func test_main_scene_has_care_hud() -> String:
	var scene: PackedScene = load("res://scenes/main.tscn")
	if scene == null:
		return "main.tscn yüklenemedi"
	var inst: Node = scene.instantiate()
	if inst == null:
		return "main.tscn instantiate edilemedi"

	var hud = inst.get_node_or_null("UI/CareHud")
	if hud == null:
		inst.free()
		return "main.tscn içinde UI/CareHud bulunamadı"

	inst.free()
	return ""
