extends Node
## Oyuncu geri bildirimi (6.3 kapalı test). Supabase girişliyse `feedback` tablosuna yazar
## (şema: server/supabase/002_feedback.sql; oyuncular sadece yazabilir, okuyamaz).
## Geliştirme (mock giriş) sürümünde user://feedback.log dosyasına ekler.

const SECRETS_PATH: String = "res://secrets.cfg"
const LOCAL_LOG: String = "user://feedback.log"
const MIN_LEN: int = 3
const MAX_LEN: int = 1000
const APP_VERSION_SETTING: String = "application/config/version"

## ok: gönderildi mi; message: oyuncuya gösterilecek kısa metin.
signal sent(ok: bool, message: String)

var _url: String = ""
var _anon_key: String = ""


func _ready() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(SECRETS_PATH) == OK:
		_url = str(cfg.get_value("supabase", "url", "")).trim_suffix("/")
		_anon_key = str(cfg.get_value("supabase", "anon_key", ""))


func uses_server() -> bool:
	return Config.AUTH_BACKEND == "supabase" and not _url.is_empty() and Services.auth.is_signed_in()


static func clean(text: String) -> String:
	return text.strip_edges().left(MAX_LEN)


static func is_valid(text: String) -> bool:
	return clean(text).length() >= MIN_LEN


func send(text: String) -> void:
	var msg: String = clean(text)
	if msg.length() < MIN_LEN:
		sent.emit(false, "Biraz daha yaz (en az %d harf)." % MIN_LEN)
		return
	var row: Dictionary = {"message": msg, "app_version": str(ProjectSettings.get_setting(APP_VERSION_SETTING, "")).left(32),
		"platform": OS.get_name().left(32)}
	if not uses_server():
		var f: FileAccess = FileAccess.open(LOCAL_LOG, FileAccess.READ_WRITE if FileAccess.file_exists(LOCAL_LOG) else FileAccess.WRITE)
		if f == null:
			sent.emit(false, "Kaydedilemedi.")
			return
		f.seek_end()
		f.store_line(JSON.stringify(row))
		f.close()
		sent.emit(true, "Teşekkürler! (geliştirme sürümü: cihaza kaydedildi)")
		return
	var res: Dictionary = await _post("/rest/v1/feedback", row)
	if res["ok"]:
		sent.emit(true, "Teşekkürler, aldık!")
	elif res["code"] == 0:
		sent.emit(false, "İnternet yok gibi, sonra tekrar dene.")
	else:
		sent.emit(false, "Gönderilemedi, biraz sonra tekrar dene.")


func _post(path: String, body: Dictionary) -> Dictionary:
	var req: HTTPRequest = HTTPRequest.new()
	req.timeout = 10.0
	add_child(req)
	var headers: PackedStringArray = ["apikey: " + _anon_key, "Authorization: Bearer " + Services.auth.get_access_token(),
		"Content-Type: application/json", "Prefer: return=minimal"]
	if req.request(_url + path, headers, HTTPClient.METHOD_POST, JSON.stringify(body)) != OK:
		req.queue_free()
		return {"ok": false, "code": 0}
	var result: Array = await req.request_completed
	req.queue_free()
	var code: int = result[1] if result[0] == HTTPRequest.RESULT_SUCCESS else 0
	return {"ok": code >= 200 and code < 300, "code": code}
