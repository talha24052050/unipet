extends Node
## Ağ arayüzü (soyut). Oyun kodu sadece bunu bilir.
## Implementasyonlar: OfflineNetworkService (şimdi), NakamaNetworkService (Parça 4).

signal connected
signal disconnected(reason: String)
signal room_joined(room_id: String)
signal player_joined(player_id: String, state: Dictionary)
signal player_left(player_id: String)
## state: {"pos": Vector3, "yaw": float, "anim": String}
signal player_state(player_id: String, state: Dictionary)
signal chat_received(message: ChatMessage)


func connect_to_server(_session_token: String) -> void:
	push_error("NetworkService.connect_to_server soyut")


func join_zone(_zone_id: String) -> void:
	push_error("NetworkService.join_zone soyut")


func leave_zone() -> void:
	push_error("NetworkService.leave_zone soyut")


func send_state(_state: Dictionary) -> void:
	push_error("NetworkService.send_state soyut")


func send_chat(_message: ChatMessage) -> void:
	push_error("NetworkService.send_chat soyut")


func local_player_id() -> String:
	return ""
