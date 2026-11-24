extends Button
## Oyun ekranındaki "Harita" butonu: 3B dünyayı yıkmadan kampüs haritasını anlık katman (overlay) olarak açar.
## "Kapat" veya "Git" (ışınlan) tıklandığında sahne yeniden yüklenmez; 0 ms gecikmeyle oyuna dönülür.

const CampusMapScene := preload("res://scenes/ui/campus_map.tscn")

## Konumu iletilecek oyuncu (boşsa ../../Player denenir).
@export var player: Node3D

var _layer: CanvasLayer = null
var _map: Control = null


func _ready() -> void:
	if not pressed.is_connected(_open):
		pressed.connect(_open)


func _exit_tree() -> void:
	if _layer != null and is_instance_valid(_layer):
		_layer.queue_free()
		_layer = null
		_map = null


func _find_main_root() -> Node:
	if get_tree() != null and get_tree().current_scene != null:
		return get_tree().current_scene
	if owner != null:
		return owner
	if get_parent() != null and get_parent().get_parent() != null:
		return get_parent().get_parent()
	return get_parent()


func _ensure_overlay() -> void:
	if _map != null and is_instance_valid(_map):
		return
	var scene_root: Node = _find_main_root()
	_layer = CanvasLayer.new()
	_layer.name = "MapOverlayLayer"
	_layer.layer = 20
	_layer.visible = false
	scene_root.add_child(_layer)

	_map = CampusMapScene.instantiate() as Control
	_map.set("overlay_mode", true)
	_map.connect("closed", _on_map_closed)
	_map.connect("teleport_requested", _on_teleport_requested)
	_layer.add_child(_map)


func _open() -> void:
	Sfx.play(&"ui_click")
	_ensure_overlay()
	# Açık pet veya ayar katmanı varsa kapat
	var scene_root: Node = _find_main_root()
	if scene_root != null:
		var pet_btn: Node = scene_root.get_node_or_null("UI/PetButton")
		if pet_btn != null and pet_btn.has_method("close_overlay"):
			pet_btn.call("close_overlay")
		var set_btn: Node = scene_root.get_node_or_null("UI/SettingsButton")
		if set_btn != null and set_btn.has_method("close_panel"):
			set_btn.call("close_panel")
		var joy: Node = scene_root.get_node_or_null("UI/Joystick")
		if joy != null and joy.has_method("_release"):
			joy.call("_release")

	var p: Node3D = _resolve_player()
	_layer.visible = true
	_map.call("open_overlay", p.global_position if p != null else Vector3.INF)


func close_overlay() -> void:
	if _layer != null and is_instance_valid(_layer):
		_layer.visible = false
	if _map != null and is_instance_valid(_map):
		_map.visible = false


func _on_map_closed() -> void:
	if _layer != null and is_instance_valid(_layer):
		_layer.visible = false


func _on_teleport_requested(target_xz: Vector2, _place: Dictionary) -> void:
	if _layer != null and is_instance_valid(_layer):
		_layer.visible = false
	var scene_root: Node = _find_main_root()
	var p: Node3D = _resolve_player()
	if scene_root != null:
		var ctrl: Node = scene_root.get_node_or_null("PlayerController")
		if ctrl != null and ctrl.has_method("clear_destination"):
			ctrl.call("clear_destination")
	if p != null and p.has_method("teleport_to"):
		p.call("teleport_to", target_xz)
	if scene_root != null:
		var cam_rig: Node = scene_root.get_node_or_null("FollowCamera")
		if cam_rig != null and cam_rig.has_method("snap_to_target"):
			cam_rig.call("snap_to_target")
		var net_sync: Node = scene_root.get_node_or_null("NetworkSync")
		if net_sync != null and net_sync.has_method("notify_local_teleport"):
			net_sync.call("notify_local_teleport")


func _resolve_player() -> Node3D:
	if player != null:
		return player
	return get_node_or_null("../../Player") as Node3D
