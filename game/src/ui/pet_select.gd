class_name PetSelect
extends Control

const PetVisual := preload("res://src/characters/pet_visual.gd")
const LocalProfile := preload("res://src/core/local_profile.gd")

const SLOT_NAMES: Dictionary = {
	&"head": "Kafa",
	&"face": "Yüz",
	&"neck": "Boyun",
	&"back": "Sırt",
}

const ROTATION_SPEED: float = 0.5
const LOGIN_SCENE: String = "res://scenes/ui/login.tscn"
const LOGOUT_FONT_SIZE: int = 28
const DRAG_SENSITIVITY: float = 0.01

@export var profile_path: String = LocalProfile.PATH

var profile: LocalProfile
var _selectable_pets: Array[CharacterDef] = []
var _current_pet_index: int = 0
var _is_dragging: bool = false
var _drag_pause_timer: float = 0.0
var _accessory_labels: Dictionary = {}

@onready var _pet_pivot: Node3D = %PetPivot
@onready var _pet_visual: PetVisual = %PetVisual
@onready var _pet_name_label: Label = %PetNameLabel
@onready var _prev_pet_btn: Button = %PrevPetButton
@onready var _next_pet_btn: Button = %NextPetButton
@onready var _start_btn: Button = %StartButton
@onready var _viewport_container: SubViewportContainer = %ViewportContainer


func _ready() -> void:
	_setup_ui()
	_selectable_pets = Services.characters.selectable()
	load_selection(profile_path)
	_connect_signals()
	_add_logout_button()


## Sol üstte "Çıkış": oturumu kapatır, giriş ekranına döner (sunucu adresi/takma ad orada değişir).
func _add_logout_button() -> void:
	var b: Button = Button.new()
	b.name = "LogoutButton"
	b.text = "Çıkış"
	b.add_theme_font_size_override("font_size", LOGOUT_FONT_SIZE)
	b.position = Vector2(16, 16)
	b.custom_minimum_size = Vector2(140, 96)
	b.pressed.connect(func() -> void:
		b.disabled = true  # çift basış iki kez çıkış/sahne değişimi yapmasın
		_logout())
	add_child(b)


func _logout() -> void:
	Sfx.play(&"ui_click")
	if Services.net != null:
		Services.net.disconnect_from_server()  # aynı cihazda başka hesapla girilirse eski Nakama oturumu kalmasın
	await Services.auth.sign_out()  # oturum dosyası silinmeden giriş ekranı açılırsa eski oturumu geri yüklüyordu
	get_tree().change_scene_to_file(LOGIN_SCENE)


func _setup_ui() -> void:
	if has_node("%HeadAccessoryLabel"):
		_accessory_labels[&"head"] = %HeadAccessoryLabel
	if has_node("%FaceAccessoryLabel"):
		_accessory_labels[&"face"] = %FaceAccessoryLabel
	if has_node("%NeckAccessoryLabel"):
		_accessory_labels[&"neck"] = %NeckAccessoryLabel
	if has_node("%BackAccessoryLabel"):
		_accessory_labels[&"back"] = %BackAccessoryLabel


func _connect_signals() -> void:
	if _prev_pet_btn != null and not _prev_pet_btn.pressed.is_connected(prev_pet):
		_prev_pet_btn.pressed.connect(prev_pet)
	if _next_pet_btn != null and not _next_pet_btn.pressed.is_connected(next_pet):
		_next_pet_btn.pressed.connect(next_pet)
	if _start_btn != null and not _start_btn.pressed.is_connected(start_game):
		_start_btn.pressed.connect(start_game)
	if _viewport_container != null and not _viewport_container.gui_input.is_connected(_on_viewport_gui_input):
		_viewport_container.gui_input.connect(_on_viewport_gui_input)

	if has_node("%HeadChangeButton") and not (%HeadChangeButton as Button).pressed.is_connected(_on_head_change_pressed):
		(%HeadChangeButton as Button).pressed.connect(_on_head_change_pressed)
	if has_node("%FaceChangeButton") and not (%FaceChangeButton as Button).pressed.is_connected(_on_face_change_pressed):
		(%FaceChangeButton as Button).pressed.connect(_on_face_change_pressed)
	if has_node("%NeckChangeButton") and not (%NeckChangeButton as Button).pressed.is_connected(_on_neck_change_pressed):
		(%NeckChangeButton as Button).pressed.connect(_on_neck_change_pressed)
	if has_node("%BackChangeButton") and not (%BackChangeButton as Button).pressed.is_connected(_on_back_change_pressed):
		(%BackChangeButton as Button).pressed.connect(_on_back_change_pressed)


func _on_head_change_pressed() -> void:
	Sfx.play(&"ui_click")
	cycle_accessory(&"head")


func _on_face_change_pressed() -> void:
	Sfx.play(&"ui_click")
	cycle_accessory(&"face")


