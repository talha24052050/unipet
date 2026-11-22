extends Label
## Bağlantı durumu: "Tek başına" | "Bağlanıyor…" | "Çevrimiçi · N kişi" | "Bağlantı koptu…".
## Sadece Services.net sinyallerini dinler; ağ koduna dokunmaz.

const OfflineNet := preload("res://src/net/offline_network_service.gd")

var _online: bool = false
var _others: Dictionary = {}


func _ready() -> void:
	add_theme_font_size_override("font_size", 20)
	var net: Node = Services.net
	if net is OfflineNet:
		text = "Tek başına"
		return
	text = "Bağlanıyor…"
	net.connected.connect(func() -> void: _set_text())
	net.room_joined.connect(func(_r: String) -> void:
		_online = true
		_set_text())
	net.disconnected.connect(func(_reason: String) -> void:
		_online = false
		_others.clear()
		text = "Bağlantı koptu, tekrar deneniyor…")
	net.player_joined.connect(func(id: String, _s: Dictionary) -> void:
		if id != net.local_player_id():
			_others[id] = true
		_set_text())
	net.player_left.connect(func(id: String) -> void:
		_others.erase(id)
		_set_text())


func _set_text() -> void:
	text = "Çevrimiçi · %d kişi" % (_others.size() + 1) if _online else "Bağlanıyor…"


## Test için: odadaki diğer oyuncu sayısı.
func others_count() -> int:
	return _others.size()
