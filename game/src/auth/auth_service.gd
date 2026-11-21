extends Node
## Kimlik doğrulama arayüzü (soyut).
## Akış: request_code(email) -> kullanıcı maildeki kodu girer -> verify_code(email, code)
## Implementasyonlar: MockAuthService (geliştirme), SupabaseAuthService (Config.AUTH_BACKEND = "supabase").

signal code_sent(email: String)
signal signed_in(user_id: String, session_token: String)
signal auth_failed(reason: String)


static func is_allowed_email(email: String) -> bool:
	var e := email.strip_edges().to_lower()
	var at := e.rfind("@")
	if at <= 0 or at == e.length() - 1:
		return false
	var domain := e.substr(at + 1)
	return domain in Config.ALLOWED_EMAIL_DOMAINS


func request_code(_email: String) -> void:
	push_error("AuthService.request_code soyut")


func verify_code(_email: String, _code: String) -> void:
	push_error("AuthService.verify_code soyut")


func is_signed_in() -> bool:
	return false


## Cihazda kayıtlı oturumu geri yükler (await edilir). Yoksa false.
func restore_session() -> bool:
	return false


func sign_out() -> void:
	pass


## Sunucu çağrılarında (profil, Nakama köprüsü) kullanılacak erişim anahtarı.
func get_access_token() -> String:
	return ""


func get_user_id() -> String:
	return ""
