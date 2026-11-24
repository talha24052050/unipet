class_name ChatMessage
extends RefCounted
## Tek chat mesaj formatı: Kampüs geneli, Kafe salonları, Grup odaları, Arkadaşlar arası Özel (DM) ve Konum Pini destekler.

enum Kind { PRESET, EMOTE, FREE }

var kind: Kind
## PRESET/EMOTE için kimlik (ör. "selam", "wave"); FREE için metin.
var payload: String
var sender_id: String
var sender_name: String = ""
## Kanal: "campus" | "cafe:<id>" | "group:<id>" | "dm:<peer_id>"
var channel: String = "campus"
## Buluşma / konum pini (true ise tıklayınca yanına ışınlanılabilir)
var has_pin: bool = false
var pin_place: String = ""
var pin_pos: Vector2 = Vector2.ZERO
var sent_at_unix: float


static func preset(id: String, ch: String = "campus") -> ChatMessage:
	var m: ChatMessage = _make(Kind.PRESET, id)
	m.channel = ch
	return m


static func emote(id: String, ch: String = "campus") -> ChatMessage:
	var m: ChatMessage = _make(Kind.EMOTE, id)
	m.channel = ch
	return m


static func free_text(text: String, ch: String = "campus") -> ChatMessage:
	var m: ChatMessage = _make(Kind.FREE, text.strip_edges().left(200))
	m.channel = ch
	return m


static func location_pin(place_label: String, pos_xz: Vector2, ch: String = "campus") -> ChatMessage:
	var clean_place: String = place_label.strip_edges().left(40)
	if clean_place.is_empty():
		clean_place = "Kampüs"
	var msg_text: String = "📍 %s'dayım, buluşalım!" % clean_place
	var m: ChatMessage = _make(Kind.FREE, msg_text.left(80))
	m.channel = ch
	m.has_pin = true
	m.pin_place = clean_place
	m.pin_pos = pos_xz
	return m


static func _make(k: Kind, p: String) -> ChatMessage:
	var m := ChatMessage.new()
	m.kind = k
	m.payload = p
	m.sent_at_unix = Time.get_unix_time_from_system()
	return m


func to_dict() -> Dictionary:
	var d: Dictionary = {
		"kind": kind,
		"payload": payload,
		"sender_id": sender_id,
		"sender_name": sender_name,
		"channel": channel,
		"t": sent_at_unix,
	}
	if has_pin:
		d["has_pin"] = true
		d["pin_place"] = pin_place
		d["pin_x"] = snappedf(pin_pos.x, 0.1)
		d["pin_z"] = snappedf(pin_pos.y, 0.1)
	return d


static func from_dict(d: Dictionary) -> ChatMessage:
	var m := ChatMessage.new()
	m.kind = int(d.get("kind", Kind.PRESET)) as Kind
	m.payload = str(d.get("payload", ""))
	m.sender_id = str(d.get("sender_id", ""))
	m.sender_name = str(d.get("sender_name", ""))
	m.channel = str(d.get("channel", "campus"))
	if m.channel.is_empty():
		m.channel = "campus"
	m.has_pin = bool(d.get("has_pin", false))
	if m.has_pin:
		m.pin_place = str(d.get("pin_place", ""))
		m.pin_pos = Vector2(float(d.get("pin_x", 0.0)), float(d.get("pin_z", 0.0)))
	m.sent_at_unix = float(d.get("t", 0.0))
	return m
