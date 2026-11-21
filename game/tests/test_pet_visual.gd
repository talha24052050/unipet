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
