extends RefCounted
## Ayarlar paneli (SettingsPanel), ayarlar butonu (SettingsButton) ve LocalSettings ses ayarları testleri.

const LocalSettings := preload("res://src/core/local_settings.gd")
const SettingsPanel := preload("res://src/ui/settings_panel.gd")
const SettingsButton := preload("res://src/ui/settings_button.gd")

const TEST_SETTINGS_PATH: String = "user://test_settings.cfg"
const TEST_LEGACY_PATH: String = "user://test_legacy_settings.cfg"
const TEST_CB_PATH: String = "user://test_cb_settings.cfg"
const TEST_SLIDER_PATH: String = "user://test_slider_settings.cfg"


func _delete_file(path: String) -> void:
	var global_path: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path) or FileAccess.file_exists(global_path):
		DirAccess.remove_absolute(global_path)


func _cleanup_node(node: Node) -> void:
	if node != null and is_instance_valid(node):
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		node.free()


## Test 1: LocalSettings yeni alanları (sfx_enabled, sfx_volume_db) kaydedip geri okuyor.
func test_local_settings_fields_roundtrip() -> String:
	_delete_file(TEST_SETTINGS_PATH)

	var s = LocalSettings.new()
	if s.sfx_enabled != true:
		return "Varsayılan sfx_enabled true olmalı, %s bulundu" % str(s.sfx_enabled)
	if not is_equal_approx(s.sfx_volume_db, 0.0):
		return "Varsayılan sfx_volume_db 0.0 olmalı, %f bulundu" % s.sfx_volume_db

	s.sfx_enabled = false
	s.sfx_volume_db = -18.0
	var err: Error = s.save(TEST_SETTINGS_PATH)
	if err != OK:
		_delete_file(TEST_SETTINGS_PATH)
		return "LocalSettings kaydedilemedi, hata kodu: %d" % err

	var loaded = LocalSettings.load_or_default(TEST_SETTINGS_PATH)
	_delete_file(TEST_SETTINGS_PATH)

	if loaded.sfx_enabled != false:
		return "Kaydedilen sfx_enabled false olarak geri okunamadı"
	if not is_equal_approx(loaded.sfx_volume_db, -18.0):
		return "Kaydedilen sfx_volume_db -18.0 olarak geri okunamadı: %f" % loaded.sfx_volume_db

	return ""


## Test 2: Eski (audio bölümü olmayan) dosya varsayılanlara düşüyor.
func test_legacy_settings_uses_defaults() -> String:
	_delete_file(TEST_LEGACY_PATH)

	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("server", "address", "192.168.1.100:7350")
	cfg.save(TEST_LEGACY_PATH)

	var loaded = LocalSettings.load_or_default(TEST_LEGACY_PATH)
	_delete_file(TEST_LEGACY_PATH)

	if loaded.server_address != "192.168.1.100:7350":
		return "Eski dosyadaki server_address okunamadı"
	if loaded.sfx_enabled != true:
		return "Eski dosyada sfx_enabled varsayılan true olmalı"
	if not is_equal_approx(loaded.sfx_volume_db, 0.0):
		return "Eski dosyada sfx_volume_db varsayılan 0.0 olmalı"

	return ""


## Test 3: Panel kontrolleri, boyutları ve dokunmatik kuralları (min 64 px, yazı 26+).
func test_settings_panel_controls_and_touch_sizes() -> String:
	var panel = SettingsPanel.new()

	if not (panel is PanelContainer):
		_cleanup_node(panel)
		return "SettingsPanel PanelContainer türevi olmalı"

	if panel.title_label == null or panel.title_label.text != "Ayarlar":
		_cleanup_node(panel)
		return "Başlık 'Ayarlar' olan Label bulunamadı"
	if panel.title_label.custom_minimum_size.y < 64.0:
		_cleanup_node(panel)
		return "Başlık yüksekliği min 64 px olmalı"
	if panel.title_label.get_theme_font_size("font_size") < 26:
		_cleanup_node(panel)
		return "Başlık yazı boyutu min 26 olmalı"

	if panel.check_button == null or not (panel.check_button is CheckButton):
		_cleanup_node(panel)
		return "'Ses efektleri' CheckButton bulunamadı"
	if panel.check_button.text != "Ses efektleri":
		_cleanup_node(panel)
		return "CheckButton metni 'Ses efektleri' olmalı"
	if panel.check_button.custom_minimum_size.y < 64.0:
		_cleanup_node(panel)
		return "CheckButton yüksekliği min 64 px olmalı"
	if panel.check_button.get_theme_font_size("font_size") < 26:
		_cleanup_node(panel)
		return "CheckButton yazı boyutu min 26 olmalı"

	if panel.volume_slider == null or not (panel.volume_slider is HSlider):
		_cleanup_node(panel)
		return "'Ses düzeyi' HSlider bulunamadı"
	if panel.volume_slider.custom_minimum_size.y < 64.0:
		_cleanup_node(panel)
		return "HSlider yüksekliği min 64 px olmalı"
	if not is_equal_approx(panel.volume_slider.min_value, -30.0):
		_cleanup_node(panel)
		return "HSlider min_value -30 olmalı"
	if not is_equal_approx(panel.volume_slider.max_value, 6.0):
		_cleanup_node(panel)
		return "HSlider max_value 6 olmalı"
	if not is_equal_approx(panel.volume_slider.step, 1.0):
		_cleanup_node(panel)
		return "HSlider step 1 olmalı"

	if panel.close_button == null or panel.close_button.text != "Kapat":
		_cleanup_node(panel)
		return "'Kapat' butonu bulunamadı"
	if panel.close_button.custom_minimum_size.y < 64.0:
		_cleanup_node(panel)
		return "Kapat butonu yüksekliği min 64 px olmalı"
	if panel.close_button.get_theme_font_size("font_size") < 26:
		_cleanup_node(panel)
		return "Kapat butonu yazı boyutu min 26 olmalı"

	_cleanup_node(panel)
	return ""


