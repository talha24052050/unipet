extends RefCounted
## İndirilen pet modelleri (tools/assets/fetch_pets.py) import edilebiliyor ve temel animasyonlara sahip mi?

const BASE: String = "res://assets/characters"
const NEEDED: PackedStringArray = ["CharacterArmature|Idle", "CharacterArmature|Walk"]


func test_pet_models_have_core_animations() -> String:
	# Animasyon adları modele göre değişir (Quaternius: "CharacterArmature|Idle", Kutbi: "Idle"): tanımdaki eşlemeyle bak.
	var reg: RefCounted = (load("res://src/characters/character_registry.gd") as GDScript).new()
	reg.call("load_from_dir", "res://data/characters")
	var found: int = 0
	for def: CharacterDef in reg.get("_defs").values():
		if not ResourceLoader.exists(def.model_path):
			return "%s: model yok" % def.id
		found += 1
		var root: Node = (load(def.model_path) as PackedScene).instantiate()
		var players: Array[Node] = root.find_children("*", "AnimationPlayer", true, false)
		if players.is_empty():
			root.free()
			return "%s: AnimationPlayer yok" % def.id
		var ap: AnimationPlayer = players[0]
		for logical: String in ["idle", "walk"]:
			if not ap.has_animation(def.anim_name(logical)):
				root.free()
				return "%s: animasyon yok: %s" % [def.id, logical]
		root.free()
	if found < 7:
		return "7 pet bekleniyordu (6 + efsanevi Kutbi), %d bulundu" % found
	return ""


const CharacterRegistry := preload("res://src/characters/character_registry.gd")


func test_registry_loads_all_pets() -> String:
	var reg: CharacterRegistry = CharacterRegistry.new()
	reg.load_from_dir("res://data/characters")
	if reg.count() != 7 or reg.selectable().size() != 6:
		return "7 tanım (6 seçilebilir + kilitli Kutbi) bekleniyordu: %d / %d" % [reg.count(), reg.selectable().size()]
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


func test_legendary_availability() -> String:
	var reg: RefCounted = (load("res://src/characters/character_registry.gd") as GDScript).new()
	reg.call("load_from_dir", "res://data/characters")
	var ids := func(list: Array) -> Array: return list.map(func(d: CharacterDef) -> String: return str(d.id))
	if ids.call(reg.call("available", PackedStringArray(), false)).has("kutbi"):
		return "kilitliyken Kutbi görünmemeli"
	if not ids.call(reg.call("available", PackedStringArray(["kutbi"]), false)).has("kutbi"):
		return "kilidi açıkken Kutbi görünmeli"
	if not ids.call(reg.call("available", PackedStringArray(), true)).has("kutbi"):
		return "geliştirici modunda Kutbi görünmeli"
	return ""
