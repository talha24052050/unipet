extends Control
## Sohbet menüsü: Sağ alttaki butonla açılır, hazır cümleler ve emote'lar sunar.
## Seçilen mesajı Services.net üzerinden gönderir ve paneli kapatır.
## Gönderimler arası 1.5 sn cooldown uygular.

const ChatCatalog := preload("res://src/net/chat_catalog.gd")

const COOLDOWN_TIME: float = 1.5

var _catalog: RefCounted
var _cooldown: float = 0.0
var _preset_buttons: Array[Button] = []
var _emote_buttons: Array[Button] = []

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


func _ready() -> void:
	_ensure_nodes()
	if _catalog == null:
		_catalog = ChatCatalog.new()
	_populate_items()
	_connect_signals()
	if _panel_overlay != null:
		_panel_overlay.add_to_group(&"joystick_blocker")  # sohbet açıkken joystick dokunuşları almasın
	close_panel()


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
	if Services.net != null and not Services.net.chat_received.is_connected(_on_chat_received):
		Services.net.chat_received.connect(_on_chat_received)


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


func _on_chat_received(msg: ChatMessage) -> void:
	if msg == null:
		return
	if Services.net != null and msg.sender_id == Services.net.local_player_id():
		return
	Sfx.play(&"chat_receive")


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
	show_presets_tab()


func close_panel() -> void:
	_ensure_nodes()
	if _panel_overlay != null:
		_panel_overlay.visible = false


func toggle_panel() -> void:
	if is_panel_open():
		close_panel()
	else:
		open_panel()


func is_panel_open() -> bool:
	_ensure_nodes()
	return _panel_overlay != null and _panel_overlay.visible


func show_presets_tab() -> void:
	_ensure_nodes()
	if _presets_scroll != null:
		_presets_scroll.visible = true
	if _emotes_scroll != null:
		_emotes_scroll.visible = false
	if _presets_tab_button != null:
		_presets_tab_button.modulate = Color(1.0, 1.0, 1.0, 1.0)
	if _emotes_tab_button != null:
		_emotes_tab_button.modulate = Color(0.7, 0.7, 0.7, 1.0)


func show_emotes_tab() -> void:
	_ensure_nodes()
	if _presets_scroll != null:
		_presets_scroll.visible = false
	if _emotes_scroll != null:
		_emotes_scroll.visible = true
	if _presets_tab_button != null:
		_presets_tab_button.modulate = Color(0.7, 0.7, 0.7, 1.0)
	if _emotes_tab_button != null:
		_emotes_tab_button.modulate = Color(1.0, 1.0, 1.0, 1.0)


func send_preset(id: String) -> bool:
	if _cooldown > 0.0:
		return false
	if Services.net != null:
		Services.net.send_chat(ChatMessage.preset(id))
	Sfx.play(&"chat_send")
	_start_cooldown()
	close_panel()
	return true


func send_emote(id: String) -> bool:
	if _cooldown > 0.0:
		return false
	if Services.net != null:
		Services.net.send_chat(ChatMessage.emote(id))
	Sfx.play(&"chat_send")
	_start_cooldown()
	close_panel()
	return true


func _start_cooldown() -> void:
	_cooldown = COOLDOWN_TIME
	_update_cooldown_ui()


func _update_cooldown_ui() -> void:
	_ensure_nodes()
	var is_passive: bool = _cooldown > 0.0
	if _chat_button != null:
		_chat_button.disabled = is_passive
	for btn: Button in _preset_buttons:
		btn.disabled = is_passive
	for btn: Button in _emote_buttons:
		btn.disabled = is_passive


func get_cooldown() -> float:
	return _cooldown
