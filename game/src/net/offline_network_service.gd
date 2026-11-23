extends "res://src/net/network_service.gd"
## Sunucusuz implementasyon: tek oyunculu geliştirme ve testler için.
## Gönderilen chat mesajlarını yerel oyuncuya geri yansıtır.

const CareRules := preload("res://src/care/pet_care_rules.gd")
const CARE_PATH: String = "user://care.cfg"
const Stardust := preload("res://src/collect/stardust_rules.gd")
const WALLET_PATH: String = "user://wallet.cfg"
const MinigameRules := preload("res://src/minigame/minigame_rules.gd")
const RaceRules := preload("res://src/minigame/race_rules.gd")

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
	request_wallet()


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
	var r: Dictionary = CareRules.apply(_care, action, now, _care_last, CareRules.bonus_for(action, _last_pos))
	_care = r["state"]
	if r["ok"]:
		_care_last[action] = now
	_care_save()
	care_updated.emit(_care, r["ok"], r["reason"])


# ---- yıldız tozu (cihazda, sunucuyla aynı kurallar)
var _points: Array = []


func _wallet_load() -> Dictionary:
	var cfg: ConfigFile = ConfigFile.new()
	var raw: Dictionary = {}
	if cfg.load(WALLET_PATH) == OK:
		raw = {"dust": cfg.get_value("w", "dust", 0), "owned": cfg.get_value("w", "owned", PackedStringArray()),
			"day": cfg.get_value("w", "day", -1), "taken": cfg.get_value("w", "taken", PackedInt32Array()),
			"mg": cfg.get_value("w", "mg", 0)}
	if _points.is_empty():
		_points = Stardust.load_points()
	return Stardust.normalize(raw, Stardust.day_number(_now()))


func _wallet_save(w: Dictionary) -> void:
	var cfg: ConfigFile = ConfigFile.new()
	for k: String in ["dust", "owned", "day", "taken", "mg"]:
		cfg.set_value("w", k, w[k])
	cfg.save(WALLET_PATH)


func request_wallet() -> void:
	var w: Dictionary = _wallet_load()
	_set_wallet.call_deferred(Stardust.view(w, _points.size()))


func send_collect(index: int) -> void:
	var w: Dictionary = _wallet_load()
	var got: bool = Stardust.collect(w, index, _last_pos, _points)
	if got:
		_wallet_save(w)
	_set_wallet(Stardust.view(w, _points.size(), got))


func send_minigame_result(game: String, score: int) -> void:
	var w: Dictionary = _wallet_load()
	var r: int = MinigameRules.reward(game, score, int(w["mg"]))
	if r > 0:
		w["dust"] = int(w["dust"]) + r
		w["mg"] = int(w["mg"]) + r
		_wallet_save(w)
	var v: Dictionary = Stardust.view(w, _points.size())
	v["reward"] = r
	_set_wallet(v)


# ---- tek kişilik yarış (sunucuyla aynı kurallar)
var _race: Dictionary = RaceRules.new_race()
var _race_cps: Array = []


func _ms() -> int:
	return Time.get_ticks_msec()


func send_race(act: String, i: int = 0) -> void:
	if _race_cps.is_empty():
		_race_cps = RaceRules.load_cps()
	var now: int = _ms()
	match act:
		"join":
			var why: String = RaceRules.join(_race, _player_id, _last_pos, now, _race_cps)
			if not why.is_empty():
				race_updated.emit({"error": why})
				return
		"leave":
			RaceRules.leave(_race, _player_id)
		"cp":
			var res: int = RaceRules.checkpoint(_race, _player_id, i, _last_pos, now, _race_cps)
			if res == 0:
				return
			if res == 2:
				var rc: Dictionary = _race["racers"][_player_id]
				var w: Dictionary = _wallet_load()
				var rw: int = clampi(RaceRules.reward(int(rc["place"]), int(_race["n"])), 0, MinigameRules.DAILY_CAP - int(w["mg"]))
				if rw > 0:
					w["dust"] = int(w["dust"]) + rw
					w["mg"] = int(w["mg"]) + rw
					_wallet_save(w)
				var v: Dictionary = Stardust.view(w, _points.size())
				v["reward"] = rw
				_set_wallet(v)
	_emit_race(now)


func _emit_race(now: int) -> void:
	race_updated.emit(RaceRules.view(_race, now, {_player_id: "Sen"}, _race_cps))


func _process(_delta: float) -> void:
	if _race["phase"] != "idle" and RaceRules.tick(_race, _ms()):
		_emit_race(_ms())


func buy_item(item: String) -> void:
	var w: Dictionary = _wallet_load()
	var def: AccessoryDef = Services.accessories.get_def(StringName(item)) if Services.accessories != null else null
	var reason: String = Stardust.buy(w, item, def.price if def != null else 0)
	if reason.is_empty():
		_wallet_save(w)
	_set_wallet(Stardust.view(w, _points.size()))
	purchase_finished.emit(item, reason.is_empty(), reason)


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
