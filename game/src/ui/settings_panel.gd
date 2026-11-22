extends PanelContainer
## Ses ve genel ayarlar paneli: Ses efektleri aç/kapa, ses düzeyi ayarı ve kapatma butonu.
## LocalSettings (user://settings.cfg) ve Sfx autoload ile anında senkronize olur.

signal closed

const LocalSettings := preload("res://src/core/local_settings.gd")

const PANEL_WIDTH: float = 560.0
const PANEL_HEIGHT: float = 960.0
const MAIN_SCENE: String = "res://scenes/main.tscn"
const MIN_CONTROL_HEIGHT: float = 64.0
const FONT_SIZE_TITLE: int = 32
const FONT_SIZE_CONTROLS: int = 28
const FONT_SIZE_LABEL: int = 26
const SLIDER_MIN: float = -30.0
const SLIDER_MAX: float = 6.0
const SLIDER_STEP: float = 1.0

var settings_path: String = LocalSettings.PATH

var title_label: Label
var check_button: CheckButton
var volume_label: Label
var volume_slider: HSlider
var close_button: Button
var feedback_input: TextEdit
var feedback_button: Button
var feedback_status: Label
## Arkadaşlarla oynama: kayıtlı oturumda giriş ekranı atlandığı için sunucu adresi burada da değiştirilebilir.
var server_input: LineEdit
var server_button: Button
var server_status: Label
const FEEDBACK_INPUT_HEIGHT: float = 140.0

# Erişilebilirlik ve test kolaylığı için kısayol
var check_box: CheckButton:
	get:
		return check_button


func _init() -> void:
	add_to_group(&"joystick_blocker")  # açıkken joystick bu alandaki dokunuşları almasın
	visible = false
	z_index = 10
	mouse_filter = Control.MOUSE_FILTER_STOP
	_setup_panel_style()
	_setup_layout()
	_connect_signals()
	refresh_from_settings()


func _setup_panel_style() -> void:
	custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	anchors_preset = Control.PRESET_CENTER
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	offset_left = -PANEL_WIDTH * 0.5
	offset_right = PANEL_WIDTH * 0.5
	offset_top = -PANEL_HEIGHT * 0.5
	offset_bottom = PANEL_HEIGHT * 0.5
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.18, 0.96)
	style.set_corner_radius_all(16)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.35, 0.42, 0.55, 0.9)
	style.content_margin_left = 32.0
	style.content_margin_right = 32.0
	style.content_margin_top = 28.0
	style.content_margin_bottom = 28.0
	add_theme_stylebox_override("panel", style)


func _setup_layout() -> void:
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.name = "ContentBox"
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(vbox)

	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "Ayarlar"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.custom_minimum_size = Vector2(0, MIN_CONTROL_HEIGHT)
	title_label.add_theme_font_size_override("font_size", FONT_SIZE_TITLE)
	vbox.add_child(title_label)

	check_button = CheckButton.new()
	check_button.name = "CheckButton"
	check_button.text = "Ses efektleri"
	check_button.custom_minimum_size = Vector2(0, MIN_CONTROL_HEIGHT)
	check_button.add_theme_font_size_override("font_size", FONT_SIZE_CONTROLS)
	check_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(check_button)

	var slider_box: VBoxContainer = VBoxContainer.new()
	slider_box.name = "SliderBox"
	slider_box.add_theme_constant_override("separation", 6)
	slider_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	volume_label = Label.new()
	volume_label.name = "VolumeLabel"
	volume_label.text = "Ses düzeyi"
	volume_label.add_theme_font_size_override("font_size", FONT_SIZE_LABEL)
	slider_box.add_child(volume_label)

	volume_slider = HSlider.new()
	volume_slider.name = "VolumeSlider"
	volume_slider.min_value = SLIDER_MIN
	volume_slider.max_value = SLIDER_MAX
	volume_slider.step = SLIDER_STEP
	volume_slider.custom_minimum_size = Vector2(0, MIN_CONTROL_HEIGHT)
	volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider_box.add_child(volume_slider)

	vbox.add_child(slider_box)

	# Geri bildirim (kapalı test): kısa metin → Services.feedback
	feedback_input = TextEdit.new()
	feedback_input.name = "FeedbackInput"
	feedback_input.placeholder_text = "Geri bildirim: hata, öneri, ne istersen…"
	feedback_input.custom_minimum_size = Vector2(0, FEEDBACK_INPUT_HEIGHT)
	feedback_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	feedback_input.add_theme_font_size_override("font_size", FONT_SIZE_LABEL)
	vbox.add_child(feedback_input)
	feedback_button = Button.new()
	feedback_button.name = "FeedbackButton"
	feedback_button.text = "Gönder"
	feedback_button.custom_minimum_size = Vector2(0, MIN_CONTROL_HEIGHT)
	feedback_button.add_theme_font_size_override("font_size", FONT_SIZE_CONTROLS)
	feedback_button.pressed.connect(_on_feedback_pressed)
	vbox.add_child(feedback_button)
	feedback_status = Label.new()
	feedback_status.name = "FeedbackStatus"
	feedback_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_status.add_theme_font_size_override("font_size", FONT_SIZE_LABEL - 4)
	vbox.add_child(feedback_status)

	server_input = LineEdit.new()
	server_input.name = "ServerInput"
	server_input.placeholder_text = "Sunucu adresi (boş = tek başına)"
	server_input.custom_minimum_size = Vector2(0, MIN_CONTROL_HEIGHT)
	server_input.add_theme_font_size_override("font_size", FONT_SIZE_LABEL)
	vbox.add_child(server_input)
	server_button = Button.new()
	server_button.name = "ServerButton"
	server_button.text = "Bağlan"
	server_button.custom_minimum_size = Vector2(0, MIN_CONTROL_HEIGHT)
	server_button.add_theme_font_size_override("font_size", FONT_SIZE_CONTROLS)
	server_button.pressed.connect(_on_server_pressed)
	vbox.add_child(server_button)
	server_status = Label.new()
	server_status.name = "ServerStatus"
	server_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	server_status.add_theme_font_size_override("font_size", FONT_SIZE_LABEL - 4)
	vbox.add_child(server_status)

	close_button = Button.new()
	close_button.name = "CloseButton"
	close_button.text = "Kapat"
	close_button.custom_minimum_size = Vector2(0, MIN_CONTROL_HEIGHT)
	close_button.add_theme_font_size_override("font_size", FONT_SIZE_CONTROLS)
	close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(close_button)


