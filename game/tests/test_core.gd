extends RefCounted

const AuthService := preload("res://src/auth/auth_service.gd")


func test_email_domain_allowed() -> String:
	if not AuthService.is_allowed_email("ali.veli@std.yildiz.edu.tr"):
		return "öğrenci maili reddedildi"
	if not AuthService.is_allowed_email("  Ali@STD.Yildiz.edu.tr "):
		return "büyük harf/boşluk normalize edilmedi"
	return ""


func test_email_domain_rejected() -> String:
	for bad in ["ali@gmail.com", "ali@yildiz.edu.tr.evil.com", "std.yildiz.edu.tr", "@std.yildiz.edu.tr", "ali@"]:
		if AuthService.is_allowed_email(bad):
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
