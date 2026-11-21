extends RefCounted

const Supa := preload("res://src/auth/supabase_auth_service.gd")


func test_parse_session_ok() -> String:
	var s: Dictionary = Supa.parse_session({"access_token": "a", "refresh_token": "r", "expires_in": 3600, "user": {"id": "u1"}})
	if s.get("user_id") != "u1" or s.get("access_token") != "a" or s.get("expires_in") != 3600:
		return "oturum ayrıştırılamadı: %s" % s
	return ""


func test_parse_session_rejects_incomplete() -> String:
	for bad: Variant in [null, "x", {}, {"access_token": "a"}, {"access_token": "a", "refresh_token": "r", "user": {}}]:
		if not Supa.parse_session(bad).is_empty():
			return "eksik oturum kabul edildi: %s" % bad
	return ""


func test_error_messages_turkish() -> String:
	if not Supa.error_message(0, null).contains("bağlan"):
		return "bağlantı hatası mesajı yanlış"
	if not Supa.error_message(429, null).contains("sık"):
		return "429 mesajı yanlış"
	if not Supa.error_message(403, {"msg": "Token has expired or is invalid"}).contains("Kod"):
		return "kod hatası mesajı yanlış"
	return ""


func test_unconfigured_service_fails_gracefully() -> String:
	var svc: Node = Supa.new()
	var configured: bool = svc.call("is_configured")
	svc.free()
	if configured and not FileAccess.file_exists("res://secrets.cfg"):
		return "ayar yokken yapılandırılmış sayıldı"
	return ""
