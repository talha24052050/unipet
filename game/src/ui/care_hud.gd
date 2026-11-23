extends Control
## Pet bakımı arayüzü: Sol üstte durum çubukları (tokluk, mutluluk, enerji),
## sağ altta bakım butonları (Ye, Dinlen, Oyna) ve uyarı/toast bildirimleri.

const PetCareRules := preload("res://src/care/pet_care_rules.gd")

const COLOR_GREEN: Color = Color(0.2, 0.8, 0.2, 1.0)
const COLOR_YELLOW: Color = Color(0.95, 0.8, 0.15, 1.0)
const COLOR_RED: Color = Color(0.9, 0.25, 0.2, 1.0)

const TOAST_DEFAULT_DURATION: float = 2.0
const SPOT_CHECK_INTERVAL: float = 0.3
const DECAY_INTERVAL: float = 1.0

const EAT_WARNING_TEXT: String = "Yemek için Yemekhane, Hokka ya da Kayıntı'ya git"
const EAT_FADED_ALPHA: float = 0.45

@export var player: Node3D

@onready var _mood_label: Label = %MoodWarningLabel
@onready var _food_label: Label = %FoodLabel
@onready var _food_bar: ProgressBar = %FoodBar
@onready var _joy_label: Label = %JoyLabel
@onready var _joy_bar: ProgressBar = %JoyBar
@onready var _energy_label: Label = %EnergyLabel
@onready var _energy_bar: ProgressBar = %EnergyBar

@onready var _eat_btn: Button = %EatButton
@onready var _rest_btn: Button = %RestButton
@onready var _play_btn: Button = %PlayButton

@onready var _toast_container: Control = %ToastContainer
@onready var _toast_label: Label = %ToastLabel

var _current_state: Dictionary = {}
var _last_action_time: Dictionary = {}
var _pending_action: String = ""

var _decay_accum: float = 0.0
var _spot_accum: float = 0.0
var _toast_timer: float = 0.0

var _fill_green: StyleBoxFlat
var _fill_yellow: StyleBoxFlat
var _fill_red: StyleBoxFlat


func _ready() -> void:
	_init_styles()
	_ensure_nodes()
	if _current_state.is_empty():
		_current_state = PetCareRules.new_state(int(Time.get_unix_time_from_system()))
	_connect_signals()
	_update_bars()
	_update_mood()
	_update_buttons()
	if _toast_container != null:
		_toast_container.visible = false


func _init_styles() -> void:
	if _fill_green != null:
		return
	_fill_green = StyleBoxFlat.new()
	_fill_green.bg_color = COLOR_GREEN
	_fill_green.corner_radius_top_left = 4
	_fill_green.corner_radius_top_right = 4
	_fill_green.corner_radius_bottom_right = 4
	_fill_green.corner_radius_bottom_left = 4

	_fill_yellow = StyleBoxFlat.new()
	_fill_yellow.bg_color = COLOR_YELLOW
	_fill_yellow.corner_radius_top_left = 4
	_fill_yellow.corner_radius_top_right = 4
	_fill_yellow.corner_radius_bottom_right = 4
	_fill_yellow.corner_radius_bottom_left = 4

	_fill_red = StyleBoxFlat.new()
	_fill_red.bg_color = COLOR_RED
	_fill_red.corner_radius_top_left = 4
	_fill_red.corner_radius_top_right = 4
	_fill_red.corner_radius_bottom_right = 4
	_fill_red.corner_radius_bottom_left = 4


func _ensure_nodes() -> void:
	if _mood_label == null and has_node("%MoodWarningLabel"):
		_mood_label = get_node("%MoodWarningLabel") as Label
	if _food_label == null and has_node("%FoodLabel"):
		_food_label = get_node("%FoodLabel") as Label
	if _food_bar == null and has_node("%FoodBar"):
		_food_bar = get_node("%FoodBar") as ProgressBar
	if _joy_label == null and has_node("%JoyLabel"):
		_joy_label = get_node("%JoyLabel") as Label
	if _joy_bar == null and has_node("%JoyBar"):
		_joy_bar = get_node("%JoyBar") as ProgressBar
	if _energy_label == null and has_node("%EnergyLabel"):
		_energy_label = get_node("%EnergyLabel") as Label
	if _energy_bar == null and has_node("%EnergyBar"):
		_energy_bar = get_node("%EnergyBar") as ProgressBar
	if _eat_btn == null and has_node("%EatButton"):
		_eat_btn = get_node("%EatButton") as Button
	if _rest_btn == null and has_node("%RestButton"):
		_rest_btn = get_node("%RestButton") as Button
	if _play_btn == null and has_node("%PlayButton"):
		_play_btn = get_node("%PlayButton") as Button
	if _toast_container == null and has_node("%ToastContainer"):
		_toast_container = get_node("%ToastContainer") as Control
	if _toast_label == null and has_node("%ToastLabel"):
		_toast_label = get_node("%ToastLabel") as Label


