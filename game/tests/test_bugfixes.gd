extends RefCounted
## 2026-11-22 hata listesinden: çıkışta oturum dosyası, WebSocket el sıkışma hatası, aksesuar çıkarma, kullanıcı adı.

const Supa := preload("res://src/auth/supabase_auth_service.gd")
const Nk := preload("res://src/net/nakama_network_service.gd")
const ProfileSync := preload("res://src/net/profile_sync.gd")


func test_sign_out_deletes_session_immediately() -> String:
	var a: Node = Supa.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(a)
	var path: String = Supa.SESSION_PATH
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string("x")
	f.close()
	a.set("_access_token", "eski")
	a.call("sign_out")  # bilerek await yok: giriş ekranı hemen açılsa bile eski oturum kalmamalı
	var left: bool = FileAccess.file_exists(path)
	a.queue_free()
	if left:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		return "çıkışta oturum dosyası hemen silinmedi"
	return ""


func test_handshake_failure_emits_disconnected() -> String:
	var n: Node = Nk.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(n)
	var got: Array = []
	n.disconnected.connect(func(r: String) -> void: got.append(r))
	# TCP bağlantısını kabul edip hemen kapatan sahte sunucu: WebSocket el sıkışması (tünel o an düşmüş gibi) başarısız
	var srv: TCPServer = TCPServer.new()
	var port: int = 18765
	while srv.listen(port, "127.0.0.1") != OK and port < 18800:
		port += 1
	var sock: WebSocketPeer = n.get("_socket")
	sock.connect_to_url("ws://127.0.0.1:%d/ws" % port)
	n.set("_connecting", true)
	var t0: int = Time.get_ticks_msec()
	while got.is_empty() and Time.get_ticks_msec() - t0 < 8000:
		if srv.is_connection_available():
			srv.take_connection().disconnect_from_host()
		n.call("_process", 0.016)
		OS.delay_msec(20)
	srv.stop()
	var st: int = sock.get_ready_state()
	n.queue_free()
	return "" if not got.is_empty() else "bağlantı kurulamadığında 'koptu' yayınlanmadı (soket durumu %d)" % st


func test_db_username_matches_schema() -> String:
	var re: RegEx = RegEx.create_from_string("^[a-zA-Z0-9_çğıöşüÇĞİÖŞÜ]{3,20}$")
	for raw: String in ["Ali Veli", "ali-veli", "Şule_42", "çok uzun bir takma ad deneme"]:
		var u: String = ProfileSync.db_username(raw)
		if re.search(u) == null:
			return "şemaya uymayan kullanıcı adı: '%s' → '%s'" % [raw, u]
	return ""


func test_sign_out_clears_state_without_waiting() -> String:
	var a: Node = Supa.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(a)
	a.set("_access_token", "eski")
	a.set("_expires_at", int(Time.get_unix_time_from_system()) + 3600)
	a.call("sign_out")
	var still: bool = a.call("is_signed_in")
	var tok: String = a.get("_access_token")
	a.queue_free()
	if still or not tok.is_empty():
		return "çıkıştan hemen sonra hâlâ girişli görünüyor"
	return ""


func test_disconnect_cancels_pending_connect() -> String:
	var n: Node = Nk.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(n)
	var g0: int = n.get("_conn_gen")
	n.call("disconnect_from_server")
	var g1: int = n.get("_conn_gen")
	n.queue_free()
	return "" if g1 > g0 else "disconnect_from_server süren bağlanmayı iptal etmiyor"
