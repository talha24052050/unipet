extends SceneTree
## Uçtan uca: gerçek Nakama'ya iki oyuncu bağlanır, aynı odada durum/profil/chat/çıkış gidip gelir.
## Kullanım: godot --headless --path game -s <repo>/tools/e2e/nakama_two_players.gd -- [host] [port]
## Sunucu UNIPET_DEV_AUTH=true ile çalışmalı (mock- kimlikleri).

## Çalışma zamanında yüklenir: -s scriptleri derlenirken autoload'lar (Services) henüz yok.
var Nakama: GDScript

var log_lines: PackedStringArray = []
var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		failures += 1


func _make(id: String, host: String, port: int) -> Node:
	var n: Node = Nakama.new()
	root.add_child(n)
	n.set("host", host)
	n.set("port", port)
	n.set("custom_id_override", id)
	return n


func _wait(cond: Callable, seconds: float = 8.0) -> bool:
	var t: float = 0.0
	while t < seconds:
		if cond.call():
			return true
		await process_frame
		t += 1.0 / 60.0
		await create_timer(0.016).timeout
	return false


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	Nakama = load("res://src/net/nakama_network_service.gd")
	var host: String = args[0] if args.size() > 0 else "127.0.0.1"
	var port: int = int(args[1]) if args.size() > 1 else 7350
	var a: Node = _make("mock-e2e-a", host, port)
	var b: Node = _make("mock-e2e-b", host, port)
	var ev: Dictionary = {"a_room": "", "b_room": "", "b_joined": [], "b_state": [], "b_profile": [], "a_chat": [], "b_chat": [], "a_left": [], "err": []}
	a.room_joined.connect(func(r: String) -> void: ev["a_room"] = r)
	b.room_joined.connect(func(r: String) -> void: ev["b_room"] = r)
	b.player_joined.connect(func(id: String, _s: Dictionary) -> void: ev["b_joined"].append(id))
	b.player_state.connect(func(id: String, s: Dictionary) -> void: ev["b_state"].append([id, s]))
	b.player_profile.connect(func(id: String, p: Dictionary) -> void: ev["b_profile"].append([id, p]))
	ev["a_care"] = []
	ev["b_care"] = []
	a.care_updated.connect(func(st: Dictionary, ok: bool, reason: String) -> void: ev["a_care"].append([ok, reason, st]))
	b.care_updated.connect(func(st: Dictionary, ok: bool, reason: String) -> void: ev["b_care"].append([ok, reason, st]))
	a.chat_received.connect(func(m: ChatMessage) -> void: ev["a_chat"].append(m.payload))
	b.chat_received.connect(func(m: ChatMessage) -> void: ev["b_chat"].append(m.payload))
	a.player_left.connect(func(id: String) -> void: ev["a_left"].append(id))
	for n: Node in [a, b]:
		n.disconnected.connect(func(r: String) -> void: ev["err"].append(r))

	await process_frame  # düğümler sahne ağacına girsin (HTTPRequest ancak o zaman çalışır)
	a.connect_to_server("mock-token")
	a.join_zone("kampus")
	check(await _wait(func() -> bool: return ev["a_room"] != "" or not ev["err"].is_empty()), "A odaya girdi %s %s" % [ev["a_room"], ev["err"]])
	a.send_profile(&"yeti", {&"head": &"hat_cap"}, "  Ali   Test ")
	b.connect_to_server("mock-token")
	b.join_zone("kampus")
	check(await _wait(func() -> bool: return ev["b_room"] != ""), "B odaya girdi")
	check(ev["a_room"] == ev["b_room"], "ikisi aynı odada")
	var a_id: String = a.local_player_id()
	check(await _wait(func() -> bool: return a_id in ev["b_joined"]), "B, A'yı görüyor (snapshot)")
	check(await _wait(func() -> bool: return ev["b_profile"].any(func(x: Array) -> bool: return x[0] == a_id and x[1]["pet"] == &"yeti" and x[1]["name"] == "Ali Test")), "B, A'nın petini ve temizlenmiş adını aldı")
	check(await _wait(func() -> bool: return not ev["a_care"].is_empty()), "A katılınca bakım durumunu aldı")
	ev["a_care"].clear()
	a.send_care_action("eat")
	check(await _wait(func() -> bool: return not ev["a_care"].is_empty()) and not ev["a_care"][0][0], "uzakta yemek reddedildi: %s" % [ev["a_care"].map(func(x: Array) -> String: return x[1])])
	ev["a_care"].clear()
	a.send_state({"pos": Vector3(-100, 0, -95), "yaw": 0.0, "anim": "idle"})
	await create_timer(0.3).timeout
	a.send_care_action("eat")
	check(await _wait(func() -> bool: return not ev["a_care"].is_empty()) and ev["a_care"][0][0], "Yemekhane'de yemek kabul edildi")
	a.send_state({"pos": Vector3(-99, 0, -94), "yaw": 1.0, "anim": "walk"})
	check(await _wait(func() -> bool: return ev["b_state"].any(func(x: Array) -> bool: return x[0] == a_id and (x[1]["pos"] as Vector3).is_equal_approx(Vector3(-99, 0, -94)))), "B, A'nın konumunu aldı")
	a.send_chat(ChatMessage.preset("selam"))
	check(await _wait(func() -> bool: return "selam" in ev["a_chat"] and "selam" in ev["b_chat"]), "chat ikisine de ulaştı")
	check(await _wait(func() -> bool: return ev["a_care"].any(func(x: Array) -> bool: return x[0] and x[1] == "")), "chat sonrası sosyal bakım puanı")
	b.send_chat(ChatMessage.free_text("serbest yazi"))
	await create_timer(1.0).timeout
	check(not ("serbest yazi" in ev["a_chat"]), "serbest yazı engellendi")
	var b_id: String = b.local_player_id()
	b.leave_zone()
	check(await _wait(func() -> bool: return b_id in ev["a_left"]), "A, B'nin çıktığını gördü")
	print("\n%s (%d hata)" % ["E2E GEÇTİ" if failures == 0 else "E2E BAŞARISIZ", failures])
	quit(1 if failures > 0 else 0)
