extends "res://src/auth/auth_service.gd"
## Geliştirme için sahte auth: domain kontrolü gerçek, kod her zaman "000000".

const DEV_CODE := "000000"
var _signed_in := false


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
	signed_in.emit("mock-" + email.get_slice("@", 0), "mock-token")


func is_signed_in() -> bool:
	return _signed_in