## Test 4: Panel açılıp kapanıyor (open, close, toggle, Kapat butonu).
func test_settings_panel_open_and_close() -> String:
	var panel = SettingsPanel.new()

	if panel.visible:
		_cleanup_node(panel)
		return "Panel başlangıçta kapalı (visible=false) olmalı"

	panel.open()
	if not panel.visible or not panel.is_open():
		_cleanup_node(panel)
		return "open() sonrasında panel açık olmalı"

	panel.close()
	if panel.visible or panel.is_open():
		_cleanup_node(panel)
		return "close() sonrasında panel kapalı olmalı"

	panel.toggle()
	if not panel.visible:
		_cleanup_node(panel)
		return "toggle() kapalıyken açmalı"

	panel.toggle()
	if panel.visible:
		_cleanup_node(panel)
		return "toggle() açıkken kapatmalı"

	panel.open()
	panel.close_button.pressed.emit()
	if panel.visible:
		_cleanup_node(panel)
		return "Kapat butonuna basılınca panel kapanmalı"

	_cleanup_node(panel)
	return ""


## Test 5: Checkbox Sfx.enabled'ı değiştiriyor ve dosyaya kaydediyor (testten sonra eski değere geri al).
func test_checkbox_modifies_sfx_enabled_and_saves() -> String:
	var prev_enabled: bool = Sfx.enabled
	var prev_volume: float = Sfx.volume_db

	_delete_file(TEST_CB_PATH)

	var panel = SettingsPanel.new()
	panel.settings_path = TEST_CB_PATH

	# Checkbox'ı false yap
	panel.check_button.button_pressed = false
	if Sfx.enabled != false:
		_cleanup_node(panel)
		_delete_file(TEST_CB_PATH)
		Sfx.enabled = prev_enabled
		Sfx.volume_db = prev_volume
		return "Checkbox false yapılınca Sfx.enabled false olmadı"

	var loaded1 = LocalSettings.load_or_default(TEST_CB_PATH)
	if loaded1.sfx_enabled != false:
		_cleanup_node(panel)
		_delete_file(TEST_CB_PATH)
		Sfx.enabled = prev_enabled
		Sfx.volume_db = prev_volume
		return "Checkbox false yapılınca LocalSettings'e kaydedilmedi"

	# Checkbox'ı true yap
	panel.check_button.button_pressed = true
	if Sfx.enabled != true:
		_cleanup_node(panel)
		_delete_file(TEST_CB_PATH)
		Sfx.enabled = prev_enabled
		Sfx.volume_db = prev_volume
		return "Checkbox true yapılınca Sfx.enabled true olmadı"

	var loaded2 = LocalSettings.load_or_default(TEST_CB_PATH)
	if loaded2.sfx_enabled != true:
		_cleanup_node(panel)
		_delete_file(TEST_CB_PATH)
		Sfx.enabled = prev_enabled
		Sfx.volume_db = prev_volume
		return "Checkbox true yapılınca LocalSettings'e kaydedilmedi"

	_cleanup_node(panel)
	_delete_file(TEST_CB_PATH)

	# Eski değerlere geri al
	Sfx.enabled = prev_enabled
	Sfx.volume_db = prev_volume
	return ""