func _on_neck_change_pressed() -> void:
	Sfx.play(&"ui_click")
	cycle_accessory(&"neck")


func _on_back_change_pressed() -> void:
	Sfx.play(&"ui_click")
	cycle_accessory(&"back")


func _process(delta: float) -> void:
	if _drag_pause_timer > 0.0:
		_drag_pause_timer -= delta
	elif _pet_pivot != null:
		_pet_pivot.rotation.y += delta * ROTATION_SPEED


func _on_viewport_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		_drag_yaw(event.relative.x)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_is_dragging = true
			_drag_pause_timer = 3.0
		else:
			_is_dragging = false
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_is_dragging = event.pressed
			if event.pressed:
				_drag_pause_timer = 3.0
	elif event is InputEventMouseMotion and _is_dragging:
		_drag_yaw(event.relative.x)


func _drag_yaw(dx: float) -> void:
	if _pet_pivot != null:
		_pet_pivot.rotation.y += dx * DRAG_SENSITIVITY
	_drag_pause_timer = 3.0


func set_pet_index(index: int, play_emote: bool = true) -> void:
	if _selectable_pets.is_empty():
		_selectable_pets = Services.characters.selectable()
	if _selectable_pets.is_empty():
		return
	_current_pet_index = posmod(index, _selectable_pets.size())
	var def: CharacterDef = _selectable_pets[_current_pet_index]
	if profile == null:
		profile = LocalProfile.load_or_default()
	profile.pet_id = def.id
	if _pet_name_label != null:
		_pet_name_label.text = def.display_name
	if _pet_visual != null:
		_pet_visual.set_character(def)
		if play_emote:
			_pet_visual.play_emote(&"emote_wave")
			Sfx.play(&"emote")
	_apply_profile_accessories_to_visual()


func next_pet() -> void:
	Sfx.play(&"ui_click")
	set_pet_index(_current_pet_index + 1, true)


func prev_pet() -> void:
	Sfx.play(&"ui_click")
	set_pet_index(_current_pet_index - 1, true)


func cycle_accessory(slot: StringName) -> void:
	if profile == null:
		profile = LocalProfile.load_or_default()
	var available: Array[AccessoryDef] = Services.accessories.for_slot(slot)
	if available.is_empty():
		profile.accessories.erase(slot)
		if _pet_visual != null:
			_pet_visual.unequip(slot)
		_update_slot_label(slot)
		return

	var current_id: StringName = profile.accessories.get(slot, &"")
	var current_idx: int = 0
	for i: int in available.size():
		if available[i].id == current_id:
			current_idx = i + 1
			break

	var next_idx: int = (current_idx + 1) % (available.size() + 1)
	if next_idx == 0:
		profile.accessories.erase(slot)
		if _pet_visual != null:
			_pet_visual.unequip(slot)
	else:
		var acc: AccessoryDef = available[next_idx - 1]
		profile.accessories[slot] = acc.id
		if _pet_visual != null:
			_pet_visual.equip(acc)

	_update_slot_label(slot)


func _apply_profile_accessories_to_visual() -> void:
	if profile == null:
		return
	for slot: StringName in CharacterDef.ACCESSORY_SLOTS:
		var acc_id: StringName = profile.accessories.get(slot, &"")
		if not acc_id.is_empty():
			var acc: AccessoryDef = Services.accessories.get_def(acc_id)
			if acc != null and _pet_visual != null:
				_pet_visual.equip(acc)
		elif _pet_visual != null:
			_pet_visual.unequip(slot)
		_update_slot_label(slot)


func _update_slot_label(slot: StringName) -> void:
	var label: Label = _accessory_labels.get(slot)
	if label == null:
		return
	var acc_id: StringName = profile.accessories.get(slot, &"") if profile != null else &""
	if acc_id.is_empty():
		label.text = "Yok"
	else:
		var acc: AccessoryDef = Services.accessories.get_def(acc_id)
		label.text = acc.display_name if acc != null else "Yok"


func save_selection(path: String = "") -> Error:
	var target_path: String = path if not path.is_empty() else profile_path
	if profile == null:
		profile = LocalProfile.load_or_default()
	if Services.profile_sync != null:
		Services.profile_sync.push(profile)
	return profile.save(target_path)


func load_selection(path: String = "") -> void:
	var target_path: String = path if not path.is_empty() else profile_path
	profile = LocalProfile.load_or_default(target_path)
	if _selectable_pets.is_empty():
		_selectable_pets = Services.characters.selectable()
	var idx: int = 0
	for i: int in _selectable_pets.size():
		if _selectable_pets[i].id == profile.pet_id:
			idx = i
			break
	set_pet_index(idx, false)


func start_game() -> void:
	Sfx.play(&"ui_click")
	save_selection()
	get_tree().change_scene_to_file("res://scenes/main.tscn")