func _connect_signals() -> void:
	if Services.net != null and not Services.net.care_updated.is_connected(_on_care_updated):
		Services.net.care_updated.connect(_on_care_updated)
	if Services.lifecycle != null and not Services.lifecycle.app_resumed.is_connected(_on_app_resumed):
		Services.lifecycle.app_resumed.connect(_on_app_resumed)
	if _eat_btn != null and not _eat_btn.pressed.is_connected(_on_eat_pressed):
		_eat_btn.pressed.connect(_on_eat_pressed)
	if _rest_btn != null and not _rest_btn.pressed.is_connected(_on_rest_pressed):
		_rest_btn.pressed.connect(_on_rest_pressed)
	if _play_btn != null and not _play_btn.pressed.is_connected(_on_play_pressed):
		_play_btn.pressed.connect(_on_play_pressed)


func _exit_tree() -> void:
	if Services != null and Services.lifecycle != null and Services.lifecycle.app_resumed.is_connected(_on_app_resumed):
		Services.lifecycle.app_resumed.disconnect(_on_app_resumed)


func _on_app_resumed(_away_seconds: float) -> void:
	var now: int = int(Time.get_unix_time_from_system())
	_current_state = PetCareRules.decay(_current_state, now)
	_update_bars()
	_update_mood()
	_update_buttons()


func _process(delta: float) -> void:
	_process_toast(delta)
	_update_buttons()

	_spot_accum += delta
	if _spot_accum >= SPOT_CHECK_INTERVAL:
		_spot_accum = 0.0
		_update_eat_button_spot_visual()

	_decay_accum += delta
	if _decay_accum >= DECAY_INTERVAL:
		_decay_accum = fmod(_decay_accum, DECAY_INTERVAL)
		var now: int = int(Time.get_unix_time_from_system())
		_current_state = PetCareRules.decay(_current_state, now)
		_update_bars()
		_update_mood()


func _process_toast(delta: float) -> void:
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0:
			_toast_timer = 0.0
			if _toast_container != null:
				_toast_container.visible = false


func _on_eat_pressed() -> void:
	Sfx.play(&"ui_click")
	if get_cooldown_remaining("eat") > 0.0:
		return
	var pos: Vector3 = _get_player_position()
	if not PetCareRules.near_spot("eat", pos):
		show_toast(EAT_WARNING_TEXT, TOAST_DEFAULT_DURATION)
		return
	_trigger_care_action("eat")


func _on_rest_pressed() -> void:
	Sfx.play(&"ui_click")
	if get_cooldown_remaining("rest") > 0.0:
		return
	_trigger_care_action("rest")


func _on_play_pressed() -> void:
	Sfx.play(&"ui_click")
	if get_cooldown_remaining("play") > 0.0:
		return
	_trigger_care_action("play")


func _trigger_care_action(action: String) -> void:
	_pending_action = action
	if Services.net != null:
		Services.net.send_care_action(action)


func _on_care_updated(state: Dictionary, ok: bool, reason: String) -> void:
	if not state.is_empty():
		_current_state = state.duplicate()
		_update_bars()
		_update_mood()
	if ok:
		if not _pending_action.is_empty():
			Sfx.play(&"care_ok")  # sadece oyuncunun eylemine yanıt; odaya katılımdaki ilk durum sessiz
			var act: String = _pending_action
			_last_action_time[act] = int(Time.get_unix_time_from_system())
			_pending_action = ""
			if act == "eat" or act == "play":
				_play_care_emote(&"emote_dance")
			elif act == "rest":
				_play_care_emote(&"emote_yes")
		_update_buttons()
	else:
		Sfx.play(&"care_fail")
		_pending_action = ""
		if not reason.is_empty():
			show_toast(reason, TOAST_DEFAULT_DURATION)


func _update_bars() -> void:
	_ensure_nodes()
	if _fill_green == null:
		_init_styles()
	var f: float = clampf(float(_current_state.get("food", 100.0)), 0.0, 100.0)
	var j: float = clampf(float(_current_state.get("joy", 100.0)), 0.0, 100.0)
	var e: float = clampf(float(_current_state.get("energy", 100.0)), 0.0, 100.0)

	_apply_stat_to_bar(_food_bar, _food_label, "Tokluk", f)
	_apply_stat_to_bar(_joy_bar, _joy_label, "Mutluluk", j)
	_apply_stat_to_bar(_energy_bar, _energy_label, "Enerji", e)


func _apply_stat_to_bar(bar: ProgressBar, label: Label, stat_name: String, val: float) -> void:
	if label != null:
		label.text = "%s %%%d" % [stat_name, roundi(val)]
	if bar != null:
		bar.value = val
		bar.add_theme_stylebox_override("fill", _get_fill_style(val))


func _get_fill_style(val: float) -> StyleBoxFlat:
	if val > 50.0:
		return _fill_green
	if val >= 20.0:
		return _fill_yellow
	return _fill_red


