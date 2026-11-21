extends "res://src/net/network_service.gd"
## Sunucusuz implementasyon: tek oyunculu geliştirme ve testler için.
## Gönderilen chat mesajlarını yerel oyuncuya geri yansıtır.

var _zone: String = ""
var _player_id: String = "local"


func connect_to_server(_session_token: String) -> void:
	connected.emit.call_deferred()


func join_zone(zone_id: String) -> void:
	_zone = "%s-1" % zone_id
	room_joined.emit.call_deferred(_zone)


func leave_zone() -> void:
	_zone = ""


func send_state(_state: Dictionary) -> void:
	pass


func send_chat(message: ChatMessage) -> void:
	if message.kind == ChatMessage.Kind.FREE and not Config.FREE_CHAT_ENABLED:
		return
	message.sender_id = _player_id
	chat_received.emit(message)


func local_player_id() -> String:
	return _player_id
