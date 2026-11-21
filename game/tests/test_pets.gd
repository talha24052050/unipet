extends RefCounted
## İndirilen pet modelleri (tools/assets/fetch_pets.py) import edilebiliyor ve temel animasyonlara sahip mi?

const BASE: String = "res://assets/characters"
const NEEDED: PackedStringArray = ["CharacterArmature|Idle", "CharacterArmature|Walk"]


func test_pet_models_have_core_animations() -> String:
	var found: int = 0
	for id: String in DirAccess.get_directories_at(BASE):
		var path: String = "%s/%s/%s.glb" % [BASE, id, id]
		if not ResourceLoader.exists(path):
			continue
		found += 1
		var root: Node = (load(path) as PackedScene).instantiate()
		var players: Array[Node] = root.find_children("*", "AnimationPlayer", true, false)
		if players.is_empty():
			root.free()
			return "%s: AnimationPlayer yok" % id
		var ap: AnimationPlayer = players[0]
		for a: String in NEEDED:
			if not ap.has_animation(a):
				root.free()
				return "%s: animasyon yok: %s" % [id, a]
		root.free()
	if found < 6:
		return "6 pet bekleniyordu, %d bulundu" % found
	return ""
