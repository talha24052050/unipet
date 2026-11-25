extends RefCounted
## Hesap silme (Google Play şartı): ayarlarda iki adımlı buton, yerel dosya temizliği, hesaba bağlı dosya listesi.

const AccountDeletion := preload("res://src/core/account_deletion.gd")
const SettingsPanel := preload("res://src/ui/settings_panel.gd")


func test_local_file_list_covers_account_data() -> String:
	for p: String in ["user://profile.cfg", "user://wallet.cfg", "user://social.cfg", "user://session.cfg"]:
		if not p in AccountDeletion.LOCAL_FILES:
			return "%s silinecekler listesinde değil" % p
	if "user://settings.cfg" in AccountDeletion.LOCAL_FILES:
		return "ses/sunucu ayarları hesaba bağlı değil, silinmemeli"
	return ""


func test_wipe_removes_given_files() -> String:
	var paths: PackedStringArray = ["user://_test_del_a.cfg", "user://_test_del_b.cfg"]
	for p: String in paths:
		var f: FileAccess = FileAccess.open(p, FileAccess.WRITE)
		f.store_string("x")
		f.close()
	AccountDeletion.wipe_local_files(paths)
	for p: String in paths:
		if FileAccess.file_exists(p):
			return "%s silinmedi" % p
	AccountDeletion.wipe_local_files(paths)  # olmayan dosyada hata vermemeli
	return ""


func test_settings_delete_button_needs_confirmation() -> String:
	var panel = SettingsPanel.new()
	var err: String = ""
	if panel.delete_button == null or panel.privacy_button == null or panel.terms_button == null:
		err = "gizlilik / koşullar / hesabı sil butonları yok"
	elif panel.delete_button.custom_minimum_size.y < 64.0:
		err = "hesap silme butonu en az 64 px olmalı"
	else:
		panel._on_delete_pressed()  # ilk dokunuş sadece onay ister
		if panel._deleting or panel.delete_button.text != "Eminim, sil" or not panel.delete_status.text.contains("KALICI"):
			err = "ilk dokunuş silmeye başlamamalı, onay istemeli"
		panel.open()
		if err.is_empty() and panel.delete_button.text != "Hesabı sil":
			err = "panel yeniden açılınca onay sıfırlanmalı"
	panel.free()
	return err


func test_legal_urls_point_to_site() -> String:
	for u: String in [Config.PRIVACY_URL, Config.TERMS_URL, Config.ACCOUNT_DELETE_URL]:
		if not u.begins_with("https://") or not u.ends_with(".html"):
			return "geçersiz yasal adres: %s" % u
	return ""
