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
