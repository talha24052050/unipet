extends RefCounted

const PetVisual := preload("res://src/characters/pet_visual.gd")


func _make(id: StringName) -> Node3D:
	var v: Node3D = PetVisual.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(v)
	v.call("set_character", load("res://data/characters/%s.tres" % id))
	return v


func test_locomotion_selection() -> String:
	if PetVisual.locomotion_for(0.0) != &"idle":
		return "durunca idle değil"
	if PetVisual.locomotion_for(Config.PLAYER_WALK_SPEED) != &"walk":
		return "yürüme hızında walk değil"
	if PetVisual.locomotion_for(Config.PLAYER_RUN_SPEED) != &"run":
		return "koşu hızında run değil"
	return ""


func test_visual_plays_logical_animations() -> String:
	var v: Node3D = _make(&"mushnub")
	var err: String = ""
	if v.call("current_logical") != &"idle":
		err = "başlangıç idle değil: %s" % v.call("current_logical")
	v.call("set_locomotion", Config.PLAYER_WALK_SPEED)
	if err.is_empty() and v.call("current_logical") != &"walk":
		err = "yürürken walk değil"
	if err.is_empty() and not v.call("play_emote", &"emote_wave"):
		err = "emote oynamadı"
	v.call("set_locomotion", 0.0)
	if err.is_empty() and v.call("current_logical") != &"emote_wave":
		err = "dururken emote kesildi"
	v.call("set_locomotion", Config.PLAYER_WALK_SPEED)
	if err.is_empty() and v.call("current_logical") != &"walk":
		err = "hareket emote'u kesmedi"
	v.free()
	return err


func test_footprint_reasonable() -> String:
	for id: StringName in [&"shark", &"birb", &"mushnub", &"yeti", &"ninja", &"chicken"]:
		var v: Node3D = _make(id)
		var fp: Vector2 = v.call("footprint")
		v.free()
		if fp.x < 0.2 or fp.x > 0.6 or fp.y < 0.8 or fp.y > 1.5:
			return "%s: çarpışma ölçüsü mantıksız (yarıçap, boy) = %s" % [id, fp]
	return ""


const AccessoryRegistry := preload("res://src/characters/accessory_registry.gd")


func test_accessories_load_and_equip_on_all_pets() -> String:
	var reg: AccessoryRegistry = AccessoryRegistry.new()
	reg.load_from_dir("res://data/accessories")
	if reg.count() < 4:
		return "en az 4 aksesuar bekleniyordu, %d" % reg.count()
	for id: StringName in [&"shark", &"birb", &"mushnub", &"yeti", &"ninja", &"chicken"]:
		var v: Node3D = _make(id)
		for acc: AccessoryDef in reg.all():
			if not v.call("equip", acc):
				v.free()
				return "%s: %s takılamadı" % [id, acc.id]
		var ids: Dictionary = v.call("equipped_ids")
		v.free()
		if ids.size() != 4:
			return "%s: takılı aksesuar sayısı %d" % [id, ids.size()]
	return ""


func test_accessories_survive_pet_change() -> String:
	var reg: AccessoryRegistry = AccessoryRegistry.new()
	reg.load_from_dir("res://data/accessories")
	var v: Node3D = _make(&"yeti")
	v.call("equip", reg.get_def(&"hat_cap"))
	v.call("set_character", load("res://data/characters/chicken.tres"))
	var ids: Dictionary = v.call("equipped_ids")
	v.call("unequip", &"head")
	var after: Dictionary = v.call("equipped_ids")
	v.free()
	if ids.get(&"head") != &"hat_cap":
		return "pet değişince kep düştü: %s" % ids
	if not after.is_empty():
		return "unequip çalışmadı: %s" % after
	return ""


func test_hat_sits_on_head_top() -> String:
	# Kep, petin boyunun üst kısmında olmalı (havada ya da gömülü değil).
	var reg: AccessoryRegistry = AccessoryRegistry.new()
	reg.load_from_dir("res://data/accessories")
	for id: StringName in [&"birb", &"mushnub", &"yeti", &"ninja", &"chicken"]:
		var v: Node3D = _make(id)
		var def: CharacterDef = v.get("definition")
		var anchor: Transform3D = v.call("accessory_anchor", &"head")
		var height_m: float = (v.call("footprint") as Vector2).y
		var y_m: float = anchor.origin.y * def.model_scale
		v.free()
		if y_m < height_m * 0.7 or y_m > height_m * 1.02:
			return "%s: kep yüksekliği %.2f m, pet boyu %.2f m" % [id, y_m, height_m]
	return ""


func test_idle_fidget() -> String:
	var v: Node3D = _make(&"yeti")
	v.set("_next_fidget", 1.0)
	var none: StringName = v.call("tick_fidget", 0.5)
	var pick: StringName = v.call("tick_fidget", 0.6)
	var now: StringName = v.call("current_logical")
	v.call("set_locomotion", Config.PLAYER_WALK_SPEED)
	var walking: StringName = v.call("tick_fidget", 100.0)
	v.set("fidget_enabled", false)
	v.call("set_locomotion", 0.0)
	var off: StringName = v.call("tick_fidget", 100.0)
	v.free()
	if none != &"" or pick == &"" or now != pick:
		return "boşta kalınca emote oynamalı: %s %s %s" % [none, pick, now]
	if walking != &"" or off != &"":
		return "yürürken ya da kapalıyken oynamamalı"
	return ""
