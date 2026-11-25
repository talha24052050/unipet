extends RefCounted
## Engellenen oyuncular (Google Play kullanıcı içeriği şartı: oyuncu başkasını engelleyebilmeli).
## Cihazda saklanır (user://blocked.cfg). Engellenen oyuncunun mesajları, baloncukları ve arkadaşlık istekleri
## hiç gösterilmez (ağ katmanında süzülür); engellerken arkadaşlık da bozulur.

const PATH: String = "user://blocked.cfg"

static var _ids: Dictionary = {}  # id -> ad
static var _loaded_from: String = ""


static func _ensure(path: String) -> void:
	if _loaded_from == path:
		return
	_loaded_from = path
	_ids = {}
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(path) == OK:
		var d: Variant = cfg.get_value("blocked", "ids", {})
		if d is Dictionary:
			_ids = d


static func _save(path: String) -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("blocked", "ids", _ids)
	cfg.save(path)


static func is_blocked(id: String, path: String = PATH) -> bool:
	if id.is_empty():
		return false
	_ensure(path)
	return _ids.has(id)


static func block(id: String, display_name: String = "", path: String = PATH) -> void:
	if id.is_empty():
		return
	_ensure(path)
	_ids[id] = display_name
	_save(path)


static func unblock(id: String, path: String = PATH) -> void:
	_ensure(path)
	if _ids.erase(id):
		_save(path)


static func all(path: String = PATH) -> Dictionary:
	_ensure(path)
	return _ids.duplicate()


## Testler / hesap silme: bellekteki listeyi bırak (dosya yeniden okunur).
static func reset_cache() -> void:
	_loaded_from = ""
	_ids = {}
