extends "res://src/net/network_service.gd"
## Nakama istemcisi (addon'suz): REST ile kimlik doğrulama + WebSocket (JSON protokolü) ile oda.
## Sunucu tarafı: server/nakama/modules/index.js (opcode'lar orada tanımlı, burada aynı).
## Ayarlar: res://secrets.cfg [nakama] host, port, ssl, server_key — yoksa yerel geliştirme varsayılanları.

const SECRETS_PATH: String = "res://secrets.cfg"
const OP_STATE: int = 1
const OP_CHAT: int = 2
const OP_SNAPSHOT: int = 3
const OP_PROFILE: int = 4
const OP_CARE: int = 5

var host: String = "127.0.0.1"
var port: int = 7350
var ssl: bool = false
var server_key: String = "unipet-dev-server-key"
## Boşsa Services.auth.get_user_id(). Testler (aynı süreçte iki oyuncu) için doldurulabilir.
var custom_id_override: String = ""

var _socket: WebSocketPeer = WebSocketPeer.new()
var _socket_open: bool = false
var _nakama_token: String = ""
var _user_id: String = ""
var _match_id: String = ""
var _cid: int = 0
## cid -> Callable(response: Dictionary)
var _pending: Dictionary = {}
var _pending_zone: String = ""
## connect_to_url çağrıldı, henüz açılmadı: bu sırada kapanırsa da "koptu" yayınlanmalı (yoksa sonsuz "Bağlanıyor…").
var _connecting: bool = false
## Her bağlantı denemesi/kapatma bir artırır: await sürerken disconnect_from_server çağrıldıysa geç gelen HTTP
## yanıtı eski hesapla soket açmasın.
var _conn_gen: int = 0


func _ready() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(SECRETS_PATH) == OK:
		host = str(cfg.get_value("nakama", "host", host))
		port = int(cfg.get_value("nakama", "port", port))
		ssl = bool(cfg.get_value("nakama", "ssl", ssl))
		server_key = str(cfg.get_value("nakama", "server_key", server_key))


## session_token: Supabase erişim anahtarı (mock'ta "mock-token"). Kullanıcı kimliği Services.auth'tan.
func connect_to_server(session_token: String) -> void:
	# Oyun sahnesi yeniden yüklendiğinde (harita / pet seçimi dönüşü) bağlantı zaten açık: yeniden bağlanmak eski
	# soketi kapatıyor ve yeni açılışta odaya tekrar katılınmıyordu (Talha: "pet seçimine girince bağlantı kopuyor").
	# Açık soketi koru; odadan çıkıp yeniden katıl (sunucunun konum/hız kaydı da yeni yerle başlar).
	if _socket_open and _socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		if not _match_id.is_empty():
			leave_zone()
		connected.emit.call_deferred()
		return
	var custom_id: String = custom_id_override if not custom_id_override.is_empty() else Services.auth.get_user_id()
	if custom_id.is_empty():
		disconnected.emit("Önce giriş yapılmalı.")
		return
	var body: Dictionary = {"id": custom_id, "vars": {"supabase_token": session_token}}
	_conn_gen += 1
	var gen: int = _conn_gen
	var res: Dictionary = await _http_post("/v2/account/authenticate/custom?create=true", body)
	if gen != _conn_gen:
		return  # bu sırada çıkış yapıldı / yeni deneme başladı
	if not res["ok"] or not (res["body"] is Dictionary) or not (res["body"] as Dictionary).has("token"):
		disconnected.emit("Sunucuya giriş yapılamadı (%d)." % res["code"])
		return
	_nakama_token = str(res["body"]["token"])
	_user_id = user_id_from_jwt(_nakama_token)
	var url: String = "%s://%s:%d/ws?lang=tr&status=false&format=json&token=%s" % ["wss" if ssl else "ws", host, port, _nakama_token.uri_encode()]
	var err: Error = _socket.connect_to_url(url)
	if err != OK:
		disconnected.emit("Bağlantı kurulamadı.")
		return
	_connecting = true


func disconnect_from_server() -> void:
	_conn_gen += 1  # süren connect_to_server'ı iptal et
	leave_zone()
	_pending_zone = ""
	_pending.clear()
	_connecting = false
	if _socket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		_socket.close()
	_socket_open = false  # kasıtlı kapanış: "koptu" yayınlanmasın (yeniden bağlanma döngüsü başlamasın)
	_nakama_token = ""
	_user_id = ""


