extends RefCounted
## Serbest yazılı sohbet ve grup adları için Türkçe argo/küfür, spam ve uzunluk filtresi.
## Sunucu tarafındaki (server/nakama/modules/index.js) kurallarla birebir uyumludur.

const MAX_FREE_LEN: int = 80
const MAX_GROUP_NAME_LEN: int = 24

const BAD_WORDS_EXACT: PackedStringArray = [
	"amk", "aq", "amq", "oc", "pic", "got", "sg", "siktir", "sik", "yarak", "meme",
]
const BAD_WORDS_SUB: PackedStringArray = [
	"orospu", "yarrak", "amcik", "sikerim", "sikeyim", "sikik", "siktig", "pezevenk",
	"kahpe", "ibne", "gavat", "yavsak", "serefsiz", "surtuk", "dalyarak", "kaltak",
	"amina", "anani", "bacini", "pust",
]


static func normalize_for_filter(raw: String) -> String:
	var low: String = raw.replace("İ", "i").replace("I", "ı").to_lower()
	var map: Dictionary = {
		"ç": "c", "ğ": "g", "ı": "i", "ö": "o", "ş": "s", "ü": "u",
		"0": "o", "1": "i", "3": "e", "4": "a", "5": "s", "7": "t",
		"@": "a", "$": "s",
	}
	var out: String = ""
	for i: int in low.length():
		var ch: String = low.substr(i, 1)
		if ch == "\u0307":
			continue
		out += str(map.get(ch, ch))
	return out


static func _squash_repeats(s: String) -> String:
	var out: String = ""
	var prev: String = ""
	for i: int in s.length():
		var ch: String = s.substr(i, 1)
		var code: int = ch.unicode_at(0)
		if code < 97 or code > 122:
			continue
		if ch != prev:
			out += ch
			prev = ch
	return out


static func is_offensive(text: String) -> bool:
	var n: String = normalize_for_filter(text)
	var cur_word: String = ""
	for i: int in n.length():
		var ch: String = n.substr(i, 1)
		var code: int = ch.unicode_at(0)
		if code >= 97 and code <= 122:
			cur_word += ch
		else:
			if not cur_word.is_empty():
				if BAD_WORDS_EXACT.has(cur_word):
					return true
				cur_word = ""
	if not cur_word.is_empty() and BAD_WORDS_EXACT.has(cur_word):
		return true

	var squashed: String = _squash_repeats(n)
	for bad: String in BAD_WORDS_SUB:
		if squashed.contains(_squash_repeats(bad)):
			return true
	return false


static func _has_excessive_char_spam(text: String) -> bool:
	var run: int = 1
	var prev: String = ""
	for i: int in text.length():
		var ch: String = text.substr(i, 1)
		if ch == prev and ch != " ":
			run += 1
			if run >= 8:
				return true
		else:
			prev = ch
			run = 1
	return false


## Serbest sohbet metnini doğrular ve temizler: {"ok": bool, "text": String, "reason": String}
static func sanitize_free_text(raw: String, max_len: int = MAX_FREE_LEN) -> Dictionary:
	var cleaned: String = ""
	var prev_space: bool = false
	for i: int in raw.strip_edges().length():
		var ch: String = raw.strip_edges().substr(i, 1)
		var code: int = ch.unicode_at(0)
		if code < 32:
			continue
		if ch == " " or ch == "\t":
			if not prev_space:
				cleaned += " "
				prev_space = true
		else:
			cleaned += ch
			prev_space = false
	cleaned = cleaned.strip_edges().left(max_len)
	if cleaned.is_empty():
		return {"ok": false, "text": "", "reason": "Boş mesaj gönderilemez."}
	if is_offensive(cleaned):
		return {"ok": false, "text": "", "reason": "Mesaj uygunsuz ifade içeriyor."}
	if _has_excessive_char_spam(cleaned):
		return {"ok": false, "text": "", "reason": "Çok fazla tekrarlayan karakter var."}
	return {"ok": true, "text": cleaned, "reason": ""}
