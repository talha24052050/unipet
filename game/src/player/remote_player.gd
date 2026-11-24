extends Node3D
## Odadaki diğer oyuncuların 3D temsili: pet görseli, isim etiketi ve konuşma baloncuğu.
## Ağdan gelen durumlar arasında interpolasyon (lerp + lerp_angle) ve teleport kontrolü yapar.

const PetVisual := preload("res://src/characters/pet_visual.gd")

const INTERPOLATION_DELAY: float = 0.1  # 100 ms geriden oynatma
const TELEPORT_DISTANCE: float = 5.0    # 5 metreden büyük sıçramalarda ışınlanma
const MAX_BUFFER_SIZE: int = 32
const NAME_LABEL_OFFSET_Y: float = 0.16
const CHAT_BUBBLE_OFFSET_Y: float = 0.52

@export var player_id: String = ""
var character_id: StringName = &""
## Profil gelince takma ad; gelmediyse kimliğin başı gösterilir.
var display_name: String = ""

var _clock: float = 0.0
var _buffer: Array[Dictionary] = []

@onready var visual: PetVisual = $PetVisual
@onready var name_label: Label3D = $NameLabel
@onready var chat_bubble: Node3D = $ChatBubble


func _ready() -> void:
	_ensure_nodes()
	if visual != null:
		visual.fidget_enabled = false  # uzak petin hareketi ağdan gelir
	if character_id == &"":
		set_character(Config.DEFAULT_PET_ID)
	_update_name_label()
	_update_heights()


func _ensure_nodes() -> void:
	if visual == null:
		visual = get_node_or_null("PetVisual") as PetVisual
	if name_label == null:
		name_label = get_node_or_null("NameLabel") as Label3D
	if chat_bubble == null:
		chat_bubble = get_node_or_null("ChatBubble") as Node3D


func set_player_id(id: String) -> void:
	player_id = id
	_update_name_label()


func _update_name_label() -> void:
	_ensure_nodes()
	if name_label != null:
		name_label.text = display_name if not display_name.is_empty() else (player_id.substr(0, 6) if not player_id.is_empty() else "")


func _update_heights() -> void:
	_ensure_nodes()
	if visual != null and visual.has_method("footprint"):
		var fp: Vector2 = visual.footprint()
		if name_label != null:
			name_label.position.y = fp.y + NAME_LABEL_OFFSET_Y
		if chat_bubble != null:
			chat_bubble.position.y = fp.y + CHAT_BUBBLE_OFFSET_Y


func set_character(id: StringName) -> void:
	_ensure_nodes()
	var def: CharacterDef = Services.characters.get_def(id)
	if def == null:
		var selectable: Array[CharacterDef] = Services.characters.selectable()
		if not selectable.is_empty():
			def = selectable[0]
		else:
			def = Services.characters.get_def(Config.DEFAULT_PET_ID)
	if def == null:
		push_warning("RemotePlayer: Geçerli pet tanımı bulunamadı: %s" % id)
		return
	character_id = def.id
	if visual != null:
		visual.set_character(def)
	_update_heights()


func apply_profile(profile: Dictionary) -> void:
	_ensure_nodes()
	var pet_id: StringName = StringName(str(profile.get("pet", "")))
	if pet_id == &"" or Services.characters.get_def(pet_id) == null:
		pet_id = Config.DEFAULT_PET_ID
	set_character(pet_id)
	display_name = str(profile.get("name", ""))
	_update_name_label()

	var raw_acc: Variant = profile.get("acc", {})
	if raw_acc is Dictionary and visual != null:
		var acc_dict: Dictionary = raw_acc
		# Profilde artık olmayan slotları çıkar (set_character takılıları korur; şapka çıkarılınca diğerleri görmeye
		# devam ediyordu)
		var wanted: Dictionary = {}
		for slot: Variant in acc_dict:
			wanted[StringName(str(slot))] = true
		for slot: StringName in (visual.equipped_ids() as Dictionary).keys():
			if not wanted.has(slot):
				visual.unequip(slot)
		for slot: Variant in acc_dict:
			var acc_id: StringName = StringName(str(acc_dict[slot]))
			var acc_def: AccessoryDef = Services.accessories.get_def(acc_id)
			if acc_def != null:
				visual.equip(acc_def)
			# Bilinmeyen aksesuar: atla
	_update_heights()


func _get_current_pos() -> Vector3:
	return global_position if is_inside_tree() else position


