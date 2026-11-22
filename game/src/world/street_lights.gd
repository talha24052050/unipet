extends Node3D
## Ortabahçe ve kampüs bölgelerindeki sokak lambalarını yönetir.
## Gündüzleri kapalı/gizli; geceleri ampuller yanar ve oyuncuya en yakın en çok 4 lambada
## gerçek OmniLight3D ışıkları aktif olur (mobil bütçe kısıtı).

const DayNightScript := preload("res://src/world/day_night.gd")

const LAMP_HEIGHT: float = 3.5
const MAX_ACTIVE_LIGHTS: int = 4
const LIGHT_RANGE: float = 8.0
const LIGHT_ENERGY: float = 1.2
const LIGHT_COLOR: Color = Color(1.0, 0.88, 0.55)
const BULB_RADIUS: float = 0.2
const BULB_HEIGHT: float = 0.4
const BULB_COLOR: Color = Color(1.0, 0.94, 0.65)
const LIGHT_UPDATE_INTERVAL_S: float = 0.5
const DAY_NIGHT_CHECK_INTERVAL_S: float = 60.0

@export_file("*.json") var data_path: String = ""
@export var follow_current_zone: bool = true
@export var day_night: Node
@export var player: Node3D

var _lamp_positions: Array[Vector3] = []
var _bulb_multimesh: MultiMeshInstance3D
var _lights: Array[OmniLight3D] = []

var _is_day: bool = false
var _force_day_mode: int = -1  # -1 = auto, 0 = force night, 1 = force day

var _light_timer: float = 0.0
var _day_night_timer: float = 0.0

var bulb_count: int:
	get:
		return _lamp_positions.size()

var active_light_count: int:
	get:
		return get_active_light_count()


func _ready() -> void:
	if follow_current_zone and Services.zones != null and Services.zones.has(Services.current_zone):
		data_path = str(Services.zones.get_zone(Services.current_zone)["props"])
	if not data_path.is_empty():
		var data: Dictionary = load_data(data_path)
		if not data.is_empty():
			setup_lamps(data)
	_setup_omni_lights()
	_check_day_night()
	_update_lights()


func _process(delta: float) -> void:
	_day_night_timer += delta
	if _day_night_timer >= DAY_NIGHT_CHECK_INTERVAL_S:
		_day_night_timer = 0.0
		_check_day_night()

	_light_timer += delta
	if _light_timer >= LIGHT_UPDATE_INTERVAL_S:
		_light_timer = 0.0
		_update_lights()


func setup_lamps(data: Dictionary) -> void:
	_lamp_positions.clear()
	var prop_list: Array = data.get("props", [])
	for item_var: Variant in prop_list:
		if not item_var is Dictionary:
			continue
		var item: Dictionary = item_var
		if str(item.get("type", "")) != "lamp":
			continue
		var pos_arr: Array = item.get("pos", [0.0, 0.0])
		if pos_arr.size() >= 2:
			var px: float = float(pos_arr[0])
			var pz: float = float(pos_arr[1])
			_lamp_positions.append(Vector3(px, LAMP_HEIGHT, pz))

	if _bulb_multimesh != null and is_instance_valid(_bulb_multimesh):
		_bulb_multimesh.queue_free()
		_bulb_multimesh = null

	if _lamp_positions.is_empty():
		return

	_bulb_multimesh = MultiMeshInstance3D.new()
	_bulb_multimesh.name = "BulbMultiMesh"

	var sphere := SphereMesh.new()
	sphere.radius = BULB_RADIUS
	sphere.height = BULB_HEIGHT
	sphere.radial_segments = 8
	sphere.rings = 4

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = BULB_COLOR
	sphere.material = mat

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = sphere
	mm.instance_count = _lamp_positions.size()

	for i: int in range(_lamp_positions.size()):
		var t := Transform3D(Basis.IDENTITY, _lamp_positions[i])
		mm.set_instance_transform(i, t)

	_bulb_multimesh.multimesh = mm
	_bulb_multimesh.visible = not _is_day
	add_child(_bulb_multimesh)


