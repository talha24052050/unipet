extends RefCounted
## Mini oyunlar: ödül kuralları (sunucuyla aynı), frizbi yakalama, alan tespiti, sunucusuz ödül.

const Rules := preload("res://src/minigame/minigame_rules.gd")
const Frisbee := preload("res://src/minigame/frisbee_game.gd")
const Hub := preload("res://src/minigame/minigame_hub.gd")


func test_reward_rules() -> String:
	# server/nakama/test/module.test.js ile aynı örnekler
	if Rules.reward("frisbee", 9, 0) != 3 or Rules.reward("frisbee", 30, 0) != 5:
		return "ödül yanlış"
	if Rules.reward("frisbee", 99, 0) != 0 or Rules.reward("frisbee", 30, 13) != 2 or Rules.reward("yok", 30, 0) != 0:
		return "sınırlar yanlış"
	return ""


func test_rules_match_server() -> String:
	var js: String = FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join("../server/nakama/modules/index.js"))
	for needle: String in ["frisbee: { maxScore: %d, perDust: %d }" % [Rules.GAMES["frisbee"]["max_score"], Rules.GAMES["frisbee"]["per_dust"]],
			"MINIGAME_MAX_REWARD = %d;" % Rules.MAX_REWARD, "MINIGAME_DAILY_CAP = %d;" % Rules.DAILY_CAP]:
		if js.find(needle) < 0:
			return "sunucuda yok/farklı: %s" % needle
	return ""


func test_can_catch() -> String:
	var pet: Vector3 = Vector3(10, 0, 10)
	if not Frisbee.can_catch(0.8, Vector3(10.5, 1.0, 10), pet):
		return "inişteki yakın frizbi yakalanmalı"
	if Frisbee.can_catch(0.3, Vector3(10.5, 1.0, 10), pet):
		return "yükselirken yakalanmamalı"
	if Frisbee.can_catch(0.8, Vector3(13, 1.0, 10), pet) or Frisbee.can_catch(0.8, Vector3(10, 3.0, 10), pet):
		return "uzak/yüksek frizbi yakalanmamalı"
	return ""


func test_score_and_streak() -> String:
	var g: Node3D = Frisbee.new()
	for i: int in 5:
		g.caught()
	var err: String = "" if g.score == 6 and g.streak == 5 else "5'li seri bonusu: skor %d" % g.score
	g.missed()
	if err.is_empty() and g.streak != 0:
		err = "kaçırınca seri sıfırlanmalı"
	g.free()
	return err


func test_spots() -> String:
	var spots: Array = Hub.load_spots()
	if spots.is_empty():
		return "minigames.json yüklenemedi"
	if Hub.spot_at(Vector3(-285, 0, 50), spots).get("id", "") != "frisbee":
		return "stadyumda frizbi alanı bulunmalı"
	if not Hub.spot_at(Vector3(0, 0, 0), spots).is_empty():
		return "Ortabahçe'de alan olmamalı"
	return ""
