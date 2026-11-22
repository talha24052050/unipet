extends RefCounted
## Bu örnekler server/nakama/test/module.test.js'te de var: istemci ve sunucu kuralları aynı kalmalı.

const R := preload("res://src/care/pet_care_rules.gd")


func test_decay_two_hours() -> String:
	var s: Dictionary = R.decay({"food": 80.0, "joy": 80.0, "energy": 80.0, "t": 1000}, 1000 + 7200)
	if s["food"] != 68.0 or s["joy"] != 72.0 or s["energy"] != 70.0 or s["t"] != 8200:
		return "2 saatlik azalma yanlış: %s" % s
	return ""


func test_decay_capped_and_clamped() -> String:
	var s: Dictionary = R.decay({"food": 50.0, "joy": 30.0, "energy": 100.0, "t": 0}, 100 * 3600)
	# 12 saat sınırı: food 50-72 → 0, joy 30-48 → 0, energy 100-60 = 40
	if s["food"] != 0.0 or s["joy"] != 0.0 or s["energy"] != 40.0:
		return "sınır/kırpma yanlış: %s" % s
	var back: Dictionary = R.decay({"food": 50.0, "joy": 50.0, "energy": 50.0, "t": 5000}, 4000)
	if back["food"] != 50.0 or back["t"] != 5000:
		return "geriye giden saat artış yaratmamalı: %s" % back
	return ""


func test_eat_and_cooldown() -> String:
	var st: Dictionary = {"food": 40.0, "joy": 60.0, "energy": 50.0, "t": 0}
	var r: Dictionary = R.apply(st, "eat", 0, {})
	if not r["ok"] or r["state"]["food"] != 75.0 or r["state"]["energy"] != 55.0:
		return "yemek yanlış: %s" % r
	var again: Dictionary = R.apply(r["state"], "eat", 300, {"eat": 0})
	if again["ok"]:
		return "bekleme süresi uygulanmadı"
	var later: Dictionary = R.apply(r["state"], "eat", 601, {"eat": 0})
	if not later["ok"]:
		return "bekleme bitince yenebilmeli"
	if R.apply(st, "uçmak", 0, {})["ok"]:
		return "bilinmeyen eylem kabul edildi"
	return ""


func test_play_costs_and_clamps() -> String:
	var r: Dictionary = R.apply({"food": 3.0, "joy": 95.0, "energy": 5.0, "t": 0}, "play", 0, {})
	if r["state"]["joy"] != 100.0 or r["state"]["energy"] != 0.0 or r["state"]["food"] != 0.0:
		return "oyun eylemi kırpma yanlış: %s" % r["state"]
	return ""


func test_mood() -> String:
	if R.mood({"food": 90.0, "joy": 90.0, "energy": 90.0}) != &"happy":
		return "mutlu olmalı"
	if R.mood({"food": 90.0, "joy": 10.0, "energy": 90.0}) != &"sad":
		return "üzgün olmalı"
	return ""


func test_care_spots_and_location() -> String:
	if not R.near_spot("eat", Vector3(-100, 0, -95)):
		return "Yemekhane yakını yemek yeri sayılmadı"
	if R.near_spot("eat", Vector3.ZERO):
		return "Ortabahçe ortası yemek yeri sayıldı"
	if R.location_error("rest", Vector3.ZERO) != "":
		return "dinlenmenin konum şartı olmamalı"
	return ""


func test_offline_care_flow() -> String:
	var Off: GDScript = load("res://src/net/offline_network_service.gd")
	var n: Node = Off.new()
	n.set("_care", R.new_state(int(Time.get_unix_time_from_system())))
	var got: Array = []
	n.care_updated.connect(func(st: Dictionary, ok: bool, reason: String) -> void: got.append([ok, reason, st]))
	n.call("send_state", {"pos": Vector3.ZERO})
	n.call("send_care_action", "eat")
	n.call("send_state", {"pos": Vector3(-100, 0, -95)})
	n.call("send_care_action", "eat")
	n.call("send_care_action", "social")
	n.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://care.cfg"))
	if got.size() != 3 or got[0][0] or not got[1][0] or got[2][0]:
		return "offline bakım akışı yanlış: %s" % [got.map(func(x: Array) -> Array: return [x[0], x[1]])]
	if float(got[1][2]["food"]) <= 80.0:
		return "yemek tokluğu artırmadı"
	return ""


func test_location_bonus() -> String:
	var st: Dictionary = {"food": 50.0, "joy": 50.0, "energy": 50.0, "t": 0}
	var stadium: Vector3 = Vector3(-285, 0, 49)
	if R.bonus_for("play", stadium) != 2.0 or R.bonus_for("play", Vector3(500, 0, 500)) != 1.0 or R.bonus_for("eat", stadium) != 1.0:
		return "bonus yerleri yanlış"
	var r: Dictionary = R.apply(st, "play", 0, {}, R.bonus_for("play", stadium))
	# sunucu testindeki örnekle aynı: joy 50+30, energy 50-10 (eksi değişmez), food 50-5
	if r["state"]["joy"] != 80.0 or r["state"]["energy"] != 40.0 or r["state"]["food"] != 45.0 or not r["bonus"]:
		return "bonuslu oyun yanlış: %s" % r["state"]
	if R.bonus_for("rest", Vector3(10, 0, 10)) != 2.0:
		return "Ortabahçe'de dinlenme bonusu yok"
	return ""