func _setup_omni_lights() -> void:
	if not _lights.is_empty():
		return
	for i: int in range(MAX_ACTIVE_LIGHTS):
		var light := OmniLight3D.new()
		light.name = "StreetLight_%d" % i
		light.omni_range = LIGHT_RANGE
		light.omni_attenuation = 1.0
		light.light_color = LIGHT_COLOR
		light.light_energy = LIGHT_ENERGY
		light.shadow_enabled = false
		light.visible = false
		add_child(light)
		_lights.append(light)


func _check_day_night() -> void:
	if _force_day_mode >= 0:
		_is_day = _force_day_mode == 1
		_apply_visibility()
		return

	if day_night == null and is_inside_tree():
		day_night = get_node_or_null("../../DayNight")
		if day_night == null:
			day_night = get_tree().get_root().find_child("DayNight", true, false)

	var hour: float = -1.0
	if day_night != null and day_night.has_method("current_hour"):
		hour = float(day_night.call("current_hour"))
	else:
		var t: Dictionary = Time.get_time_dict_from_system()
		hour = float(t["hour"]) + float(t["minute"]) / 60.0

	var s: Dictionary = DayNightScript.sample(hour)
	_is_day = bool(s.get("is_day", true))
	_apply_visibility()


func _apply_visibility() -> void:
	if _bulb_multimesh != null and is_instance_valid(_bulb_multimesh):
		_bulb_multimesh.visible = not _is_day


func _update_lights() -> void:
	if _lights.is_empty():
		_setup_omni_lights()

	if _is_day or _lamp_positions.is_empty():
		for light: OmniLight3D in _lights:
			if is_instance_valid(light):
				light.visible = false
		return

	var target_pos: Vector3 = _get_target_position()
	var sorted_indices: Array[int] = _get_sorted_lamp_indices(target_pos)
	var count_to_activate: int = mini(MAX_ACTIVE_LIGHTS, sorted_indices.size())

	for i: int in range(count_to_activate):
		var light: OmniLight3D = _lights[i]
		if not is_instance_valid(light):
			continue
		var lamp_pos: Vector3 = _lamp_positions[sorted_indices[i]]
		if is_inside_tree():
			light.global_position = lamp_pos
		else:
			light.position = lamp_pos
		light.visible = true

	for i: int in range(count_to_activate, MAX_ACTIVE_LIGHTS):
		var light: OmniLight3D = _lights[i]
		if is_instance_valid(light):
			light.visible = false


func _get_target_position() -> Vector3:
	if player != null and is_instance_valid(player):
		return player.global_position if player.is_inside_tree() else player.position
	if is_inside_tree():
		var p: Node = get_node_or_null("../../Player")
		if p is Node3D and (p as Node3D).is_inside_tree():
			return (p as Node3D).global_position
		var found: Node = get_tree().get_root().find_child("Player", true, false)
		if found is Node3D and (found as Node3D).is_inside_tree():
			return (found as Node3D).global_position
		return global_position
	return position


func _get_sorted_lamp_indices(target_pos: Vector3) -> Array[int]:
	var entries: Array[Dictionary] = []
	for i: int in range(_lamp_positions.size()):
		var lpos: Vector3 = _lamp_positions[i]
		var dist_sq: float = lpos.distance_squared_to(target_pos)
		entries.append({"index": i, "dist_sq": dist_sq})

	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["dist_sq"]) < float(b["dist_sq"])
	)

	var result: Array[int] = []
	for entry: Dictionary in entries:
		result.append(int(entry["index"]))
	return result


func get_bulb_count() -> int:
	return _lamp_positions.size()


func get_active_light_count() -> int:
	var count: int = 0
	for light: OmniLight3D in _lights:
		if is_instance_valid(light) and light.visible:
			count += 1
	return count


func get_lights() -> Array[OmniLight3D]:
	return _lights


func get_lamp_positions() -> Array[Vector3]:
	return _lamp_positions


func set_day_mode(is_day_mode: bool) -> void:
	_force_day_mode = 1 if is_day_mode else 0
	_is_day = is_day_mode
	_apply_visibility()
	_update_lights()


func is_night() -> bool:
	return not _is_day


func is_day() -> bool:
	return _is_day


func update_lights() -> void:
	_update_lights()


func check_day_night() -> void:
	_check_day_night()


static func load_data(path: String) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return {}
	return parsed
