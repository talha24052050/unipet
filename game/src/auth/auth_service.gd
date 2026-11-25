extends Node
## Kimlik doğrulama arayüzü (soyut).
## Akış: request_code(email) -> kullanıcı maildeki kodu girer -> verify_code(email, code)
## Implementasyonlar: MockAuthService (geliştirme), SupabaseAuthService (Config.AUTH_BACKEND = "supabase").

signal code_sent(email: String)
signal signed_in(user_id: String, session_token: String)
signal auth_failed(reason: String)


## Girişe izin verilen mail mi? Config.REQUIRE_SCHOOL_EMAIL'e göre okul maili ya da herhangi geçerli mail.
static func is_allowed_email(email: String) -> bool:
	return is_school_email(email) if Config.REQUIRE_SCHOOL_EMAIL else is_valid_email(email)


static func is_valid_email(email: String) -> bool:
	var e := email.strip_edges().to_lower()
	var at := e.rfind("@")
	if at <= 0 or at == e.length() - 1 or e.count("@") != 1 or " " in e:
		return false
	var domain := e.substr(at + 1)
	return "." in domain and not domain.begins_with(".") and not domain.ends_with(".")


static func is_school_email(email: String) -> bool:
	if not is_valid_email(email):
		return false
	var e := email.strip_edges().to_lower()
	return e.substr(e.rfind("@") + 1) in Config.ALLOWED_EMAIL_DOMAINS


## Mail reddedilince gösterilecek mesaj.
static func email_rejected_message() -> String:
	if Config.REQUIRE_SCHOOL_EMAIL:
		return "Sadece YTÜ öğrenci maili (@std.yildiz.edu.tr) ile giriş yapılabilir."
	return "Geçerli bir mail adresi gir."


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


## Giriş hesabını kalıcı siler ve oturumu kapatır. "" = başarılı, aksi halde hata. (Play Store hesap silme şartı)
func delete_account() -> String:
	sign_out()
	await Engine.get_main_loop().process_frame
	return ""


## Sunucu çağrılarında (profil, Nakama köprüsü) kullanılacak erişim anahtarı.
func get_access_token() -> String:
	return ""


func get_user_id() -> String:
	return ""
