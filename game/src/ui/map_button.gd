extends Button
## Oyun ekranındaki "Harita" butonu:
## - 3B dünyayı yıkmadan kampüs haritasını anlık katman (overlay) olarak açar.
## - Işınlanma kaldırıldı; haritadan veya sohbet konum pininden hedef işaretlendiğinde
##   3B dünyada parlayan hedef sütunu (WaypointBeacon3D) ve üst ekranda canlı mesafe/durak pusulası gösterir.

const CampusMapScene := preload("res://scenes/ui/campus_map.tscn")

@export var player: Node3D

var _layer: CanvasLayer = null
var _map: Control = null
var _beacon_3d: Node3D = null
var _hud_pill: PanelContainer = null
var _hud_label: Label = null


func _ready() -> void:
	if not pressed.is_connected(_open):
		pressed.connect(_open)
	if Services != null and Services.has_signal("waypoint_changed") and not Services.waypoint_changed.is_connected(_on_waypoint_changed):
		Services.waypoint_changed.connect(_on_waypoint_changed)
	if Services != null and not Services.active_waypoint.is_empty():
		_on_waypoint_changed(Services.active_waypoint)


func _process(_delta: float) -> void:
	if Services == null or Services.active_waypoint.is_empty():
		if _hud_pill != null:
			_hud_pill.visible = false
		if _beacon_3d != null:
			_beacon_3d.visible = false
		return
	var p: Node3D = _resolve_player()
	if p == null:
		return
	var wp_xz: Vector2 = Services.active_waypoint.get("pos", Vector2.ZERO)
	var dist: float = Vector2(p.global_position.x, p.global_position.z).distance_to(wp_xz)
	if dist <= 15.0:
		var arrived_name: String = str(Services.active_waypoint.get("name", "Hedef"))
		Services.clear_waypoint()
		Sfx.play(&"care_ok")
		var scene_root: Node = _find_main_root()
		if scene_root != null:
			var hud: Node = scene_root.find_child("CareHud", true, false)
			if hud != null and hud.has_method("show_toast"):
				hud.call("show_toast", "✓ %s hedefine ulaştın!" % arrived_name, 3.0)
		return
	if _hud_label != null:
		var nm: String = str(Services.active_waypoint.get("name", "Hedef"))
		var st_nm: String = str(Services.active_waypoint.get("stop", ""))
		var stop_hint: String = ("  ·  🚌 %s" % st_nm) if not st_nm.is_empty() else ""
		_hud_label.text = "🧭 %s · %d m%s" % [nm, roundi(dist), stop_hint]


func _exit_tree() -> void:
	if Services != null and Services.has_signal("waypoint_changed") and Services.waypoint_changed.is_connected(_on_waypoint_changed):
		Services.waypoint_changed.disconnect(_on_waypoint_changed)
	if _layer != null and is_instance_valid(_layer):
		_layer.queue_free()
		_layer = null
		_map = null
	if _beacon_3d != null and is_instance_valid(_beacon_3d):
		_beacon_3d.queue_free()
		_beacon_3d = null


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
	_map.connect("waypoint_requested", _on_waypoint_requested)
	_layer.add_child(_map)


func _ensure_waypoint_visuals() -> void:
	var scene_root: Node = _find_main_root()
	if scene_root == null:
		return
	if _beacon_3d == null or not is_instance_valid(_beacon_3d):
		_beacon_3d = Node3D.new()
		_beacon_3d.name = "WaypointBeacon3D"
		var beam_mi: MeshInstance3D = MeshInstance3D.new()
		var cyl: CylinderMesh = CylinderMesh.new()
		cyl.top_radius = 0.25
		cyl.bottom_radius = 0.55
		cyl.height = 26.0
		var bmat: StandardMaterial3D = StandardMaterial3D.new()
		bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bmat.albedo_color = Color(1.0, 0.78, 0.18, 0.34)
		cyl.material = bmat
		beam_mi.mesh = cyl
		beam_mi.position.y = 13.0
		beam_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_beacon_3d.add_child(beam_mi)

		var ring_mi: MeshInstance3D = MeshInstance3D.new()
		var torus: TorusMesh = TorusMesh.new()
		torus.inner_radius = 1.6
		torus.outer_radius = 2.1
		var rmat: StandardMaterial3D = StandardMaterial3D.new()
		rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rmat.albedo_color = Color(1.0, 0.76, 0.14, 0.92)
		torus.material = rmat
		ring_mi.mesh = torus
		ring_mi.position.y = 0.18
		ring_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_beacon_3d.add_child(ring_mi)
		scene_root.add_child(_beacon_3d)

	if _hud_pill == null or not is_instance_valid(_hud_pill):
		var ui_parent: Node = get_parent()
		_hud_pill = PanelContainer.new()
		_hud_pill.name = "WaypointHudPill"
		_hud_pill.offset_left = 24.0
		_hud_pill.offset_top = 258.0
		_hud_pill.offset_right = 396.0
		_hud_pill.offset_bottom = 306.0
		var st: StyleBoxFlat = StyleBoxFlat.new()
		st.bg_color = Color(0.08, 0.13, 0.22, 0.90)
		st.border_width_left = 2
		st.border_width_top = 2
		st.border_width_right = 2
		st.border_width_bottom = 2
		st.border_color = Color(1.0, 0.78, 0.24, 0.92)
		st.set_corner_radius_all(16)
		st.content_margin_left = 12.0
		st.content_margin_right = 8.0
		st.content_margin_top = 4.0
		st.content_margin_bottom = 4.0
		_hud_pill.add_theme_stylebox_override("panel", st)

		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_hud_pill.add_child(row)

		_hud_label = Label.new()
		_hud_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_hud_label.add_theme_font_size_override("font_size", 17)
		_hud_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.72))
		_hud_label.clip_text = true
		row.add_child(_hud_label)

		var x_btn: Button = Button.new()
		x_btn.text = "✕"
		x_btn.custom_minimum_size = Vector2(36, 36)
		x_btn.add_theme_font_size_override("font_size", 16)
		x_btn.pressed.connect(func() -> void:
			Sfx.play(&"ui_click")
			if Services != null:
				Services.clear_waypoint())
		row.add_child(x_btn)
		ui_parent.add_child(_hud_pill)


func _open() -> void:
	Sfx.play(&"ui_click")
	_ensure_overlay()
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


func _on_waypoint_requested(_target_xz: Vector2, _place: Dictionary) -> void:
	if _layer != null and is_instance_valid(_layer):
		_layer.visible = false


func _on_waypoint_changed(wp: Dictionary) -> void:
	if wp.is_empty():
		if _beacon_3d != null and is_instance_valid(_beacon_3d):
			_beacon_3d.visible = false
		if _hud_pill != null and is_instance_valid(_hud_pill):
			_hud_pill.visible = false
		return
	_ensure_waypoint_visuals()
	var xz: Vector2 = wp.get("pos", Vector2.ZERO)
	if _beacon_3d != null and is_instance_valid(_beacon_3d):
		_beacon_3d.global_position = Vector3(xz.x, TerrainHeight.active_height(xz.x, xz.y), xz.y)
		_beacon_3d.visible = true
	if _hud_pill != null and is_instance_valid(_hud_pill):
		_hud_pill.visible = true


func _resolve_player() -> Node3D:
	if player != null:
		return player
	return get_node_or_null("../../Player") as Node3D