func _connect_signals() -> void:
	if check_button != null and not check_button.toggled.is_connected(_on_check_button_toggled):
		check_button.toggled.connect(_on_check_button_toggled)
	if volume_slider != null and not volume_slider.value_changed.is_connected(_on_volume_slider_changed):
		volume_slider.value_changed.connect(_on_volume_slider_changed)
	if close_button != null and not close_button.pressed.is_connected(_on_close_button_pressed):
		close_button.pressed.connect(_on_close_button_pressed)


func _on_check_button_toggled(toggled_on: bool) -> void:
	Sfx.enabled = toggled_on
	_save_settings()


func _on_volume_slider_changed(val: float) -> void:
	Sfx.volume_db = val
	_update_volume_label()
	_save_settings()


func _on_close_button_pressed() -> void:
	Sfx.play(&"ui_click")
	close()


func _on_feedback_pressed() -> void:
	var fb: Node = Services.feedback
	if fb == null:
		return
	feedback_button.disabled = true
	feedback_status.text = "Gönderiliyor…"
	if not fb.sent.is_connected(_on_feedback_sent):
		fb.sent.connect(_on_feedback_sent)
	fb.send(feedback_input.text)


func _on_feedback_sent(ok: bool, message: String) -> void:
	feedback_button.disabled = false
	feedback_status.text = message
	if ok:
		feedback_input.text = ""


func _update_volume_label() -> void:
	if volume_label != null:
		volume_label.text = "Ses düzeyi (%d dB)" % int(Sfx.volume_db)


func _save_settings() -> void:
	var s: RefCounted = LocalSettings.load_or_default(settings_path)
	s.set("sfx_enabled", Sfx.enabled)
	s.set("sfx_volume_db", Sfx.volume_db)
	var _err: Error = s.call("save", settings_path)


## Adresi doğrular, kaydeder, ağ servisini değiştirir ve oyun sahnesini yeniden yükler (yeni sunucuya bağlanır).
func apply_server(text: String) -> bool:
	var addr: String = text.strip_edges()
	if not addr.is_empty() and LocalSettings.parse_server_address(addr).is_empty():
		server_status.text = "Adres geçersiz. Örnek: 192.168.1.5 ya da https://xxx.trycloudflare.com"
		return false
	var s: RefCounted = LocalSettings.load_or_default(settings_path)
	s.set("server_address", addr)
	s.call("save", settings_path)
	server_status.text = "Bağlanılıyor…" if not addr.is_empty() else "Tek başına moda geçildi."
	return true


func _on_server_pressed() -> void:
	if not apply_server(server_input.text):
		return
	Services.net.leave_zone()
	Services.use_server(LocalSettings.effective_server(server_input.text.strip_edges(), Config.IS_RELEASE))
	close()
	get_tree().change_scene_to_file.call_deferred(MAIN_SCENE)


func refresh_from_settings() -> void:
	if server_input != null:
		server_input.text = str(LocalSettings.load_or_default(settings_path).get("server_address"))
	if check_button != null:
		check_button.set_pressed_no_signal(Sfx.enabled)
	if volume_slider != null:
		volume_slider.set_value_no_signal(Sfx.volume_db)
	_update_volume_label()


func open() -> void:
	refresh_from_settings()
	visible = true
	# Ağaç dışında ayarlanan çapalar CanvasLayer altında (0,0)'a göre kalıyor: açılırken ekranın ortasına al.
	if is_inside_tree():
		position = ((get_viewport_rect().size - size) * 0.5).floor()


func close() -> void:
	visible = false
	closed.emit()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func is_open() -> bool:
	return visible


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
