extends "res://src/auth/auth_service.gd"
## Geliştirme için sahte auth (Config.AUTH_BACKEND = "mock"). Gerçek girişte (supabase) bunların hiçbiri yok.
## - Kod her zaman "000000".
## - Hızlı giriş: mail alanına "000" → kod sormadan giriş (cihaza özel kimlik).
## - Oturum cihazda hatırlanır: bir kez giriş yapınca sonraki açılışlarda giriş ekranı atlanır.

const DEV_CODE := "000000"
const QUICK_LOGIN := "000"
const SESSION_PATH := "user://mock_session.cfg"
var _signed_in := false
var _user_id := ""


func request_code(email: String) -> void:
	if not is_allowed_email(email):
		auth_failed.emit(email_rejected_message())
		return
	code_sent.emit(email)


func verify_code(email: String, code: String) -> void:
	if not is_allowed_email(email):
		auth_failed.emit("Geçersiz mail.")
		return
	if code != DEV_CODE:
		auth_failed.emit("Kod hatalı.")
		return
	_sign_in("mock-" + email.get_slice("@", 0))


## Mail ve kod olmadan giriş. Kimlik cihaza özel: iki telefon aynı odada karışmaz.
func quick_sign_in() -> void:
	_sign_in(device_user_id())


static func device_user_id() -> String:
	return "mock-dev-" + OS.get_unique_id().sha256_text().substr(0, 10)


func restore_session() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(SESSION_PATH) != OK:
		return false
	var id: String = str(cfg.get_value("session", "user_id", ""))
	if id.is_empty():
		return false
	_signed_in = true
	_user_id = id
	signed_in.emit(_user_id, "mock-token")
	return true


func is_signed_in() -> bool:
	return _signed_in


func sign_out() -> void:
	_signed_in = false
	_user_id = ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_PATH))


func get_access_token() -> String:
	return "mock-token" if _signed_in else ""


func get_user_id() -> String:
	return _user_id


func _sign_in(id: String) -> void:
	_signed_in = true
	_user_id = id
	var cfg := ConfigFile.new()
	cfg.set_value("session", "user_id", id)
	cfg.save(SESSION_PATH)
	signed_in.emit(_user_id, "mock-token")
