extends RefCounted
## Google Play kullanıcı içeriği şartları: engelleme, şikayet, koşulları kabul notu.

const BlockList := preload("res://src/core/block_list.gd")
const NetworkService := preload("res://src/net/network_service.gd")
const TEST_PATH: String = "user://_test_blocked.cfg"


func _clean() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	BlockList.reset_cache()


func test_block_list_persists_and_unblocks() -> String:
	_clean()
	var err: String = ""
	BlockList.block("u-kotu", "Kötü", TEST_PATH)
	BlockList.reset_cache()
	if not BlockList.is_blocked("u-kotu", TEST_PATH):
		err = "engel dosyadan geri okunmadı"
	elif BlockList.is_blocked("u-iyi", TEST_PATH) or BlockList.is_blocked("", TEST_PATH):
		err = "engellenmeyen oyuncu engelli görünüyor"
	else:
		BlockList.unblock("u-kotu", TEST_PATH)
		BlockList.reset_cache()
		if BlockList.is_blocked("u-kotu", TEST_PATH):
			err = "engel kaldırılamadı"
	_clean()
	return err


func test_report_reasons_match_server() -> String:
	var src: String = FileAccess.get_file_as_string("res://../server/nakama/modules/index.js")
	for k: String in NetworkService.REPORT_REASONS:
		if not src.is_empty() and not src.contains('"%s"' % k):
			return "sunucu şikayet nedenini tanımıyor: %s" % k
	if NetworkService.REPORT_REASONS.size() < 2:
		return "en az iki şikayet nedeni olmalı"
	return ""


func test_profile_card_has_block_and_report() -> String:
	var Popup: GDScript = load("res://src/ui/player_profile_popup.gd")
	var p: Control = Popup.new()
	p.call("_build_ui")
	var err: String = ""
	if p.find_child("BlockButton", true, false) == null or p.find_child("ReportButton", true, false) == null:
		err = "profil kartında Engelle / Şikayet et yok"
	elif p.find_child("ReportReasonRow", true, false).get_child_count() != NetworkService.REPORT_REASONS.size():
		err = "şikayet nedeni butonları eksik"
	p.free()
	return err
