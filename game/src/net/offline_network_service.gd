extends "res://src/net/network_service.gd"
## Sunucusuz implementasyon: tek oyunculu geliştirme ve testler için.
## Gönderilen chat mesajlarını yerel oyuncuya geri yansıtır.

const CareRules := preload("res://src/care/pet_care_rules.gd")
const CARE_PATH: String = "user://care.cfg"

var _zone: String = ""
var _player_id: String = "local"
var _last_pos: Vector3 = Vector3.ZERO
## Tek oyunculu bakım: cihazda saklanır, aynı kurallar.
var _care: Dictionary = {}
var _care_last: Dictionary = {}


func connect_to_server(_session_token: String) -> void:
	connected.emit.call_deferred()


func join_zone(zone_id: String) -> void:
	_zone = "%s-1" % zone_id
	room_joined.emit.call_deferred(_zone)
	_care_load()
	care_updated.emit.call_deferred(CareRules.decay(_care, _now()), true, "")


func leave_zone() -> void:
	_zone = ""


func send_state(state: Dictionary) -> void:
	_last_pos = state.get("pos", _last_pos)


func send_care_action(action: String) -> void:
	if _care.is_empty():
		_care_load()
	var now: int = _now()
	if not action in CareRules.PLAYER_ACTIONS:
		care_updated.emit(CareRules.decay(_care, now), false, "geçersiz eylem")
		return
	var loc: String = CareRules.location_error(action, _last_pos)
	if not loc.is_empty():
		care_updated.emit(CareRules.decay(_care, now), false, loc)
		return
	var r: Dictionary = CareRules.apply(_care, action, now, _care_last)
	_care = r["state"]
	if r["ok"]:
		_care_last[action] = now
	_care_save()
	care_updated.emit(_care, r["ok"], r["reason"])


func _now() -> int:
	return int(Time.get_unix_time_from_system())


func _care_load() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(CARE_PATH) == OK:
		_care = cfg.get_value("care", "state", {})
		_care_last = cfg.get_value("care", "last", {})
	if _care.is_empty():
		_care = CareRules.new_state(_now())
		_care_save()


func _care_save() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("care", "state", _care)
	cfg.set_value("care", "last", _care_last)
	cfg.save(CARE_PATH)


func send_chat(message: ChatMessage) -> void:
	if message.kind == ChatMessage.Kind.FREE and not Config.FREE_CHAT_ENABLED:
		return
	message.sender_id = _player_id
	chat_received.emit(message)


func local_player_id() -> String:
	return _player_id
