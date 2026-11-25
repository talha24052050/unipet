extends RefCounted

const Nakama := preload("res://src/net/nakama_network_service.gd")


func test_state_roundtrip() -> String:
	var enc: Dictionary = Nakama.encode_state({"pos": Vector3(1.234, 0.5, -2.0), "yaw": 1.57, "anim": "walk"})
	var dec: Dictionary = Nakama.decode_state(JSON.parse_string(JSON.stringify(enc)))
	if not (dec["pos"] as Vector3).is_equal_approx(Vector3(1.23, 0.5, -2.0)) or dec["anim"] != "walk":
		return "durum bozuldu: %s" % dec
	return ""


func test_jwt_user_id() -> String:
	var payload: String = Marshalls.utf8_to_base64(JSON.stringify({"uid": "abc-123", "exp": 1})).replace("+", "-").replace("/", "_").replace("=", "")
	if Nakama.user_id_from_jwt("x." + payload + ".sig") != "abc-123":
		return "jwt uid okunamadı"
	if Nakama.user_id_from_jwt("bozuk") != "":
		return "bozuk jwt boş dönmeli"
	return ""


func _md(op: int, obj: Dictionary) -> Dictionary:
	return {"match_data": {"op_code": str(op), "data": Marshalls.utf8_to_base64(JSON.stringify(obj))}}


func test_incoming_messages_emit_signals() -> String:
	var n: Node = Nakama.new()
	var got: Array = []
	n.player_state.connect(func(id: String, st: Dictionary) -> void: got.append(["state", id, st["anim"]]))
	n.chat_received.connect(func(m: ChatMessage) -> void: got.append(["chat", m.sender_id, m.payload, m.kind]))
	n.player_profile.connect(func(id: String, pr: Dictionary) -> void: got.append(["profile", id, pr["pet"], pr["acc"].get(&"head")]))
	n.player_joined.connect(func(id: String, _st: Dictionary) -> void: got.append(["join", id]))
	n.player_left.connect(func(id: String) -> void: got.append(["left", id]))
	n.call("_handle", _md(1, {"id": "B", "p": [1, 0, 2], "y": 0.1, "a": "walk"}))
	n.call("_handle", _md(2, {"s": "B", "k": 0, "p": "selam"}))
	n.call("_handle", _md(2, {"s": "B", "k": 9, "p": "x"}))
	n.call("_handle", _md(4, {"id": "B", "pet": "yeti", "acc": {"head": "hat_cap"}}))
	n.call("_handle", _md(3, {"players": [{"id": "C", "p": [0, 0, 0], "y": 0, "a": "idle", "pet": "ninja", "acc": {}}]}))
	n.call("_handle", {"match_presence_event": {"joins": [{"user_id": "D"}], "leaves": [{"user_id": "B"}]}})
	n.free()
	var expect: Array = [
		["state", "B", "walk"], ["chat", "B", "selam", ChatMessage.Kind.PRESET], ["profile", "B", &"yeti", &"hat_cap"],
		["join", "C"], ["profile", "C", &"ninja", null], ["join", "D"], ["left", "B"],
	]
	if str(got) != str(expect):
		return "sinyaller beklenenden farklı:\n%s\n%s" % [got, expect]
	return ""


func test_fast_reconnect_keeps_player_until_last_session_leaves() -> String:
	var n: Node = Nakama.new()
	var got: Array = []
	n.player_joined.connect(func(id: String, _st: Dictionary) -> void: got.append(["join", id]))
	n.player_left.connect(func(id: String) -> void: got.append(["left", id]))
	# E yeniden bağlandı: yeni oturum (s2) eski oturumun (s1) çıkışından ÖNCE geliyor.
	n.call("_handle", {"match_presence_event": {"joins": [{"user_id": "E", "session_id": "s1"}]}})
	n.call("_handle", {"match_presence_event": {"joins": [{"user_id": "E", "session_id": "s2"}]}})
	n.call("_handle", {"match_presence_event": {"leaves": [{"user_id": "E", "session_id": "s1"}]}})
	var mid: String = str(got)
	n.call("_handle", {"match_presence_event": {"leaves": [{"user_id": "E", "session_id": "s2"}]}})
	n.free()
	if mid != str([["join", "E"]]):
		return "eski oturumun çıkışı oyuncuyu silmemeli: %s" % mid
	if str(got) != str([["join", "E"], ["left", "E"]]):
		return "son oturum çıkınca ayrılmalı: %s" % got
	return ""


func test_non_fatal_rpc_error_does_not_disconnect() -> String:
	var n: Node = Nakama.new()
	var drops: Array = []
	var results: Array = []
	n.disconnected.connect(func(reason: String) -> void: drops.append(reason))
	n.purchase_finished.connect(func(item: String, ok: bool, reason: String) -> void: results.append([item, ok, reason]))
	n.set("_socket_open", true)
	n.buy_item("crown_star")  # soket gerçekte kapalı: zarf gönderilmez ama istek kaydedilir
	var cid: String = str(n.get("_cid"))
	n.call("_handle", {"cid": cid, "error": {"message": "yetersiz"}})
	n.call("_send_request", {"rpc": {"id": "find_room"}}, func(_r: Dictionary) -> void: pass, true)
	n.call("_handle", {"cid": str(n.get("_cid")), "error": {"message": "oda yok"}})
	n.set("_socket_open", false)
	n.free()
	if str(results) != str([["crown_star", false, "sunucu hatası"]]):
		return "dükkan hatası satın almayı başarısız bitirmeli: %s" % results
	if drops != ["oda yok"]:
		return "sadece oda isteği hatası bağlantıyı düşürmeli: %s" % drops
	return ""


func test_snapshot_player_without_position_joins_without_state() -> String:
	var n: Node = Nakama.new()
	var got: Array = []
	n.player_joined.connect(func(id: String, st: Dictionary) -> void: got.append([id, st.is_empty()]))
	n.call("_handle", _md(3, {"players": [{"id": "F", "p": [0, 0, 0], "y": 0, "a": "idle"}, {"id": "G", "p": [3, 0, 4], "y": 0, "a": "idle"}]}))
	n.free()
	if str(got) != str([["F", true], ["G", false]]):
		return "konumsuz oyuncu durumsuz katılmalı: %s" % got
	return ""
