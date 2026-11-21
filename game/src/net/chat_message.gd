class_name ChatMessage
extends RefCounted
## Tek chat mesaj formatı. Serbest chat ileride aynı yapıyla açılır.

enum Kind { PRESET, EMOTE, FREE }

var kind: Kind
## PRESET/EMOTE için kimlik (ör. "selam", "el_salla"); FREE için metin.
var payload: String
var sender_id: String
var sent_at_unix: float


static func preset(id: String) -> ChatMessage:
	return _make(Kind.PRESET, id)


static func emote(id: String) -> ChatMessage:
	return _make(Kind.EMOTE, id)


static func free_text(text: String) -> ChatMessage:
	return _make(Kind.FREE, text.strip_edges().left(200))


static func _make(k: Kind, p: String) -> ChatMessage:
	var m := ChatMessage.new()
	m.kind = k
	m.payload = p
	m.sent_at_unix = Time.get_unix_time_from_system()
	return m


func to_dict() -> Dictionary:
	return {"kind": kind, "payload": payload, "sender_id": sender_id, "t": sent_at_unix}


static func from_dict(d: Dictionary) -> ChatMessage:
	var m := ChatMessage.new()
	m.kind = int(d.get("kind", Kind.PRESET)) as Kind
	m.payload = str(d.get("payload", ""))
	m.sender_id = str(d.get("sender_id", ""))
	m.sent_at_unix = float(d.get("t", 0.0))
	return m
