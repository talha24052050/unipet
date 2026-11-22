extends Node
## Ağ senkronu yöneticisi: Yerel oyuncunun durumunu periyodik olarak sunucuya iletir,
## odadaki uzak oyuncuları (RemotePlayer) yönetir ve ağ kopmalarında yeniden bağlanmayı yönetir.

const RemotePlayerScene := preload("res://scenes/remote_player.tscn")
const LocalProfile := preload("res://src/core/local_profile.gd")

const POS_EPSILON: float = 0.02          # 2 cm (durum değişim eşiği)
const YAW_EPSILON: float = 0.02          # 0.02 radyan (~1.15 derece)
const HEARTBEAT_INTERVAL: float = 1.0    # Değişmeyen durumda en az saniyede 1 gönder
## Kopunca artan aralıklarla yeniden bağlan: 3, 6, 12, 24, sonra 30 sn'de bir (~20 dk). Ev interneti/tünel
## 30-60 sn kopabiliyor (2026-11-22 arkadaşlarla testte 40 sn kesinti 5×5 sn'lik eski denemeleri tüketti).
const RECONNECT_DELAY: float = 3.0
const RECONNECT_DELAY_MAX: float = 30.0
const MAX_RECONNECT_ATTEMPTS: int = 45
const DEFAULT_ZONE: String = "kampus"


## Oyuncunun bulunduğu bölge (harita ekranı Services.current_zone'u değiştirir).
static func _zone_id() -> String:
	return Services.current_zone if not Services.current_zone.is_empty() else DEFAULT_ZONE

@export var player_node: NodePath
var player: Node3D = null
var remote_players_parent: Node = null

var net: Node = null: set = set_network_service

var _remote_players: Dictionary = {}  # player_id: String -> RemotePlayer: Node3D
var _in_room: bool = false
var _tick_accum: float = 0.0
var _heartbeat_accum: float = 0.0
var _has_sent_state: bool = false
var _last_sent_pos: Vector3 = Vector3.ZERO
var _last_sent_yaw: float = 0.0
var _last_sent_anim: String = ""

var _reconnect_attempts: int = 0
var _reconnect_timer: float = 0.0
var _waiting_reconnect: bool = false


func _ready() -> void:
	if player == null:
		if not player_node.is_empty() and has_node(player_node):
			player = get_node(player_node) as Node3D
		elif has_node("../Player"):
			player = get_node("../Player") as Node3D

	if remote_players_parent == null:
		remote_players_parent = self

	if net == null and Services.net != null:
		set_network_service(Services.net)
	elif net != null:
		_connect_network_signals()

	_initiate_connection()


func set_network_service(new_net: Node) -> void:
	if net != null:
		_disconnect_network_signals()
	net = new_net
	if net != null:
		_connect_network_signals()


func _exit_tree() -> void:
	_disconnect_network_signals()
	_clear_remote_players()


func _connect_network_signals() -> void:
	if net == null:
		return
	if not net.connected.is_connected(_on_connected):
		net.connected.connect(_on_connected)
	if not net.disconnected.is_connected(_on_disconnected):
		net.disconnected.connect(_on_disconnected)
	if not net.room_joined.is_connected(_on_room_joined):
		net.room_joined.connect(_on_room_joined)
	if not net.player_joined.is_connected(_on_player_joined):
		net.player_joined.connect(_on_player_joined)
	if not net.player_left.is_connected(_on_player_left):
		net.player_left.connect(_on_player_left)
	if not net.player_state.is_connected(_on_player_state):
		net.player_state.connect(_on_player_state)
	if not net.player_profile.is_connected(_on_player_profile):
		net.player_profile.connect(_on_player_profile)


func _disconnect_network_signals() -> void:
	if net == null:
		return
	if net.connected.is_connected(_on_connected):
		net.connected.disconnect(_on_connected)
	if net.disconnected.is_connected(_on_disconnected):
		net.disconnected.disconnect(_on_disconnected)
	if net.room_joined.is_connected(_on_room_joined):
		net.room_joined.disconnect(_on_room_joined)
	if net.player_joined.is_connected(_on_player_joined):
		net.player_joined.disconnect(_on_player_joined)
	if net.player_left.is_connected(_on_player_left):
		net.player_left.disconnect(_on_player_left)
	if net.player_state.is_connected(_on_player_state):
		net.player_state.disconnect(_on_player_state)
	if net.player_profile.is_connected(_on_player_profile):
		net.player_profile.disconnect(_on_player_profile)


func _initiate_connection() -> void:
	if net == null:
		return
	var token: String = Services.auth.get_access_token() if Services.auth != null else ""
	net.connect_to_server(token)


func _on_connected() -> void:
	_reconnect_attempts = 0
	_waiting_reconnect = false
	_reconnect_timer = 0.0
	if net != null:
		net.join_zone(_zone_id())


