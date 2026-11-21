extends Node
## Ağ arayüzü (soyut). Oyun kodu sadece bunu bilir.
## Implementasyonlar: OfflineNetworkService (tek oyunculu), NakamaNetworkService (Config.NETWORK_BACKEND = "nakama").

signal connected
signal disconnected(reason: String)
signal room_joined(room_id: String)
signal player_joined(player_id: String, state: Dictionary)
signal player_left(player_id: String)
## state: {"pos": Vector3, "yaw": float, "anim": String}
signal player_state(player_id: String, state: Dictionary)
signal chat_received(message: ChatMessage)
## Başka oyuncunun pet + aksesuar seçimi: profile = {"pet": StringName, "acc": {slot: id}}
signal player_profile(player_id: String, profile: Dictionary)


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


## Yerel oyuncunun pet + aksesuarlarını odaya duyurur (katılınca ve değişince).
func send_profile(_pet_id: StringName, _accessories: Dictionary) -> void:
	pass


func local_player_id() -> String:
	return ""
