extends Node3D
## Bir CharacterDef'in modelini yükler ve MANTIKSAL animasyonları oynatır.
## Oyun kodu model dosyasını ya da gerçek animasyon adlarını bilmez; sadece:
##   set_character(def), set_locomotion(hız), play_emote(&"emote_wave")

signal emote_finished(logical: StringName)

const LOOPING: PackedStringArray = ["idle", "walk", "run"]

var definition: CharacterDef
var _model: Node3D
var _player: AnimationPlayer
var _current: StringName = &""
var _emote: StringName = &""


func set_character(def: CharacterDef) -> void:
	if _model != null:
		_model.queue_free()
		_model = null
		_player = null
	definition = def
	_current = &""
	_emote = &""
	if def == null:
		return
	var scene: PackedScene = load(def.model_path)
	_model = scene.instantiate()
	_model.scale = Vector3.ONE * def.model_scale
	add_child(_model)
	var players: Array[Node] = _model.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		_player = players[0]
		_player.animation_finished.connect(_on_animation_finished)
		for logical: String in LOOPING:
			var anim: Animation = _player.get_animation(def.anim_name(logical)) if _player.has_animation(def.anim_name(logical)) else null
			if anim != null:
				anim.loop_mode = Animation.LOOP_LINEAR
	_play(&"idle")


## Yatay hıza göre idle / walk / run seçer. Hareket emote'u keser.
func set_locomotion(speed: float) -> void:
	if definition == null:
		return
	var moving: bool = speed > Config.PET_IDLE_SPEED
	if _emote != &"" and not moving:
		return
	_emote = &""
	var logical: StringName = locomotion_for(speed)
	_play(logical)
	if _player != null and logical != &"idle":
		# Ayak kaymasın diye oynatma hızı gerçek hıza oranlanır.
		var ref: float = Config.PLAYER_RUN_SPEED if logical == &"run" else Config.PLAYER_WALK_SPEED
		_player.speed_scale = definition.anim_speed(logical) * clampf(speed / ref, 0.5, 1.5)
	elif _player != null:
		_player.speed_scale = 1.0


## Tek seferlik emote (dans, zıplama...). Bitince ya da hareket edilince loco'ya döner.
func play_emote(logical: StringName) -> bool:
	if definition == null or definition.anim_name(logical).is_empty():
		return false
	_emote = logical
	_play(logical, true)
	return true


func current_logical() -> StringName:
	return _emote if _emote != &"" else _current


## Model boyutundan yaklaşık çarpışma yarıçapı ve boyu (ölçek uygulanmış).
func footprint() -> Vector2:
	if _model == null:
		return Vector2(0.35, 1.2)
	var box: AABB = AABB()
	var first: bool = true
	for n: Node in _model.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n
		var b: AABB = _relative_xform(mi) * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	var radius: float = minf(box.size.x, box.size.z) * 0.5 * Config.PET_COLLISION_RADIUS_FACTOR
	return Vector2(radius, box.size.y)


static func locomotion_for(speed: float) -> StringName:
	if speed <= Config.PET_IDLE_SPEED:
		return &"idle"
	if speed >= Config.PLAYER_RUN_SPEED * 0.9:
		return &"run"
	return &"walk"


func _play(logical: StringName, restart: bool = false) -> void:
	if _player == null:
		return
	if logical == _current and not restart and _emote == &"":
		return
	var real: String = definition.anim_name(logical)
	if real.is_empty() or not _player.has_animation(real):
		return
	if logical != &"run" and logical != &"walk":
		_player.speed_scale = definition.anim_speed(logical)
	_player.play(real, Config.PET_ANIM_BLEND)
	if restart:
		_player.seek(0.0, true)
	if _emote == &"":
		_current = logical


func _on_animation_finished(_name: StringName) -> void:
	if _emote == &"":
		return
	var done: StringName = _emote
	_emote = &""
	_current = &""
	_play(&"idle")
	emote_finished.emit(done)


## Model köküne göre dönüşüm (ağaçta olmasa da çalışır).
func _relative_xform(n: Node3D) -> Transform3D:
	var t: Transform3D = n.transform
	var p: Node = n.get_parent()
	while p != null and p != self and p is Node3D:
		t = (p as Node3D).transform * t
		p = p.get_parent()
	return t
