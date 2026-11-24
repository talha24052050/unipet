extends Button
## Oyun ekranındaki "Pet" butonu: 3B dünyayı yıkmadan Pet seçim/aksesuar ekranını anlık katman (overlay) olarak açar.
## Kaydedildiğinde oyuncunun görünümünü ve ağ profilini sahne içinde 0 ms gecikmeyle günceller.

const PetSelectScene := preload("res://scenes/ui/pet_select.tscn")
const LocalProfile := preload("res://src/core/local_profile.gd")

var _layer: CanvasLayer = null
var _pet_ui: Control = null


func _ready() -> void:
	if not pressed.is_connected(_open):
		pressed.connect(_open)


func _exit_tree() -> void:
	if _layer != null and is_instance_valid(_layer):
		_layer.queue_free()
		_layer = null
		_pet_ui = null


func _find_main_root() -> Node:
	if get_tree() != null and get_tree().current_scene != null:
		return get_tree().current_scene
	if owner != null:
		return owner
	if get_parent() != null and get_parent().get_parent() != null:
		return get_parent().get_parent()
	return get_parent()


func _ensure_overlay() -> void:
	if _pet_ui != null and is_instance_valid(_pet_ui):
		return
	var scene_root: Node = _find_main_root()
	_layer = CanvasLayer.new()
	_layer.name = "PetOverlayLayer"
	_layer.layer = 21
	_layer.visible = false
	scene_root.add_child(_layer)

	_pet_ui = PetSelectScene.instantiate() as Control
	_pet_ui.set("overlay_mode", true)
	_pet_ui.connect("closed", _on_pet_closed)
	_layer.add_child(_pet_ui)
	if _pet_ui.has_method("set_overlay_mode"):
		_pet_ui.call("set_overlay_mode", true)
	if _pet_ui.has_method("set_active"):
		_pet_ui.call("set_active", false)


func _open() -> void:
	Sfx.play(&"ui_click")
	_ensure_overlay()
	var scene_root: Node = _find_main_root()
	if scene_root != null:
		var map_btn: Node = scene_root.get_node_or_null("UI/MapButton")
		if map_btn != null and map_btn.has_method("close_overlay"):
			map_btn.call("close_overlay")
		var set_btn: Node = scene_root.get_node_or_null("UI/SettingsButton")
		if set_btn != null and set_btn.has_method("close_panel"):
			set_btn.call("close_panel")
		var joy: Node = scene_root.get_node_or_null("UI/Joystick")
		if joy != null and joy.has_method("_release"):
			joy.call("_release")

	_layer.visible = true
	if _pet_ui.has_method("set_active"):
		_pet_ui.call("set_active", true)


func close_overlay() -> void:
	if _layer != null and is_instance_valid(_layer):
		_layer.visible = false
	if _pet_ui != null and is_instance_valid(_pet_ui) and _pet_ui.has_method("set_active"):
		_pet_ui.call("set_active", false)


func _on_pet_closed(saved: bool) -> void:
	if _layer != null and is_instance_valid(_layer):
		_layer.visible = false
	if not saved:
		return
	var scene_root: Node = _find_main_root()
	if scene_root == null:
		return
	var p: Node = scene_root.get_node_or_null("Player")
	if p != null and p.has_method("apply_profile"):
		p.call("apply_profile", LocalProfile.load_or_default())
	var net_sync: Node = scene_root.get_node_or_null("NetworkSync")
	if net_sync != null and net_sync.has_method("send_local_profile"):
		net_sync.call("send_local_profile")
