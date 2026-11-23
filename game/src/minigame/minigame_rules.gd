extends RefCounted
## Mini oyun ödül kuralları — server/nakama/modules/index.js MINIGAMES ile AYNI.

const GAMES: Dictionary = {"frisbee": {"max_score": 40, "per_dust": 3}}
const MAX_REWARD: int = 5
const DAILY_CAP: int = 15


## Skor için verilecek yıldız tozu (already = bugün mini oyunlardan alınan).
static func reward(game: String, score: int, already: int) -> int:
	var g: Dictionary = GAMES.get(game, {})
	if g.is_empty() or score < 0 or score > int(g["max_score"]):
		return 0
	var r: int = mini(score / int(g["per_dust"]), MAX_REWARD)
	return maxi(0, mini(r, DAILY_CAP - already))
