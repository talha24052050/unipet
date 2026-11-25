extends "res://src/auth/auth_service.gd"
## Supabase Auth (GoTrue REST) ile mail + tek kullanımlık kod girişi.
## Ayarlar: res://secrets.cfg [supabase] url, anon_key  (repo'da yok; CI GitHub secret'tan yazar).
## Oturum cihazda şifreli saklanır (user://session.cfg, anahtar cihaz kimliğinden türetilir) ve
## süresi dolmadan yenilenir. Okul maili zorunluluğu (Config.REQUIRE_SCHOOL_EMAIL) istemcide de
## kontrol edilir ama ASIL kontrol sunucudadır (Supabase hook'u + Nakama, docs/SUPABASE.md).

const SECRETS_PATH: String = "res://secrets.cfg"
const SESSION_PATH: String = "user://session.cfg"
## Süresi bitmeden bu kadar saniye önce yenile.
const REFRESH_MARGIN_S: int = 120

var _url: String = ""
var _anon_key: String = ""
var _access_token: String = ""
var _refresh_token: String = ""
var _user_id: String = ""
var _expires_at: int = 0  # unix saniye
var _refresh_timer: Timer
const REFRESH_RETRY_S: float = 30.0


func _ready() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(SECRETS_PATH) != OK:
		push_error("Supabase ayarı yok: %s" % SECRETS_PATH)
	else:
		_url = str(cfg.get_value("supabase", "url", "")).trim_suffix("/")
		_anon_key = str(cfg.get_value("supabase", "anon_key", ""))
	_refresh_timer = Timer.new()
	_refresh_timer.one_shot = true
	_refresh_timer.timeout.connect(_refresh)
	add_child(_refresh_timer)


func is_configured() -> bool:
	return not _url.is_empty() and not _anon_key.is_empty()


func request_code(email: String) -> void:
	var e: String = email.strip_edges().to_lower()
	if not is_allowed_email(e):
		auth_failed.emit(email_rejected_message())
		return
	var res: Dictionary = await _post("/auth/v1/otp", {"email": e, "create_user": true})
	if res["ok"]:
		code_sent.emit(e)
	else:
		auth_failed.emit(error_message(res["code"], res["body"]))


func verify_code(email: String, code: String) -> void:
	var e: String = email.strip_edges().to_lower()
	var res: Dictionary = await _post("/auth/v1/verify", {"type": "email", "email": e, "token": code.strip_edges()})
	if not res["ok"] and (res["code"] == 400 or res["code"] == 403):
		# Google Play inceleme hesabı: incelemeci e-postaya erişemez. Supabase'de yalnızca o hesaba sayısal bir şifre
		# tanımlanır ve kod alanına yazılır (docs/PLAY_STORE.md). Şifresi olmayan normal hesaplarda bu deneme hep başarısız.
		var pw: Dictionary = await _post("/auth/v1/token?grant_type=password", {"email": e, "password": code.strip_edges()})
		if pw["ok"]:
			res = pw
	if not res["ok"]:
		auth_failed.emit(error_message(res["code"], res["body"]))
		return
	if not _accept_session(res["body"]):
		auth_failed.emit("Sunucudan geçersiz oturum geldi.")


## Kayıtlı oturum varsa yenileyerek geri yükler. Başarılıysa signed_in yayınlanır.
func restore_session() -> bool:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load_encrypted_pass(SESSION_PATH, _device_key()) != OK:
		return false
	_refresh_token = str(cfg.get_value("session", "refresh_token", ""))
	if _refresh_token.is_empty():
		return false
	return await _refresh()


func sign_out() -> void:
	# Önce yerel oturumu sil: çağıran beklemese bile giriş ekranı eski oturumu geri yükleyemesin.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_PATH))
	if _refresh_timer != null and _refresh_timer.is_inside_tree():
		_refresh_timer.stop()
	var token: String = _access_token
	_access_token = ""
	_refresh_token = ""
	_user_id = ""
	_expires_at = 0
	# Sunucu tarafı çıkış (token iptali) en iyi çaba: beklenmez. İnternet yoksa çıkış 15 sn takılıyordu; yerel oturum
	# zaten silindi. Token parametreyle gider, _access_token'a geri konmaz (istek sürerken is_signed_in true dönüyordu).
	if not token.is_empty():
		_post("/auth/v1/logout", {}, true, token)


