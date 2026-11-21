extends RefCounted
## Pet bakımı kuralları (saf, durum tutmaz). Sunucudaki server/nakama/modules/index.js `careApply`
## ile BİREBİR aynı olmalı; test_care.gd ve module.test.js aynı örneklerle ikisini de doğrular.
##
## Durum: {"food": 0..100, "joy": 0..100, "energy": 0..100, "t": unix saniye (son hesap)}

const MAX: float = 100.0
## Saatte azalma.
const DECAY_PER_HOUR: Dictionary = {"food": 6.0, "joy": 4.0, "energy": 5.0}
## En fazla bu kadar saatlik azalma uygulanır (uzun aradan dönen oyuncu sıfırda bulmasın).
const MAX_DECAY_HOURS: float = 12.0
## Eylem → {stat: artış}. "cooldown": aynı eylem için bekleme (saniye).
const ACTIONS: Dictionary = {
	"eat": {"food": 35.0, "energy": 5.0, "cooldown": 600},
	"rest": {"energy": 30.0, "cooldown": 300},
	"social": {"joy": 8.0, "cooldown": 30},
	"play": {"joy": 15.0, "energy": -10.0, "food": -5.0, "cooldown": 120},
}
const STATS: PackedStringArray = ["food", "joy", "energy"]
## Eylem yerleri (sunucudaki CARE_SPOTS ile aynı dosya).
const SPOTS_PATH: String = "res://data/care_spots.json"
## İstemcinin kendisinin isteyebildiği eylemler ("social" sadece chat/emote ile kazanılır).
const PLAYER_ACTIONS: PackedStringArray = ["eat", "rest", "play"]
## Eylem → konum şartı (care_spots.json anahtarı).
const ACTION_SPOT: Dictionary = {"eat": "eat"}


## `pos` bu eylem türünün yerlerinden birinin yakınında mı?
static func near_spot(kind: String, pos: Vector3) -> bool:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SPOTS_PATH))
	if not data is Dictionary:
		return false
	for s: Dictionary in (data as Dictionary).get(kind, []):
		if Vector2(pos.x - float(s["x"]), pos.z - float(s["z"])).length() <= float(s["r"]):
			return true
	return false


## Konum şartı varsa ve sağlanmıyorsa kullanıcıya gösterilecek sebep, yoksa "".
static func location_error(action: String, pos: Vector3) -> String:
	if ACTION_SPOT.has(action) and not near_spot(ACTION_SPOT[action], pos):
		return "Yemek için Yemekhane, Hokka ya da Kayıntı'ya git"
	return ""


static func new_state(now: int) -> Dictionary:
	return {"food": 80.0, "joy": 80.0, "energy": 80.0, "t": now}


## Geçen zamana göre azalmayı uygular (yeni sözlük döner).
static func decay(state: Dictionary, now: int) -> Dictionary:
	var out: Dictionary = state.duplicate()
	var hours: float = clampf(float(now - int(state.get("t", now))) / 3600.0, 0.0, MAX_DECAY_HOURS)
	for s: String in STATS:
		out[s] = snappedf(clampf(float(state.get(s, MAX)) - DECAY_PER_HOUR[s] * hours, 0.0, MAX), 0.01)
	out["t"] = maxi(now, int(state.get("t", now)))
	return out


## Eylemi uygular. last_action: {eylem: unix} (bekleme kontrolü). Dönen: {"ok", "state", "reason"}.
static func apply(state: Dictionary, action: String, now: int, last_action: Dictionary) -> Dictionary:
	if not ACTIONS.has(action):
		return {"ok": false, "state": state, "reason": "bilinmeyen eylem"}
	var rule: Dictionary = ACTIONS[action]
	if now - int(last_action.get(action, -1000000)) < int(rule["cooldown"]):
		return {"ok": false, "state": decay(state, now), "reason": "biraz bekle"}
	var s: Dictionary = decay(state, now)
	for stat: String in STATS:
		if rule.has(stat):
			s[stat] = snappedf(clampf(float(s[stat]) + float(rule[stat]), 0.0, MAX), 0.01)
	return {"ok": true, "state": s, "reason": ""}


## Petin genel ruh hali → animasyon/yüz ifadesi için (en düşük değere göre).
static func mood(state: Dictionary) -> StringName:
	var low: float = minf(float(state.get("food", MAX)), minf(float(state.get("joy", MAX)), float(state.get("energy", MAX))))
	if low < 20.0:
		return &"sad"
	if low < 50.0:
		return &"ok"
	return &"happy"