func join_zone(zone_id: String) -> void:
	if not _socket_open:
		_pending_zone = zone_id  # bağlanınca katılır
		return
	_send_request({"rpc": {"id": "find_room", "payload": JSON.stringify({"zone": zone_id})}}, func(r: Dictionary) -> void:
		var payload: Variant = JSON.parse_string(str(r.get("rpc", {}).get("payload", "{}")))
		if not payload is Dictionary or not (payload as Dictionary).has("match_id"):
			disconnected.emit("Oda bulunamadı.")
			return
		_join_match(str(payload["match_id"])))


func leave_zone() -> void:
	if _match_id.is_empty():
		return
	_send_envelope({"match_leave": {"match_id": _match_id}})
	_match_id = ""


func send_state(state: Dictionary) -> void:
	if _match_id.is_empty():
		return
	_send_match_data(OP_STATE, encode_state(state))


func send_chat(message: ChatMessage) -> void:
	if message.kind == ChatMessage.Kind.FREE and not Config.FREE_CHAT_ENABLED:
		return
	_send_match_data(OP_CHAT, {"k": int(message.kind), "p": message.payload})


func send_profile(pet_id: StringName, accessories: Dictionary, display_name: String = "") -> void:
	var acc: Dictionary = {}
	for slot: StringName in accessories:
		acc[str(slot)] = str(accessories[slot])
	_send_match_data(OP_PROFILE, {"pet": str(pet_id), "acc": acc, "name": display_name})


func send_care_action(action: String) -> void:
	_send_match_data(OP_CARE, {"act": action})


func local_player_id() -> String:
	return _user_id


func _process(_delta: float) -> void:
	_socket.poll()
	var st: WebSocketPeer.State = _socket.get_ready_state()
	if st == WebSocketPeer.STATE_CLOSED and _connecting:
		_connecting = false
		disconnected.emit("Bağlantı kurulamadı (%d)." % _socket.get_close_code())
	if st == WebSocketPeer.STATE_OPEN and not _socket_open:
		_connecting = false
		_socket_open = true
		connected.emit()
		if not _pending_zone.is_empty():
			var z: String = _pending_zone
			_pending_zone = ""
			join_zone(z)
	elif st == WebSocketPeer.STATE_CLOSED and _socket_open:
		_socket_open = false
		_match_id = ""
		disconnected.emit("Bağlantı koptu (%d)." % _socket.get_close_code())
	while _socket.get_available_packet_count() > 0:
		var msg: Variant = JSON.parse_string(_socket.get_packet().get_string_from_utf8())
		if msg is Dictionary:
			_handle(msg)


func _handle(msg: Dictionary) -> void:
	var cid: String = str(msg.get("cid", ""))
	if not cid.is_empty() and _pending.has(cid):
		var cb: Callable = _pending[cid]
		_pending.erase(cid)
		if msg.has("error"):
			push_warning("Nakama hata: %s" % msg["error"])
			disconnected.emit(str((msg["error"] as Dictionary).get("message", "Sunucu hatası")))
			return
		cb.call(msg)
		return
	if msg.has("match_presence_event"):
		var ev: Dictionary = msg["match_presence_event"]
		for p: Dictionary in ev.get("joins", []):
			if str(p.get("user_id")) != _user_id:
				player_joined.emit(str(p["user_id"]), {})
		for p: Dictionary in ev.get("leaves", []):
			player_left.emit(str(p["user_id"]))
	elif msg.has("match_data"):
		_handle_match_data(msg["match_data"])


func _handle_match_data(md: Dictionary) -> void:
	var op: int = int(str(md.get("op_code", "0")))
	var raw: String = Marshalls.base64_to_utf8(str(md.get("data", "")))
	var data: Variant = JSON.parse_string(raw)
	if not data is Dictionary:
		return
	var d: Dictionary = data
	match op:
		OP_STATE:
			player_state.emit(str(d.get("id", "")), decode_state(d))
		OP_CHAT:
			var k: int = int(d.get("k", -1))
			if k < 0 or k > ChatMessage.Kind.FREE:
				return
			chat_received.emit(ChatMessage.from_dict({"kind": k, "payload": str(d.get("p", "")), "sender_id": str(d.get("s", ""))}))
		OP_PROFILE:
			player_profile.emit(str(d.get("id", "")), decode_profile(d))
		OP_CARE:
			var st: Variant = d.get("state")
			if st is Dictionary:
				care_updated.emit(st, bool(d.get("ok", false)), str(d.get("reason", "")))
		OP_SNAPSHOT:
			for p: Dictionary in d.get("players", []):
				var pid: String = str(p.get("id", ""))
				player_joined.emit(pid, decode_state(p))
				if not str(p.get("pet", "")).is_empty():
					player_profile.emit(pid, decode_profile(p))