## Test 6: Ses düzeyi kaydırıcısı Sfx.volume_db'yi değiştiriyor ve dosyaya kaydediyor.
func test_volume_slider_modifies_sfx_volume_and_saves() -> String:
	var prev_enabled: bool = Sfx.enabled
	var prev_volume: float = Sfx.volume_db

	_delete_file(TEST_SLIDER_PATH)

	var panel = SettingsPanel.new()
	panel.settings_path = TEST_SLIDER_PATH
	var root: Node = (Engine.get_main_loop() as SceneTree).root
	root.add_child(panel)

	panel.volume_slider.value = -12.0
	panel.volume_slider.value_changed.emit(-12.0)

	if not is_equal_approx(Sfx.volume_db, -12.0):
		var curr_val: float = panel.volume_slider.value
		_cleanup_node(panel)
		_delete_file(TEST_SLIDER_PATH)
		Sfx.enabled = prev_enabled
		Sfx.volume_db = prev_volume
		return "HSlider -12 dB yapılınca Sfx.volume_db güncellenmedi (val=%f, Sfx=%f)" % [curr_val, Sfx.volume_db]

	var loaded = LocalSettings.load_or_default(TEST_SLIDER_PATH)
	if not is_equal_approx(loaded.sfx_volume_db, -12.0):
		_cleanup_node(panel)
		_delete_file(TEST_SLIDER_PATH)
		Sfx.enabled = prev_enabled
		Sfx.volume_db = prev_volume
		return "HSlider -12 dB yapılınca LocalSettings'e kaydedilmedi"

	_cleanup_node(panel)
	_delete_file(TEST_SLIDER_PATH)

	# Eski değerlere geri al
	Sfx.enabled = prev_enabled
	Sfx.volume_db = prev_volume
	return ""


## Test 7: main.tscn içinde UI altında SettingsButton Harita butonunun hemen altında ve aynı genişlikte.
func test_settings_button_in_main_scene() -> String:
	var scene: PackedScene = load("res://scenes/main.tscn")
	if scene == null:
		return "main.tscn yüklenemedi"
	var inst: Node = scene.instantiate()
	if inst == null:
		return "main.tscn instantiate edilemedi"

	var map_btn: Button = inst.get_node_or_null("UI/MapButton") as Button
	if map_btn == null:
		_cleanup_node(inst)
		return "main.tscn içinde UI/MapButton bulunamadı"

	var settings_btn: Button = inst.get_node_or_null("UI/SettingsButton") as Button
	if settings_btn == null:
		_cleanup_node(inst)
		return "main.tscn içinde UI/SettingsButton bulunamadı"

	if settings_btn.text != "Ayarlar":
		_cleanup_node(inst)
		return "SettingsButton metni 'Ayarlar' olmalı"

	# Aynı genişlikte:
	var map_w: float = map_btn.offset_right - map_btn.offset_left
	var set_w: float = settings_btn.offset_right - settings_btn.offset_left
	if not is_equal_approx(map_w, set_w):
		_cleanup_node(inst)
		return "SettingsButton Harita butonuyla aynı genişlikte olmalı (%f != %f)" % [set_w, map_w]

	# Hemen altında:
	if settings_btn.offset_top < map_btn.offset_bottom:
		_cleanup_node(inst)
		return "SettingsButton Harita butonunun hemen altında olmalı"

	_cleanup_node(inst)
	return ""


## Test 8: SettingsButton paneli açıp kapatıyor.
func test_settings_button_toggles_panel() -> String:
	var btn = SettingsButton.new()
	var root: Node = (Engine.get_main_loop() as SceneTree).root
	root.add_child(btn)

	# Butona tıkla -> panel açılmalı
	btn._on_pressed()
	if btn.panel == null or not btn.panel.visible:
		_cleanup_node(btn)
		return "SettingsButton basılınca panel açılmalı"

	# Tekrar tıkla -> panel kapanmalı
	btn._on_pressed()
	if btn.panel.visible:
		_cleanup_node(btn)
		return "SettingsButton tekrar basılınca panel kapanmalı"

	_cleanup_node(btn)
	return ""


func test_server_address_in_settings() -> String:
	var P: GDScript = load("res://src/ui/settings_panel.gd")
	var p: Control = P.new()
	p.set("settings_path", "user://test_settings_server.cfg")
	var bad: bool = p.call("apply_server", "boşluklu adres ://")
	var good: bool = p.call("apply_server", "https://abc-def.trycloudflare.com")
	var LS: GDScript = load("res://src/core/local_settings.gd")
	var saved: String = str(LS.call("load_or_default", "user://test_settings_server.cfg").get("server_address"))
	p.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_settings_server.cfg"))
	if bad or not good:
		return "doğrulama yanlış: kötü=%s iyi=%s" % [bad, good]
	if saved != "https://abc-def.trycloudflare.com":
		return "adres kaydedilmedi: %s" % saved
	return ""
