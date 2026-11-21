extends "res://src/auth/auth_service.gd"
## Geliştirme için sahte auth: domain kontrolü gerçek, kod her zaman "000000".

const DEV_CODE := "000000"
var _signed_in := false
var _user_id := ""


func request_code(email: String) -> void:
	if not is_allowed_email(email):
		auth_failed.emit("Sadece YTÜ öğrenci maili (@std.yildiz.edu.tr) ile giriş yapılabilir.")
		return
	code_sent.emit(email)


func verify_code(email: String, code: String) -> void:
	if not is_allowed_email(email):
		auth_failed.emit("Geçersiz mail.")
		return
	if code != DEV_CODE:
		auth_failed.emit("Kod hatalı.")
		return
	_signed_in = true
	_user_id = "mock-" + email.get_slice("@", 0)
	signed_in.emit(_user_id, "mock-token")


func is_signed_in() -> bool:
	return _signed_in


func sign_out() -> void:
	_signed_in = false
	_user_id = ""


func get_access_token() -> String:
	return "mock-token" if _signed_in else ""


func get_user_id() -> String:
	return _user_id
