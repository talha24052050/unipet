extends "res://src/net/network_service.gd"
## Sunucusuz implementasyon: tek oyunculu geliştirme ve testler için.
## Gönderilen chat mesajlarını yerel oyuncuya geri yansıtır.

const CareRules := preload("res://src/care/pet_care_rules.gd")
const CARE_PATH: String = "user://care.cfg"
const Stardust := preload("res://src/collect/stardust_rules.gd")
const WALLET_PATH: String = "user://wallet.cfg"
const MinigameRules := preload("res://src/minigame/minigame_rules.gd")
const RaceRules := preload("res://src/minigame/race_rules.gd")
const ChatFilter := preload("res://src/net/chat_filter.gd")
const LocalProfile := preload("res://src/core/local_profile.gd")
const SOCIAL_PATH: String = "user://social.cfg"

var _zone: String = ""
var _player_id: String = "local"
var _display_name: String = ""
var _pet_id: String = "mushnub"
var _active_cafe: String = ""
var _groups: Array = []
var _next_gid: int = 1
var _last_pos: Vector3 = Vector3.ZERO
## Tek oyunculu bakım: cihazda saklanır, aynı kurallar.
var _care: Dictionary = {}
var _care_last: Dictionary = {}


func connect_to_server(_session_token: String) -> void:
	connected.emit.call_deferred()


func join_zone(zone_id: String) -> void:
	_zone = "%s-1" % zone_id
	var prof: RefCounted = LocalProfile.load_or_default()
	_display_name = str(prof.get("display_name"))
	_pet_id = str(prof.get("pet_id"))
	_social_load()
	room_joined.emit.call_deferred(_zone)
	_care_load()
	care_updated.emit.call_deferred(CareRules.decay(_care, _now()), true, "")
	request_wallet()
	_emit_full_social.call_deferred()


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


func send_profile(pet_id: StringName, _accessories: Dictionary, display_name: String = "") -> void:
	_pet_id = str(pet_id)
	if not display_name.is_empty():
		_display_name = display_name


func send_chat(message: ChatMessage) -> void:
	if message.kind == ChatMessage.Kind.FREE:
		if not Config.FREE_CHAT_ENABLED:
			return
		var check: Dictionary = ChatFilter.sanitize_free_text(message.payload)
		if not bool(check.get("ok", false)):
			social_updated.emit({"type": "toast", "ok": false, "text": str(check.get("reason", "Mesaj gönderilemedi."))})
			return
		message.payload = str(check["text"])
	if message.channel.begins_with("dm:"):
		var target_id: String = message.channel.trim_prefix("dm:")
		if not _is_friend_offline(target_id):
			social_updated.emit({"type": "toast", "ok": false, "text": "Özel mesaj göndermek için önce arkadaş olmalısınız."})
			return
	message.sender_id = _player_id
	if message.sender_name.is_empty():
		message.sender_name = _display_name if not _display_name.is_empty() else "Sen"
	chat_received.emit(message)