func _join_match(match_id: String) -> void:
	_send_request({"match_join": {"match_id": match_id}}, func(r: Dictionary) -> void:
		var m: Dictionary = r.get("match", {})
		_match_id = str(m.get("match_id", match_id))
		var me: Dictionary = m.get("self", {})
		if me.has("user_id"):
			_user_id = str(me["user_id"])
		room_joined.emit(_match_id)
		for p: Dictionary in m.get("presences", []):
			if str(p.get("user_id")) != _user_id:
				player_joined.emit(str(p["user_id"]), {}))


func _send_match_data(op: int, payload: Dictionary) -> void:
	if _match_id.is_empty() or not _socket_open:
		return
	_send_envelope({"match_data_send": {
		"match_id": _match_id,
		"op_code": str(op),
		"data": Marshalls.utf8_to_base64(JSON.stringify(payload)),
	}})


func _send_request(body: Dictionary, on_response: Callable) -> void:
	_cid += 1
	var cid: String = str(_cid)
	_pending[cid] = on_response
	body["cid"] = cid
	_send_envelope(body)


func _send_envelope(body: Dictionary) -> void:
	if _socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_socket.send_text(JSON.stringify(body))


func _http_post(path: String, body: Dictionary) -> Dictionary:
	var req: HTTPRequest = HTTPRequest.new()
	req.timeout = 10.0
	add_child(req)
	var auth: String = "Basic " + Marshalls.utf8_to_base64(server_key + ":")
	var url: String = "%s://%s:%d%s" % ["https" if ssl else "http", host, port, path]
	var err: Error = req.request(url, ["Authorization: " + auth, "Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		req.queue_free()
		return {"ok": false, "code": 0, "body": null}
	var result: Array = await req.request_completed
	req.queue_free()
	var code: int = result[1] if result[0] == HTTPRequest.RESULT_SUCCESS else 0
	var text: String = (result[3] as PackedByteArray).get_string_from_utf8()
	return {"ok": code >= 200 and code < 300, "code": code, "body": JSON.parse_string(text) if not text.is_empty() else null}


## Ağ durumunu sıkıştırılmış JSON'a çevirir (sunucu formatı: {p:[x,y,z], y:yaw, a:anim}).
static func encode_state(state: Dictionary) -> Dictionary:
	var p: Vector3 = state.get("pos", Vector3.ZERO)
	return {"p": [snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(p.z, 0.01)], "y": snappedf(float(state.get("yaw", 0.0)), 0.01), "a": str(state.get("anim", "idle"))}


static func decode_state(d: Dictionary) -> Dictionary:
	var p: Array = d.get("p", [0, 0, 0])
	if p.size() != 3:
		p = [0, 0, 0]
	return {"pos": Vector3(float(p[0]), float(p[1]), float(p[2])), "yaw": float(d.get("y", 0.0)), "anim": str(d.get("a", "idle"))}


static func decode_profile(d: Dictionary) -> Dictionary:
	var acc: Dictionary = {}
	var raw: Variant = d.get("acc", {})
	if raw is Dictionary:
		for slot: String in raw:
			acc[StringName(slot)] = StringName(str(raw[slot]))
	return {"pet": StringName(str(d.get("pet", ""))), "acc": acc, "name": str(d.get("name", ""))}


## Nakama oturum JWT'sinin içindeki kullanıcı kimliği (uid). İmza doğrulanmaz; sadece okumak için.
static func user_id_from_jwt(jwt: String) -> String:
	var parts: PackedStringArray = jwt.split(".")
	if parts.size() < 2:
		return ""
	var b64: String = parts[1].replace("-", "+").replace("_", "/")
	while b64.length() % 4 != 0:
		b64 += "="
	var payload: Variant = JSON.parse_string(Marshalls.base64_to_utf8(b64))
	return str((payload as Dictionary).get("uid", "")) if payload is Dictionary else ""
