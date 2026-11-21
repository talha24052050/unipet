extends RefCounted

const AuthService := preload("res://src/auth/auth_service.gd")


func test_email_domain_allowed() -> String:
	if not AuthService.is_school_email("ali.veli@std.yildiz.edu.tr"):
		return "öğrenci maili reddedildi"
	if not AuthService.is_school_email("  Ali@STD.Yildiz.edu.tr "):
		return "büyük harf/boşluk normalize edilmedi"
	return ""


func test_email_domain_rejected() -> String:
	for bad in ["ali@gmail.com", "ali@yildiz.edu.tr.evil.com", "std.yildiz.edu.tr", "@std.yildiz.edu.tr", "ali@"]:
		if AuthService.is_school_email(bad):
			return "kabul edilmemeliydi: " + bad
	return ""


func test_chat_message_roundtrip() -> String:
	var m := ChatMessage.emote("el_salla")
	m.sender_id = "p1"
	var back := ChatMessage.from_dict(m.to_dict())
	if back.kind != ChatMessage.Kind.EMOTE or back.payload != "el_salla" or back.sender_id != "p1":
		return "roundtrip bozuk"
	return ""


func test_free_text_trimmed() -> String:
	var m := ChatMessage.free_text("  " + "a".repeat(500) + "  ")
	if m.payload.length() != 200:
		return "200 karaktere kırpılmadı: %d" % m.payload.length()
	return ""


func test_character_def_validation() -> String:
	var d := CharacterDef.new()
	d.id = &"test"
	d.model_path = "res://x.glb"
	if d.validate().is_empty():
		return "animasyonlar eksikken geçerli sayıldı"
	for a in CharacterDef.REQUIRED_ANIMS:
		d.animation_map[a] = a
	d.accessory_bones = {"head": "Head"}
	var errs := d.validate()
	if not errs.is_empty():
		return "geçerli tanım reddedildi: %s" % errs
	d.accessory_bones["tail"] = "Tail"
	if d.validate().is_empty():
		return "bilinmeyen slot kabul edildi"
	return ""


func test_local_profile_roundtrip() -> String:
	var LocalProfile: GDScript = load("res://src/core/local_profile.gd")
	var path: String = "user://test_profile.cfg"
	var p: RefCounted = LocalProfile.new()
	p.pet_id = &"yeti"
	p.accessories = {&"head": &"hat_cap", &"back": &"backpack"}
	p.save(path)
	var back: RefCounted = LocalProfile.load_or_default(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if back.pet_id != &"yeti" or back.accessories.get(&"head") != &"hat_cap" or back.accessories.size() != 2:
		return "profil geri okunamadı: %s %s" % [back.pet_id, back.accessories]
	var empty: RefCounted = LocalProfile.load_or_default("user://yok.cfg")
	if empty.pet_id != Config.DEFAULT_PET_ID:
		return "kayıt yokken varsayılan pet gelmedi"
	return ""


func test_any_valid_email_when_school_not_required() -> String:
	for good in ["ali@gmail.com", "a.b@outlook.com.tr", " Ali@STD.Yildiz.edu.tr "]:
		if not AuthService.is_valid_email(good):
			return "geçerli mail reddedildi: " + good
	for bad in ["ali", "ali@", "@gmail.com", "ali@gmail", "a b@gmail.com", "a@@b.com", "ali@.com"]:
		if AuthService.is_valid_email(bad):
			return "geçersiz mail kabul edildi: " + bad
	if AuthService.is_allowed_email("ali@gmail.com") == Config.REQUIRE_SCHOOL_EMAIL:
		return "is_allowed_email Config.REQUIRE_SCHOOL_EMAIL'e uymuyor"
	return ""


func test_server_address_parsing() -> String:
	var LS: GDScript = load("res://src/core/local_settings.gd")
	var cases: Dictionary = {
		"192.168.1.5": {"host": "192.168.1.5", "port": 7350, "ssl": false},
		" 192.168.1.5:8000 ": {"host": "192.168.1.5", "port": 8000, "ssl": false},
		"https://abc-def.trycloudflare.com/": {"host": "abc-def.trycloudflare.com", "port": 443, "ssl": true},
		"http://Oyun.local": {"host": "oyun.local", "port": 7350, "ssl": false},
	}
	for text: String in cases:
		var got: Dictionary = LS.parse_server_address(text)
		if str(got) != str(cases[text]):
			return "%s -> %s" % [text, got]
	for bad: String in ["", "   ", "1.2.3.4:abc", "1.2.3.4:99999", "https://a.com/yol", "a b"]:
		if not LS.parse_server_address(bad).is_empty():
			return "geçersiz adres kabul edildi: %s" % bad
	return ""


func test_display_name_cleaning() -> String:
	var LP: GDScript = load("res://src/core/local_profile.gd")
	var cases: Dictionary = {"  Ali   Veli ": "Ali Veli", "Şükrü_42": "Şükrü_42", "<b>x</b>": "bxb", "çok uzun bir takma ad deneme": "çok uzun bir tak"}
	for raw: String in cases:
		if LP.clean_name(raw) != cases[raw]:
			return "%s -> '%s' (beklenen '%s')" % [raw, LP.clean_name(raw), cases[raw]]
	if LP.name_from_email("ali.veli@gmail.com") != "ali veli":
		return "mailden isim yanlış: %s" % LP.name_from_email("ali.veli@gmail.com")
	return ""


func test_effective_server_release_fallback() -> String:
	var LS: GDScript = load("res://src/core/local_settings.gd")
	var path: String = "user://test_secrets.cfg"
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("nakama", "host", "1-2-3-4.sslip.io")
	cfg.set_value("nakama", "port", 443)
	cfg.set_value("nakama", "ssl", true)
	cfg.save(path)
	var dev_empty: Dictionary = LS.effective_server("", false, path)
	var rel_empty: Dictionary = LS.effective_server("", true, path)
	var rel_typed: Dictionary = LS.effective_server("192.168.1.5", true, path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if not dev_empty.is_empty():
		return "geliştirmede boş adres tek oyunculu olmalı"
	if rel_empty.get("host") != "1-2-3-4.sslip.io" or rel_empty.get("ssl") != true:
		return "yayında gömülü sunucu kullanılmalı: %s" % rel_empty
	if rel_typed.get("host") != "192.168.1.5":
		return "yazılan adres öncelikli olmalı"
	return ""


func test_dev_build_uses_mock_offline() -> String:
	if not Config.IS_RELEASE and (Config.AUTH_BACKEND != "mock" or Config.NETWORK_BACKEND != "offline"):
		return "geliştirme derlemesi mock/offline olmalı"
	return ""