func _on_disconnected(_reason: String) -> void:
	_in_room = false
	_clear_remote_players()
	if _reconnect_attempts < MAX_RECONNECT_ATTEMPTS:
		_waiting_reconnect = true
		_reconnect_timer = reconnect_delay(_reconnect_attempts)
		_reconnect_attempts += 1
	else:
		_waiting_reconnect = false


func _on_room_joined(_room_id: String) -> void:
	_in_room = true
	send_local_profile()
	_has_sent_state = false
	_heartbeat_accum = HEARTBEAT_INTERVAL


func _on_player_joined(id: String, state: Dictionary) -> void:
	if id.is_empty():
		return
	if net != null and id == net.local_player_id():
		return
	if _remote_players.has(id):
		if not state.is_empty():
			var existing: Node3D = _remote_players[id]
			if existing.has_method("push_state"):
				existing.push_state(state)
		return

	var rp: Node3D = RemotePlayerScene.instantiate()
	if rp.has_method("set_player_id"):
		rp.set_player_id(id)
	var parent_node: Node = remote_players_parent if remote_players_parent != null else self
	parent_node.add_child(rp)
	if not rp.is_node_ready():
		rp.call("_ready")
	_remote_players[id] = rp

	if not state.is_empty() and rp.has_method("push_state"):
		rp.push_state(state)


func _on_player_left(id: String) -> void:
	if _remote_players.has(id):
		var rp: Node = _remote_players[id]
		_remote_players.erase(id)
		rp.queue_free()


func _on_player_state(id: String, state: Dictionary) -> void:
	if _remote_players.has(id):
		var rp: Node3D = _remote_players[id]
		if rp.has_method("push_state"):
			rp.push_state(state)


func _on_player_profile(id: String, profile: Dictionary) -> void:
	if _remote_players.has(id):
		var rp: Node3D = _remote_players[id]
		if rp.has_method("apply_profile"):
			rp.apply_profile(profile)


func _clear_remote_players() -> void:
	for id: String in _remote_players:
		var rp: Node = _remote_players[id]
		rp.queue_free()
	_remote_players.clear()


func get_remote_player(id: String) -> Node3D:
	return _remote_players.get(id, null)


func get_remote_players() -> Dictionary:
	return _remote_players


func send_local_profile() -> void:
	if net == null or not _in_room:
		return
	var pet_id: StringName = Config.DEFAULT_PET_ID
	var accs: Dictionary = {}
	if player != null:
		if "character_id" in player and player.character_id != &"":
			pet_id = player.character_id
		if "visual" in player and player.visual != null and player.visual.has_method("equipped_ids"):
			accs = player.visual.equipped_ids()
		else:
			var prof: LocalProfile = LocalProfile.load_or_default()
			accs = prof.accessories
	else:
		var prof: LocalProfile = LocalProfile.load_or_default()
		pet_id = prof.pet_id
		accs = prof.accessories
	net.send_profile(pet_id, accs, LocalProfile.load_or_default().display_name)


func _process(delta: float) -> void:
	if _waiting_reconnect:
		_reconnect_timer -= delta
		if _reconnect_timer <= 0.0:
			_waiting_reconnect = false
			_initiate_connection()

	if not _in_room or net == null or player == null:
		return

	_heartbeat_accum += delta
	_tick_accum += delta
	var tick_rate: float = float(Config.NET_TICK_RATE)
	var tick_interval: float = 1.0 / tick_rate if tick_rate > 0.0 else 0.1
	if _tick_accum >= tick_interval:
		_tick_accum -= tick_interval
		_check_and_send_state()


func _check_and_send_state() -> void:
	if player == null or net == null:
		return

	var pos: Vector3 = player.global_position if player.is_inside_tree() else player.position
	var yaw: float = player.global_rotation.y if player.is_inside_tree() else player.rotation.y
	var anim: String = "idle"
	if "visual" in player and player.visual != null and player.visual.has_method("current_logical"):
		anim = str(player.visual.current_logical())

	var pos_changed: bool = not _has_sent_state or pos.distance_to(_last_sent_pos) >= POS_EPSILON
	var yaw_changed: bool = not _has_sent_state or absf(angle_difference(_last_sent_yaw, yaw)) >= YAW_EPSILON
	var anim_changed: bool = not _has_sent_state or anim != _last_sent_anim
	var heartbeat: bool = _heartbeat_accum >= HEARTBEAT_INTERVAL

	if pos_changed or yaw_changed or anim_changed or heartbeat:
		var state: Dictionary = {
			"pos": pos,
			"yaw": yaw,
			"anim": anim
		}
		net.send_state(state)
		_has_sent_state = true
		_last_sent_pos = pos
		_last_sent_yaw = yaw
		_last_sent_anim = anim
		_heartbeat_accum = 0.0


static func reconnect_delay(attempt: int) -> float:
	return minf(RECONNECT_DELAY * pow(2.0, float(attempt)), RECONNECT_DELAY_MAX)
