extends RefCounted

const SamiNpc := preload("res://src/world/sami_npc.gd")


func test_sami_voxel_glb_has_limbs_and_animations() -> String:
	if not ResourceLoader.exists(SamiNpc.MODEL_PATH):
		return "sami.glb bulunamadı: %s" % SamiNpc.MODEL_PATH
	var inst: Node3D = (load(SamiNpc.MODEL_PATH) as PackedScene).instantiate() as Node3D
	var meshes: Array[Node] = inst.find_children("*", "MeshInstance3D", true, false)
	if meshes.size() < 6:
		inst.free()
		return "Sami modelinde en az 6 eklemli voksel parçası olmalıydı: %d" % meshes.size()
	var aps: Array[Node] = inst.find_children("*", "AnimationPlayer", true, false)
	if aps.is_empty():
		inst.free()
		return "Sami modelinde AnimationPlayer yok"
	var ap: AnimationPlayer = aps[0] as AnimationPlayer
	for anim_name: String in ["Idle", "Wave", "Talk", "Walk", "Jump"]:
		if not ap.has_animation(anim_name):
			inst.free()
			return "Sami animasyonu eksik: %s" % anim_name
	inst.free()
	return ""


func test_sami_npc_spawns_at_hamam_and_interacts() -> String:
	var player: Node3D = Node3D.new()
	var sp: Vector3 = SamiNpc.world_spawn_position()
	if absf(sp.y - (-2.0)) > 0.05:
		player.free()
		return "Sami Tarihi Hamam çökük avlu kotunda (-2.0 m) olmalıydı: %s" % sp
	player.position = sp + Vector3(1.5, 0.0, 1.5)

	var sami: Node3D = SamiNpc.new()
	sami.set("player", player)
	(Engine.get_main_loop() as SceneTree).root.add_child(player)
	(Engine.get_main_loop() as SceneTree).root.add_child(sami)
	if not sami.is_node_ready():
		sami.call("_ready")

	var err: String = ""
	if not sami.is_in_group(&"npcs"):
		err = "Sami 'npcs' grubunda değil"
	if err.is_empty():
		sami.call("_process", 0.2)
		var btn: Button = sami.get("_talk_btn") as Button
		if btn == null or not btn.visible:
			err = "Yakındaki oyuncuya '💬 Sami ile Konuş' butonu görünmedi"
	if err.is_empty():
		sami.call("interact")
		if not bool(sami.call("is_dialog_open")):
			err = "interact() sonrası Sami diyalog kartı açılmadı"
	if err.is_empty():
		sami.call("select_topic", "artlab")
		var lbl: Label = sami.get("_dialog_lbl") as Label
		if lbl == null or not lbl.text.contains("ARTLAB"):
			err = "ARTLAB konusu diyalog metnini güncellemedi"
		sami.call("close_dialog")
		if bool(sami.call("is_dialog_open")):
			err = "close_dialog() kartı kapatmadı"

	sami.free()
	player.free()
	return err
