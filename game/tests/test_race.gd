extends RefCounted
## Koşu yarışı: kurallar sunucuyla aynı senaryoda aynı sonucu verir, kontrol noktaları sunucuyla aynı.

const R := preload("res://src/minigame/race_rules.gd")
const RaceClient := preload("res://src/minigame/race_client.gd")


func _at(cps: Array, i: int) -> Vector3:
	return Vector3(float(cps[i][0]), 0, float(cps[i][1]))


func test_race_flow() -> String:
	# server/nakama/test/module.test.js "koşu yarışı" ile aynı senaryo
	var cps: Array = R.load_cps()
	if cps.size() != 7:
		return "7 kontrol noktası bekleniyordu: %d" % cps.size()
	var r: Dictionary = R.new_race()
	var t0: int = 1000000
	if R.join(r, "R1", _at(cps, 0) + Vector3(40, 0, 0), t0, cps) != "başlangıç çizgisine gel":
		return "uzaktan katılınmamalı"
	if R.join(r, "R1", _at(cps, 0), t0, cps) != "" or r["phase"] != "lobby":
		return "katılınca lobi açılmalı"
	R.join(r, "R2", _at(cps, 0) + Vector3(2, 0, 0), t0 + 1000, cps)
	if R.tick(r, t0 + 5000) or not R.tick(r, t0 + 10000) or r["phase"] != "running":
		return "lobi 10 sn sonra koşuya geçmeli"
	var go: int = r["start_at"]
	if R.checkpoint(r, "R1", 1, _at(cps, 1), go - 500, cps) != 0 or R.checkpoint(r, "R1", 2, _at(cps, 2), go + 20000, cps) != 0 \
			or R.checkpoint(r, "R1", 1, _at(cps, 1), go + 1000, cps) != 0:
		return "erken / sıra atlama / imkânsız hız reddedilmeli"
	var t: int = go
	for i: int in range(1, cps.size()):
		t += 7000
		if R.checkpoint(r, "R1", i, _at(cps, i), t, cps) != (2 if i == cps.size() - 1 else 1):
			return "kapı %d geçilmeli" % i
	if int(r["racers"]["R1"]["place"]) != 1 or R.reward(1, 2) != 3 or R.reward(2, 2) != 1:
		return "sıra/ödül yanlış"
	if not R.tick(r, go + 90001) or r["phase"] != "done" or not R.tick(r, go + 98001) or r["phase"] != "idle":
		return "bitiş/boşta geçişi yanlış"
	return ""


func test_cps_match_server() -> String:
	var js: String = FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join("../server/nakama/modules/index.js"))
	var m: RegExMatch = RegEx.create_from_string("var RACE_CPS = ([[].*[]]);").search(js)
	if m == null:
		return "index.js RACE_CPS yok"
	var server: Array = JSON.parse_string(m.get_string(1))
	var cps: Array = R.load_cps()
	if server.size() != cps.size():
		return "kontrol noktası sayısı farklı"
	for i: int in cps.size():
		for k: int in 3:
			if absf(float(server[i][k]) - float(cps[i][k])) > 0.01:
				return "kontrol noktası %d farklı" % i
	return ""


func test_standings_and_slots() -> String:
	var s: Array = R.standings([{"id": "a", "cp": 3, "place": 0}, {"id": "b", "cp": 6, "place": 2}, {"id": "c", "cp": 6, "place": 1}, {"id": "d", "cp": 4, "place": 0}])
	if s.map(func(x: Dictionary) -> String: return x["id"]) != ["c", "b", "d", "a"]:
		return "sıralama yanlış: %s" % [s]
	if RaceClient.fmt_time(65.4) != "01:05.4":
		return "süre biçimi: %s" % RaceClient.fmt_time(65.4)
	return ""
