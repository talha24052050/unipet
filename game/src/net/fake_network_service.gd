extends "res://src/net/network_service.gd"
## SADECE testler için sahte ağ servisi. Sinyalleri elle tetiklenebilir
## ve gönderilen verileri bellekte depolar.

var local_id: String = "local_test_id"
var is_connected_to_server: bool = false
var current_room: String = ""

var connect_calls: int = 0
var last_connect_token: String = ""
var joined_zones: Array[String] = []
var leave_zone_calls: int = 0

var sent_states: Array[Dictionary] = []
var sent_profiles: Array[Dictionary] = []
var sent_chats: Array[ChatMessage] = []
var sent_socials: Array[Dictionary] = []


func connect_to_server(session_token: String) -> void:
	connect_calls += 1
	last_connect_token = session_token


func join_zone(zone_id: String) -> void:
	joined_zones.append(zone_id)
	current_room = "%s-1" % zone_id


func leave_zone() -> void:
	leave_zone_calls += 1
	current_room = ""


func send_state(state: Dictionary) -> void:
	sent_states.append(state.duplicate(true))


func send_profile(pet_id: StringName, accessories: Dictionary, display_name: String = "") -> void:
	sent_profiles.append({"pet": pet_id, "acc": accessories.duplicate(true)})


func send_chat(message: ChatMessage) -> void:
	sent_chats.append(message)


func send_social(payload: Dictionary) -> void:
	sent_socials.append(payload.duplicate(true))


func local_player_id() -> String:
	return local_id


## Test simülasyon yardımcıları:
func simulate_connected() -> void:
	is_connected_to_server = true
	connected.emit()


func simulate_disconnected(reason: String = "") -> void:
	is_connected_to_server = false
	current_room = ""
	disconnected.emit(reason)


func simulate_room_joined(room_id: String = "kampus-1") -> void:
	current_room = room_id
	room_joined.emit(room_id)


func simulate_player_joined(player_id: String, state: Dictionary = {}) -> void:
	player_joined.emit(player_id, state)


func simulate_player_left(player_id: String) -> void:
	player_left.emit(player_id)


func simulate_player_state(player_id: String, state: Dictionary) -> void:
	player_state.emit(player_id, state)


func simulate_player_profile(player_id: String, profile: Dictionary) -> void:
	player_profile.emit(player_id, profile)


func simulate_chat(message: ChatMessage) -> void:
	chat_received.emit(message)


func simulate_social(data: Dictionary) -> void:
	_apply_social_packet(data)


func clear_history() -> void:
	sent_states.clear()
	sent_profiles.clear()
	sent_chats.clear()
	sent_socials.clear()
	joined_zones.clear()
	connect_calls = 0
	leave_zone_calls = 0
