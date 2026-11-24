extends RefCounted
## Cihaz ayarları (user://settings.cfg). Şimdilik: arkadaşlarla oynamak için sunucu adresi ve ses ayarları.

const PATH: String = "user://settings.cfg"
## Sunucu adresi verilmezse kullanılan Nakama portu (server/docker-compose.yml).
const DEFAULT_PORT: int = 7350

var server_address: String = ""
var sfx_enabled: bool = true
var sfx_volume_db: float = 0.0
## Geliştirici modu (Talha 2026-11-24): açıkken giriş ekranı yok (cihaza özel sahte hesapla otomatik giriş);
## kapalıyken normal mod (mail + kod, Supabase). -1 = varsayılan: yayın dışı derlemelerde (editör ve test APK) açık.
## Yayın (imzalı) sürümünde her zaman kapalı.
const DEV_MODE_DEFAULT: int = -1
var dev_mode: int = DEV_MODE_DEFAULT


static func load_or_default(path: String = PATH) -> RefCounted:
	var s: RefCounted = new()
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(path) == OK:
		s.server_address = str(cfg.get_value("server", "address", ""))
		s.sfx_enabled = bool(cfg.get_value("audio", "sfx_enabled", true))
		s.sfx_volume_db = float(cfg.get_value("audio", "sfx_volume_db", 0.0))
		s.dev_mode = int(cfg.get_value("dev", "mode", DEV_MODE_DEFAULT))
	return s


func save(path: String = PATH) -> Error:
	var cfg: ConfigFile = ConfigFile.new()
	var _err: Error = cfg.load(path)
	cfg.set_value("server", "address", server_address)
	cfg.set_value("audio", "sfx_enabled", sfx_enabled)
	cfg.set_value("audio", "sfx_volume_db", sfx_volume_db)
	cfg.set_value("dev", "mode", dev_mode)
	return cfg.save(path)


## Bu ayarlarla geliştirici modu açık mı? release: imzalı yayın; _editor: Godot'tan kaynakla çalıştırma.
static func resolve_dev_mode(setting: int, release: bool, _editor: bool = true) -> bool:
	if release:
		return false
	if setting >= 0:
		return setting == 1
	return true


## Kullanılacak sunucu: oyuncunun girdiği adres; boşsa ve yayın derlemesiyse res://secrets.cfg [nakama].
## {} = tek oyunculu.
static func effective_server(typed_address: String, release: bool, secrets_path: String = "res://secrets.cfg") -> Dictionary:
	var typed: Dictionary = parse_server_address(typed_address)
	if not typed.is_empty() or not release:
		return typed
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(secrets_path) != OK or str(cfg.get_value("nakama", "host", "")).is_empty():
		return {}
	return {"host": str(cfg.get_value("nakama", "host")), "port": int(cfg.get_value("nakama", "port", 443)),
		"ssl": bool(cfg.get_value("nakama", "ssl", true))}


## "192.168.1.5", "192.168.1.5:7350", "https://abc.trycloudflare.com" → {"host", "port", "ssl"}.
## Boş ya da geçersizse {} (tek oyunculu).
static func parse_server_address(text: String) -> Dictionary:
	var t: String = text.strip_edges().to_lower()
	if t.is_empty():
		return {}
	var ssl: bool = false
	if t.begins_with("https://"):
		ssl = true
		t = t.substr(8)
	elif t.begins_with("http://"):
		t = t.substr(7)
	t = t.trim_suffix("/")
	if t.is_empty() or "/" in t or " " in t:
		return {}
	var host: String = t
	var port: int = 443 if ssl else DEFAULT_PORT
	var colon: int = t.rfind(":")
	if colon > 0:
		var p: String = t.substr(colon + 1)
		if not p.is_valid_int() or int(p) <= 0 or int(p) > 65535:
			return {}
		port = int(p)
		host = t.substr(0, colon)
	if host.is_empty():
		return {}
	return {"host": host, "port": port, "ssl": ssl}