func send_social(payload: Dictionary) -> void:
	_social_load()
	var act: String = str(payload.get("act", ""))
	var my_name: String = _display_name if not _display_name.is_empty() else "Sen"
	match act:
		"sync":
			_emit_full_social()
		"enter_cafe":
			_active_cafe = str(payload.get("cafe", "")).strip_edges()
			_emit_full_social()
		"leave_cafe":
			_active_cafe = ""
			_emit_full_social()
		"create_group":
			var chk: Dictionary = ChatFilter.sanitize_free_text(str(payload.get("title", "")), ChatFilter.MAX_GROUP_NAME_LEN)
			if not bool(chk.get("ok", false)):
				social_updated.emit({"type": "toast", "ok": false, "text": str(chk.get("reason", "Geçersiz grup adı."))})
				return
			var gid: String = "g%d" % _next_gid
			_next_gid += 1
			_remove_from_all_groups(_player_id)
			_groups.append({
				"id": gid,
				"title": str(chk["text"]),
				"owner": _player_id,
				"owner_name": my_name,
				"x": snappedf(_last_pos.x, 0.1),
				"z": snappedf(_last_pos.z, 0.1),
				"members": [{"id": _player_id, "name": my_name}],
			})
			_emit_full_social({"joined_group": gid})
		"join_group":
			var jid: String = str(payload.get("id", ""))
			_remove_from_all_groups(_player_id)
			for g: Dictionary in _groups:
				if str(g.get("id", "")) == jid:
					var mems: Array = g.get("members", [])
					mems.append({"id": _player_id, "name": my_name})
					g["members"] = mems
					_emit_full_social({"joined_group": jid})
					return
			_emit_full_social()
		"leave_group":
			_remove_from_all_groups(_player_id)
			_emit_full_social({"left_group": true})
		"friend_req":
			var tid: String = str(payload.get("to", "")).strip_edges()
			var tname: String = str(payload.get("name", tid)).strip_edges()
			if tid.is_empty() or tid == _player_id:
				return
			if _is_friend_offline(tid):
				return
			var out_list: Array = social_state.get("outgoing", [])
			for item: Dictionary in out_list:
				if str(item.get("id", "")) == tid:
					return
			out_list.append({"id": tid, "name": tname if not tname.is_empty() else tid})
			social_state["outgoing"] = out_list
			_social_save()
			_emit_full_social({"toast": "Arkadaşlık isteği gönderildi!"})
		"friend_accept":
			var aid: String = str(payload.get("from", "")).strip_edges()
			var inc: Array = social_state.get("incoming", [])
			var found_name: String = aid
			var next_inc: Array = []
			for item: Dictionary in inc:
				if str(item.get("id", "")) == aid:
					found_name = str(item.get("name", aid))
				else:
					next_inc.append(item)
			social_state["incoming"] = next_inc
			if not _is_friend_offline(aid):
				var fr: Array = social_state.get("friends", [])
				fr.append({"id": aid, "name": found_name})
				social_state["friends"] = fr
			_social_save()
			_emit_full_social({"toast": "%s ile arkadaş oldunuz!" % found_name})
		"friend_decline":
			var did: String = str(payload.get("from", "")).strip_edges()
			var d_next: Array = []
			for item: Dictionary in social_state.get("incoming", []):
				if str(item.get("id", "")) != did:
					d_next.append(item)
			social_state["incoming"] = d_next
			_social_save()
			_emit_full_social()
		"friend_remove":
			var rid: String = str(payload.get("id", "")).strip_edges()
			var r_next: Array = []
			for item: Dictionary in social_state.get("friends", []):
				if str(item.get("id", "")) != rid:
					r_next.append(item)
			social_state["friends"] = r_next
			_social_save()
			_emit_full_social()


func _is_friend_offline(uid: String) -> bool:
	for item: Dictionary in social_state.get("friends", []):
		if str(item.get("id", "")) == uid:
			return true
	return false


func _remove_from_all_groups(uid: String) -> void:
	var kept: Array = []
	for g: Dictionary in _groups:
		var mems: Array = []
		for m: Dictionary in g.get("members", []):
			if str(m.get("id", "")) != uid:
				mems.append(m)
		if not mems.is_empty():
			g["members"] = mems
			kept.append(g)
	_groups = kept


func _social_load() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(SOCIAL_PATH) == OK:
		social_state["friends"] = cfg.get_value("social", "friends", [])
		social_state["incoming"] = cfg.get_value("social", "incoming", [])
		social_state["outgoing"] = cfg.get_value("social", "outgoing", [])


func _social_save() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("social", "friends", social_state.get("friends", []))
	cfg.set_value("social", "incoming", social_state.get("incoming", []))
	cfg.set_value("social", "outgoing", social_state.get("outgoing", []))
	cfg.save(SOCIAL_PATH)


func _emit_full_social(extra: Dictionary = {}) -> void:
	var cafes_map: Dictionary = {}
	if not _active_cafe.is_empty():
		var my_name: String = _display_name if not _display_name.is_empty() else "Sen"
		cafes_map[_active_cafe] = [{"id": _player_id, "name": my_name, "pet": _pet_id}]
	var pkt: Dictionary = {
		"type": "social_state",
		"friends": social_state.get("friends", []),
		"incoming": social_state.get("incoming", []),
		"outgoing": social_state.get("outgoing", []),
		"cafes": cafes_map,
		"groups": _groups.duplicate(true),
	}
	for k: Variant in extra:
		pkt[k] = extra[k]
	if extra.has("toast"):
		pkt["ok"] = true
		pkt["text"] = extra["toast"]
	_apply_social_packet(pkt)


func local_player_id() -> String:
	return _player_id
