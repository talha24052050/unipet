extends Node
## Temel ses efektleri yöneticisi (autoload Sfx).
## AudioStreamPlayer havuzu ile en çok 6 eşzamanlı ses çalar.

const SOUNDS: Dictionary = {
	&"ui_click": "res://assets/sfx/ui_click.ogg",
	&"chat_send": "res://assets/sfx/chat_send.ogg",
	&"chat_receive": "res://assets/sfx/chat_receive.ogg",
	&"emote": "res://assets/sfx/emote.ogg",
	&"care_ok": "res://assets/sfx/care_ok.ogg",
	&"care_fail": "res://assets/sfx/care_fail.ogg",
	&"teleport": "res://assets/sfx/teleport.ogg",
	&"step": "res://assets/sfx/step.ogg",
	&"meow": "res://assets/sfx/meow.wav",
}

const POOL_SIZE: int = 6

var volume_db: float = 0.0
var enabled: bool = true
var suspended: bool = false

var last_played: StringName = &""
var play_count: int = 0

var _pool: Array[AudioStreamPlayer] = []
var _warned: Dictionary = {}
var _streams: Dictionary = {}
var _next_player_idx: int = 0


func _init() -> void:
	_ensure_pool()


func _ready() -> void:
	_ensure_pool()
	for p: AudioStreamPlayer in _pool:
		if p.get_parent() == null and is_inside_tree():
			add_child(p)
	var settings: RefCounted = preload("res://src/core/local_settings.gd").load_or_default()
	if settings != null:
		var raw_enabled: Variant = settings.get("sfx_enabled")
		if raw_enabled != null:
			enabled = bool(raw_enabled)
		var raw_vol: Variant = settings.get("sfx_volume_db")
		if raw_vol != null:
			volume_db = float(raw_vol)
	if Services != null and Services.lifecycle != null:
		if not Services.lifecycle.app_paused.is_connected(_on_app_paused):
			Services.lifecycle.app_paused.connect(_on_app_paused)
		if not Services.lifecycle.app_resumed.is_connected(_on_app_resumed):
			Services.lifecycle.app_resumed.connect(_on_app_resumed)


func _on_app_paused() -> void:
	set_suspended(true)


func _on_app_resumed(_away_seconds: float) -> void:
	set_suspended(false)


func set_suspended(value: bool) -> void:
	suspended = value
	if suspended:
		stop_all()


func stop_all() -> void:
	for p: AudioStreamPlayer in _pool:
		if p != null and p.playing:
			p.stop()


func _ensure_pool() -> void:
	while _pool.size() < POOL_SIZE:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.bus = &"Master"
		_pool.append(p)
		if is_inside_tree():
			add_child(p)


func play(sound_name: StringName) -> void:
	if not enabled or suspended:
		return
	if not SOUNDS.has(sound_name):
		if not _warned.has(sound_name):
			_warned[sound_name] = true
			push_warning("Bilinmeyen ses efekti: %s" % str(sound_name))
		return
	var path: String = str(SOUNDS[sound_name])
	if not ResourceLoader.exists(path):
		if not _warned.has(path):
			_warned[path] = true
			push_warning("Ses dosyası bulunamadı: %s" % path)
		return
	var stream: AudioStream = _streams.get(sound_name)
	if stream == null:
		stream = load(path) as AudioStream
		if stream != null:
			_streams[sound_name] = stream
	if stream == null:
		return

	last_played = sound_name
	play_count += 1

	_ensure_pool()
	var player: AudioStreamPlayer = _get_available_player()
	if player == null:
		return
	player.stream = stream
	player.volume_db = volume_db
	if player.is_inside_tree():
		player.play()


func _get_available_player() -> AudioStreamPlayer:
	if _pool.is_empty():
		return null
	for p: AudioStreamPlayer in _pool:
		if not p.playing:
			return p
	var p: AudioStreamPlayer = _pool[_next_player_idx]
	_next_player_idx = (_next_player_idx + 1) % _pool.size()
	return p


func get_pool_size() -> int:
	return _pool.size()