## Supabase hesabını siler (server/supabase/003_account_delete.sql: profil ve geri bildirimler de gider).
func delete_account() -> String:
	if _access_token.is_empty():
		return "Oturum yok. Tekrar giriş yapıp dene."
	var res: Dictionary = await _post("/rest/v1/rpc/delete_my_account", {}, true)
	if not res["ok"]:
		return "Hesap silinemedi (%d). İnternetini kontrol edip tekrar dene." % res["code"]
	sign_out()
	return ""


func is_signed_in() -> bool:
	return not _access_token.is_empty() and Time.get_unix_time_from_system() < _expires_at


func get_access_token() -> String:
	return _access_token


func get_user_id() -> String:
	return _user_id


func _refresh() -> bool:
	var res: Dictionary = await _post("/auth/v1/token?grant_type=refresh_token", {"refresh_token": _refresh_token})
	if res["ok"] and _accept_session(res["body"]):
		return true
	if res["code"] == 400 or res["code"] == 401:
		# Yenileme anahtarı geçersiz: tekrar giriş gerekir.
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_PATH))
		_refresh_token = ""
	elif not _refresh_token.is_empty() and _refresh_timer != null and _refresh_timer.is_inside_tree():
		# Geçici hata (internet yok / sunucu 5xx): tek seferlik zamanlayıcı bir daha kurulmazsa oturum süresi dolar
		_refresh_timer.start(REFRESH_RETRY_S)
	return false


func _accept_session(body: Variant) -> bool:
	var s: Dictionary = parse_session(body)
	if s.is_empty():
		return false
	_access_token = s["access_token"]
	_refresh_token = s["refresh_token"]
	_user_id = s["user_id"]
	_expires_at = int(Time.get_unix_time_from_system()) + int(s["expires_in"])
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("session", "refresh_token", _refresh_token)
	cfg.save_encrypted_pass(SESSION_PATH, _device_key())
	_refresh_timer.start(maxf(10.0, float(s["expires_in"]) - REFRESH_MARGIN_S))
	signed_in.emit(_user_id, _access_token)
	return true


## GoTrue oturum cevabını ayrıştırır; eksikse {}.
static func parse_session(body: Variant) -> Dictionary:
	if not body is Dictionary:
		return {}
	var b: Dictionary = body
	var user: Variant = b.get("user")
	if not (b.has("access_token") and b.has("refresh_token") and user is Dictionary and (user as Dictionary).has("id")):
		return {}
	return {
		"access_token": str(b["access_token"]),
		"refresh_token": str(b["refresh_token"]),
		"expires_in": int(b.get("expires_in", 3600)),
		"user_id": str((user as Dictionary)["id"]),
	}


## Kullanıcıya gösterilecek Türkçe hata.
static func error_message(code: int, body: Variant) -> String:
	if code == 0:
		return "Sunucuya bağlanılamadı. İnternet bağlantını kontrol et."
	if code == 429:
		return "Çok sık denedin. Biraz bekleyip tekrar dene."
	var msg: String = ""
	if body is Dictionary:
		var d: Dictionary = body
		msg = str(d.get("msg", d.get("error_description", d.get("message", ""))))
	if code == 403 or msg.to_lower().contains("expired") or msg.to_lower().contains("invalid"):
		return "Kod hatalı ya da süresi dolmuş. Yeni kod iste."
	return "Giriş başarısız (%d)." % code


## token_override: with_auth'ta _access_token yerine kullanılacak anahtar (çıkışta yerel oturum silindikten sonra).
func _post(path: String, body: Dictionary, with_auth: bool = false, token_override: String = "") -> Dictionary:
	if not is_configured():
		return {"ok": false, "code": 0, "body": null}
	var req: HTTPRequest = HTTPRequest.new()
	req.timeout = 15.0
	add_child(req)
	var headers: PackedStringArray = ["apikey: " + _anon_key, "Content-Type: application/json"]
	if with_auth:
		headers.append("Authorization: Bearer " + (token_override if not token_override.is_empty() else _access_token))
	var err: Error = req.request(_url + path, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		req.queue_free()
		return {"ok": false, "code": 0, "body": null}
	var result: Array = await req.request_completed
	req.queue_free()
	var code: int = result[1]
	var text: String = (result[3] as PackedByteArray).get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text) if not text.is_empty() else null
	return {"ok": result[0] == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300, "code": code if result[0] == HTTPRequest.RESULT_SUCCESS else 0, "body": parsed}


## Oturum dosyasının şifresi: cihaza özgü (dosya başka cihaza kopyalanırsa açılmaz).
static func _device_key() -> String:
	return ("unipet-session-" + OS.get_unique_id()).sha256_text()
