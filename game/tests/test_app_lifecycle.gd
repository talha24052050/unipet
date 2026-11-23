extends RefCounted
## iOS / Android arka plan ve geri dönüş (AppLifecycle) testleri.

const AppLifecycleScript := preload("res://src/core/app_lifecycle.gd")
const NetworkService := preload("res://src/net/network_service.gd")
const NetworkSyncScript := preload("res://src/net/network_sync.gd")
const VirtualJoystickScript := preload("res://src/player/virtual_joystick.gd")


class MockReconnectNet extends NetworkService:
	var connect_calls: int = 0

	func connect_to_server(_token: String) -> void:
		connect_calls += 1

	func join_zone(_zone_id: String) -> void:
		pass

	func leave_zone() -> void:
		pass

	func send_state(_state: Dictionary) -> void:
		pass

	func send_chat(_msg: ChatMessage) -> void:
		pass


func test_lifecycle_pause_resume_deduplicated() -> String:
	var lc: Node = AppLifecycleScript.new()
	var events: Array[String] = []
	lc.app_paused.connect(func() -> void: events.append("pause"))
	lc.app_resumed.connect(func(_s: float) -> void: events.append("resume"))

	# Başlangıçta resume etkisiz olmalı
	lc.call("handle_resume")
	if not events.is_empty():
		lc.free()
		return "pause olmadan resume tetiklenmemeli"

	# Çift pause tek sinyal üretmeli
	lc.call("handle_pause")
	lc.call("handle_pause")
	lc.call("handle_resume")
	lc.call("handle_resume")

	var ok: bool = events == ["pause", "resume"] and int(lc.get("pause_count")) == 1 and int(lc.get("resume_count")) == 1
	lc.free()
	return "" if ok else "beklenmeyen yaşam döngüsü olayları: %s" % str(events)


func test_sfx_suspends_on_pause_and_resumes() -> String:
	var prev_enabled: bool = Sfx.enabled
	var prev_suspended: bool = Sfx.suspended
	Sfx.enabled = true
	Sfx.set_suspended(true)
	var before: int = Sfx.play_count
	Sfx.play(&"ui_click")
	var during: int = Sfx.play_count
	Sfx.set_suspended(false)
	Sfx.play(&"ui_click")
	var after: int = Sfx.play_count

	Sfx.enabled = prev_enabled
	Sfx.set_suspended(prev_suspended)
	if during != before:
		return "askıdayken ses çalınmamalı"
	if after <= before:
		return "geri dönünce ses tekrar çalmalı"
	return ""


func test_joystick_releases_touch_on_pause() -> String:
	var joy: Control = VirtualJoystickScript.new()
	joy.size = Vector2(300, 300)
	var ended: Array[bool] = []
	joy.touch_ended.connect(func() -> void: ended.append(true))

	joy.call("handle_touch", 0, true, Vector2(100, 100))
	joy.call("handle_drag", 0, Vector2(180, 100))
	if not joy.call("is_active") or (joy.get("value") as Vector2).length() <= 0.1:
		joy.free()
		return "joystick aktif olmadı"

	joy.call("release_touch")
	var ok: bool = not joy.call("is_active") and (joy.get("value") as Vector2) == Vector2.ZERO and ended.size() == 1
	joy.free()
	return "" if ok else "pause sonrası joystick dokunuşu bırakmadı"


func test_network_sync_reconnects_immediately_on_resume() -> String:
	var mock_net: MockReconnectNet = MockReconnectNet.new()
	var sync: Node = NetworkSyncScript.new()
	sync.set("net", mock_net)
	(Engine.get_main_loop() as SceneTree).root.add_child(sync)

	var initial_calls: int = mock_net.connect_calls
	# Bağlantı kopunca bekleme moduna geçer
	mock_net.disconnected.emit("background")
	if not bool(sync.get("_waiting_reconnect")):
		sync.free()
		mock_net.free()
		return "kopma sonrası _waiting_reconnect true olmalı"

	# Uygulama geri dönünce 30 sn beklemeden hemen yeniden bağlanmalı
	sync.call("_on_app_resumed", 15.0)
	var calls_after: int = mock_net.connect_calls
	var waiting_after: bool = bool(sync.get("_waiting_reconnect"))
	sync.free()
	mock_net.free()

	if calls_after != initial_calls + 1 or waiting_after:
		return "geri dönüşte hemen yeniden bağlanmadı (calls=%d->%d, waiting=%s)" % [initial_calls, calls_after, str(waiting_after)]
	return ""
