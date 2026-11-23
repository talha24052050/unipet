extends RefCounted
## Koşu yarışı kuralları — server/nakama/modules/index.js (raceJoin/raceCp/raceTick/raceReward/raceView) ile AYNI.
## Sunucusuz modda OfflineNetworkService bunları kullanır; çok oyunculuda sunucu otoriterdir.

const DATA: String = "res://data/race.json"
const CP_RADIUS: float = 9.0
const JOIN_RADIUS: float = 25.0
const LOBBY_MS: int = 10000
const COUNTDOWN_MS: int = 3000
const TIMEOUT_MS: int = 90000
const RESULTS_MS: int = 8000
const MAX_RACERS: int = 8
const MAX_SPEED: float = 9.0


## [[x, z, d], ...] (d = başlangıçtan pist mesafesi)
static func load_cps(path: String = DATA) -> Array:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var out: Array = []
	if d is Dictionary:
		for c: Dictionary in d.get("cps", []):
			out.append([float(c["p"][0]), float(c["p"][1]), float(c["d"])])
	return out


static func new_race() -> Dictionary:
	return {"phase": "idle", "lobby_ends": 0, "start_at": 0, "ends_at": 0, "done_until": 0, "racers": {}, "order": [], "n": 0}


static func _dist(pos: Vector3, cp: Array) -> float:
	return Vector2(pos.x - float(cp[0]), pos.z - float(cp[1])).length()


static func join(r: Dictionary, uid: String, pos: Vector3, now: int, cps: Array) -> String:
	if r["phase"] != "idle" and r["phase"] != "lobby":
		return "yarış sürüyor"
	if (r["racers"] as Dictionary).has(uid):
		return ""
	if (r["racers"] as Dictionary).size() >= MAX_RACERS:
		return "yarış dolu"
	if _dist(pos, cps[0]) > JOIN_RADIUS:
		return "başlangıç çizgisine gel"
	if r["phase"] == "idle":
		r["phase"] = "lobby"
		r["lobby_ends"] = now + LOBBY_MS
		r["racers"] = {}
		r["order"] = []
	r["racers"][uid] = {"cp": 0, "time": 0, "place": 0}
	return ""


static func leave(r: Dictionary, uid: String) -> bool:
	if not (r["racers"] as Dictionary).has(uid):
		return false
	(r["racers"] as Dictionary).erase(uid)
	if r["phase"] == "lobby" and (r["racers"] as Dictionary).is_empty():
		r["phase"] = "idle"
	return true


## 0 geçersiz, 1 geçti, 2 bitirdi.
static func checkpoint(r: Dictionary, uid: String, i: int, pos: Vector3, now: int, cps: Array) -> int:
	var rc: Variant = (r["racers"] as Dictionary).get(uid)
	if r["phase"] != "running" or rc == null or int(rc["place"]) > 0 or now < int(r["start_at"]):
		return 0
	if i != int(rc["cp"]) + 1 or i >= cps.size():
		return 0
	if _dist(pos, cps[i]) > CP_RADIUS:
		return 0
	if float(cps[i][2]) - 2.0 * CP_RADIUS > MAX_SPEED * float(now - int(r["start_at"])) / 1000.0:
		return 0
	rc["cp"] = i
	if i < cps.size() - 1:
		return 1
	rc["time"] = now - int(r["start_at"])
	(r["order"] as Array).append(uid)
	rc["place"] = (r["order"] as Array).size()
	return 2


static func tick(r: Dictionary, now: int) -> bool:
	if r["phase"] == "lobby" and now >= int(r["lobby_ends"]):
		r["n"] = (r["racers"] as Dictionary).size()
		if int(r["n"]) == 0:
			r["phase"] = "idle"
			return true
		r["phase"] = "running"
		r["start_at"] = now + COUNTDOWN_MS
		r["ends_at"] = int(r["start_at"]) + TIMEOUT_MS
		return true
	if r["phase"] == "running":
		var all_done: bool = true
		for id: String in r["racers"]:
			if int(r["racers"][id]["place"]) == 0:
				all_done = false
		if all_done or now >= int(r["ends_at"]):
			r["phase"] = "done"
			r["done_until"] = now + RESULTS_MS
			return true
	if r["phase"] == "done" and now >= int(r["done_until"]):
		r["phase"] = "idle"
		r["racers"] = {}
		r["order"] = []
		return true
	return false


static func reward(place: int, n: int) -> int:
	if place <= 0:
		return 0
	if place == 1 and n >= 2:
		return 3
	if place == 2 and n >= 3:
		return 2
	return 1


static func view(r: Dictionary, now: int, names: Dictionary, cps: Array) -> Dictionary:
	var list: Array = []
	for id: String in r["racers"]:
		var rc: Dictionary = r["racers"][id]
		list.append({"id": id, "name": names.get(id, ""), "cp": rc["cp"], "time": rc["time"], "place": rc["place"]})
	return {"phase": r["phase"], "lobby_in": maxi(0, int(r["lobby_ends"]) - now), "start_in": int(r["start_at"]) - now,
		"racers": list, "cps": cps.size() - 1}


## Sıralama (canlı): bitirenler yere göre, sonra en çok kontrol noktası geçen.
static func standings(racers: Array) -> Array:
	var s: Array = racers.duplicate()
	s.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pa: int = int(a["place"])
		var pb: int = int(b["place"])
		if pa > 0 or pb > 0:
			return pb == 0 or (pa > 0 and pa < pb)
		return int(a["cp"]) > int(b["cp"]))
	return s