func _update_mood() -> void:
	_ensure_nodes()
	if _mood_label == null:
		return
	var mood_val: StringName = PetCareRules.mood(_current_state)
	if mood_val == &"sad":
		var f: float = float(_current_state.get("food", 100.0))
		var j: float = float(_current_state.get("joy", 100.0))
		var e: float = float(_current_state.get("energy", 100.0))

		if f <= j and f <= e:
			_mood_label.text = "Petin acıktı"
		elif e <= j and e <= f:
			_mood_label.text = "Petin yoruldu"
		else:
			_mood_label.text = "Petin sıkıldı"
		_mood_label.visible = true
	else:
		_mood_label.visible = false


func _update_buttons() -> void:
	_ensure_nodes()
	_update_action_button("eat", _eat_btn, "Ye")
	_update_action_button("rest", _rest_btn, "Dinlen")
	_update_action_button("play", _play_btn, "Oyna")
	_update_eat_button_spot_visual()


func _update_action_button(action: String, btn: Button, base_text: String) -> void:
	if btn == null:
		return
	var cd: float = get_cooldown_remaining(action)
	if cd > 0.0:
		btn.disabled = true
		btn.text = "%s (%ds)" % [base_text, ceili(cd)]
	else:
		btn.disabled = false
		# Bonus yerindeyse (ör. Stadyumda Oyna) butonda "2×" görünsün.
		var bonus: float = PetCareRules.bonus_for(action, _get_player_position())
		btn.text = "%s %d×" % [base_text, int(bonus)] if bonus > 1.0 else base_text


func _update_eat_button_spot_visual() -> void:
	if _eat_btn == null:
		return
	var cd: float = get_cooldown_remaining("eat")
	var is_near: bool = PetCareRules.near_spot("eat", _get_player_position())
	if cd > 0.0:
		_eat_btn.modulate = Color(1.0, 1.0, 1.0, EAT_FADED_ALPHA)
	elif is_near:
		_eat_btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		_eat_btn.modulate = Color(1.0, 1.0, 1.0, EAT_FADED_ALPHA)


func get_cooldown_remaining(action: String) -> float:
	if not PetCareRules.ACTIONS.has(action):
		return 0.0
	var cd: float = float(PetCareRules.ACTIONS[action].get("cooldown", 0))
	var last_t: int = int(_last_action_time.get(action, 0))
	if last_t <= 0:
		return 0.0
	var now: int = int(Time.get_unix_time_from_system())
	var passed: int = now - last_t
	var remaining: float = cd - float(passed)
	return maxf(0.0, remaining)


func set_action_time(action: String, timestamp: int) -> void:
	_last_action_time[action] = timestamp
	_update_buttons()


func is_eat_active() -> bool:
	if get_cooldown_remaining("eat") > 0.0:
		return false
	return PetCareRules.near_spot("eat", _get_player_position())


func get_current_state() -> Dictionary:
	return _current_state.duplicate()


func set_state(state: Dictionary) -> void:
	_current_state = state.duplicate()
	_update_bars()
	_update_mood()


func show_toast(text: String, duration: float = TOAST_DEFAULT_DURATION) -> void:
	_ensure_nodes()
	if text.is_empty():
		return
	if _toast_label != null:
		_toast_label.text = text
	if _toast_container != null:
		_toast_container.visible = true
	_toast_timer = duration


func get_toast_text() -> String:
	_ensure_nodes()
	return _toast_label.text if _toast_label != null else ""


func is_toast_visible() -> bool:
	_ensure_nodes()
	return _toast_container != null and _toast_container.visible


func get_mood_warning_text() -> String:
	_ensure_nodes()
	return _mood_label.text if _mood_label != null else ""


func is_mood_warning_visible() -> bool:
	_ensure_nodes()
	return _mood_label != null and _mood_label.visible


func _play_care_emote(anim: StringName) -> void:
	Sfx.play(&"emote")
	var p: Node3D = _get_player()
	if p != null and "visual" in p and p.visual != null:
		if p.visual.has_method("play_emote"):
			p.visual.play_emote(anim)


func _get_player() -> Node3D:
	if player != null and is_instance_valid(player):
		return player
	if not is_inside_tree():
		return null
	if has_node("../../Player"):
		return get_node("../../Player") as Node3D
	if has_node("../Player"):
		return get_node("../Player") as Node3D
	if owner != null and owner.has_node("Player"):
		return owner.get_node("Player") as Node3D
	var tree: SceneTree = get_tree()
	if tree != null and tree.current_scene != null:
		var p: Node = tree.current_scene.get_node_or_null("Player")
		if p is Node3D:
			return p as Node3D
	return null


func _get_player_position() -> Vector3:
	var p: Node3D = _get_player()
	if p != null and is_instance_valid(p):
		if p.is_inside_tree():
			return p.global_position
		return p.position
	return Vector3.ZERO
