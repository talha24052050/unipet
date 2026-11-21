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


const CharacterRegistry := preload("res://src/characters/character_registry.gd")


func test_registry_loads_all_pets() -> String:
	var reg: CharacterRegistry = CharacterRegistry.new()
	reg.load_from_dir("res://data/characters")
	if reg.count() != 6:
		return "6 pet tanımı bekleniyordu, %d yüklendi" % reg.count()
	return ""


func test_defs_match_models() -> String:
	var reg: CharacterRegistry = CharacterRegistry.new()
	reg.load_from_dir("res://data/characters")
	for def: CharacterDef in reg.selectable():
		var root: Node = (load(def.model_path) as PackedScene).instantiate()
		var ap: AnimationPlayer = root.find_children("*", "AnimationPlayer", true, false)[0]
		var sk: Skeleton3D = root.find_children("*", "Skeleton3D", true, false)[0]
		var err: String = ""
		for logical: String in def.animation_map:
			if not ap.has_animation(def.anim_name(logical)):
				err = "%s: '%s' -> modelde yok: %s" % [def.id, logical, def.anim_name(logical)]
		for slot: String in def.accessory_bones:
			if sk.find_bone(str(def.accessory_bones[slot])) == -1:
				err = "%s: slot '%s' kemiği yok: %s" % [def.id, slot, def.accessory_bones[slot]]
		if def.model_scale <= 0.0 or def.model_scale > 1.0:
			err = "%s: ölçek mantıksız: %s" % [def.id, def.model_scale]
		root.free()
		if not err.is_empty():
			return err
	return ""