func _set_current_pos(p: Vector3) -> void:
	if is_inside_tree():
		global_position = p
	else:
		position = p


func _get_current_yaw() -> float:
	return global_rotation.y if is_inside_tree() else rotation.y


func _set_current_yaw(y: float) -> void:
	if is_inside_tree():
		global_rotation.y = y
	else:
		rotation.y = y


func _set_pos_and_yaw(p: Vector3, y: float) -> void:
	_set_current_pos(p)
	_set_current_yaw(y)


func push_state(state: Dictionary) -> void:
	var pos: Vector3 = state["pos"] if state.has("pos") else _get_current_pos()
	var yaw: float = float(state["yaw"]) if state.has("yaw") else _get_current_yaw()
	var anim: String = str(state.get("anim", "idle"))

	if _buffer.is_empty():
		_set_pos_and_yaw(pos, yaw)
		_buffer.append({"time": _clock, "pos": pos, "yaw": yaw, "anim": anim})
		_apply_animation(anim, 0.0)
		return

	var last_pos: Vector3 = _buffer[-1]["pos"]
	if pos.distance_to(last_pos) > TELEPORT_DISTANCE:
		_set_pos_and_yaw(pos, yaw)
		_buffer.clear()
		_buffer.append({"time": _clock, "pos": pos, "yaw": yaw, "anim": anim})
		_apply_animation(anim, 0.0)
		return

	_buffer.append({"time": _clock, "pos": pos, "yaw": yaw, "anim": anim})
	if _buffer.size() > MAX_BUFFER_SIZE:
		_buffer.pop_front()


func _process(delta: float) -> void:
	_clock += delta
	update_interpolation(_clock - INTERPOLATION_DELAY, delta)


func update_interpolation(render_time: float, delta: float) -> void:
	if _buffer.is_empty():
		return
	if _buffer.size() == 1:
		_set_pos_and_yaw(_buffer[0]["pos"], float(_buffer[0]["yaw"]))
		_apply_animation(str(_buffer[0]["anim"]), 0.0)
		return

	while _buffer.size() > 2 and float(_buffer[1]["time"]) <= render_time:
		_buffer.pop_front()

	if render_time <= float(_buffer[0]["time"]):
		_set_pos_and_yaw(_buffer[0]["pos"], float(_buffer[0]["yaw"]))
		_apply_animation(str(_buffer[0]["anim"]), 0.0)
		return

	if render_time >= float(_buffer[-1]["time"]):
		_set_pos_and_yaw(_buffer[-1]["pos"], float(_buffer[-1]["yaw"]))
		_apply_animation(str(_buffer[-1]["anim"]), 0.0)
		return

	var s0: Dictionary = _buffer[0]
	var s1: Dictionary = _buffer[1]
	var t0: float = float(s0["time"])
	var t1: float = float(s1["time"])
	var span: float = t1 - t0
	var factor: float = clampf((render_time - t0) / span, 0.0, 1.0) if span > 0.00001 else 0.0

	var p0: Vector3 = s0["pos"]
	var p1: Vector3 = s1["pos"]
	if p0.distance_to(p1) > TELEPORT_DISTANCE:
		_set_pos_and_yaw(p1, float(s1["yaw"]))
		_apply_animation(str(s1["anim"]), 0.0)
		return

	var target_pos: Vector3 = p0.lerp(p1, factor)
	var target_yaw: float = lerp_angle(float(s0["yaw"]), float(s1["yaw"]), factor)

	var cur_pos: Vector3 = _get_current_pos()
	var moved: Vector3 = target_pos - cur_pos
	var speed: float = (Vector3(moved.x, 0.0, moved.z).length() / delta) if delta > 0.0 else 0.0

	_set_pos_and_yaw(target_pos, target_yaw)
	_apply_animation(str(s1["anim"]), speed)


func _apply_animation(anim_name: String, speed: float) -> void:
	_ensure_nodes()
	if visual == null:
		return
	if anim_name.begins_with("emote_"):
		visual.play_emote(StringName(anim_name))
	else:
		if speed > 0.05:
			visual.set_locomotion(speed)
		elif anim_name == "walk":
			visual.set_locomotion(Config.PLAYER_WALK_SPEED)
		elif anim_name == "run":
			visual.set_locomotion(Config.PLAYER_RUN_SPEED)
		else:
			visual.set_locomotion(0.0)
