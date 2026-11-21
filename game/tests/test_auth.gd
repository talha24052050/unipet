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


func test_profile_row_roundtrip() -> String:
	var PS: GDScript = load("res://src/net/profile_sync.gd")
	var LP: GDScript = load("res://src/core/local_profile.gd")
	var p: RefCounted = LP.new()
	p.pet_id = &"yeti"
	p.display_name = "Ali Veli"
	p.accessories = {&"head": &"hat_cap"}
	var row: Dictionary = PS.to_row(p, "u-1")
	if row["id"] != "u-1" or row["pet_id"] != "yeti" or row["username"] != "Ali_Veli" or row["accessories"]["head"] != "hat_cap":
		return "satır yanlış: %s" % row
	var back: RefCounted = PS.from_row(JSON.parse_string(JSON.stringify(row)), LP.new())
	if back.pet_id != &"yeti" or back.display_name != "Ali Veli" or back.accessories.get(&"head") != &"hat_cap":
		return "geri dönüş yanlış: %s %s %s" % [back.pet_id, back.display_name, back.accessories]
	var short: RefCounted = LP.new()
	short.display_name = "Al"
	if PS.to_row(short, "u").has("username"):
		return "3 harften kısa ad gönderilmemeli (tablo kısıtı)"
	return ""


func test_profile_sync_inactive_in_mock() -> String:
	if Config.AUTH_BACKEND == "mock" and Services.profile_sync != null and Services.profile_sync.is_active():
		return "sahte girişte profil senkronu kapalı olmalı"
	return ""
