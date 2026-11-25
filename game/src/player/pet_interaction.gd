extends Node
## Petle etkileşim (dokunarak):
## - Kendi petine dokun → sevilir: kalpler uçar, sevinç hareketi yapar (diğerleri hareketi görür).
## - Başka oyuncunun petine dokun → petin ona döner, el sallar, "Selam!" der; onun üstünde kalpler.
## Dokunuş ekran uzayında seçilir (uzak oyuncuların çarpışma şekli yok): petin gövde noktasına en yakın, yarıçap içinde.

const PICK_RADIUS_PX: float = 90.0
const PICK_HEIGHT: float = 0.5
const PET_COOLDOWN_S: float = 0.9
const GREET_COOLDOWN_S: float = 4.0
const GREET_MAX_DIST: float = 25.0
const HAPPY_EMOTES: Array[StringName] = [&"emote_jump", &"emote_yes", &"emote_dance"]
const HEART_COLOR: Color = Color(1.0, 0.36, 0.5)

signal pet_petted
signal player_greeted(player_id: String)
signal profile_requested(player_id: String, display_name: String, pet_id: String)

@export var player: Node3D
## Uzak oyuncuların ebeveyni (NetworkSync); çocukları RemotePlayer.
@export var remotes: Node

var _pet_cd: float = 0.0
var _greet_cd: float = 0.0
var _happy_i: int = 0
static var _heart_tex: Texture2D


func _process(delta: float) -> void:
	_pet_cd = maxf(_pet_cd - delta, 0.0)
	_greet_cd = maxf(_greet_cd - delta, 0.0)


## Dokunuşu bir pete denk geldiyse işler ve true döner (o zaman yürüme hedefi konmaz).
func try_tap(screen_pos: Vector2, camera: Camera3D) -> bool:
	if camera == null:
		return false
	var cands: Array[Node3D] = _candidates()
	var pts: Array[Vector2] = []
	for n: Node3D in cands:
		var w_body: Vector3 = n.global_position + Vector3.UP * PICK_HEIGHT
		var p_body: Vector2 = Vector2.INF if camera.is_position_behind(w_body) else camera.unproject_position(w_body)
		# Başka oyuncuların veya kampüs NPC'lerinin kafa üstü yazısına dokunulduğunda da kolayca etkileşim sağla
		if n != player and not n.is_in_group(&"cats"):
			var w_lbl: Vector3 = n.global_position + Vector3.UP * (1.55 if n.is_in_group(&"npcs") else 1.32)
			var p_lbl: Vector2 = Vector2.INF if camera.is_position_behind(w_lbl) else camera.unproject_position(w_lbl)
			if p_lbl != Vector2.INF and (p_body == Vector2.INF or p_lbl.distance_to(screen_pos) < p_body.distance_to(screen_pos)):
				p_body = p_lbl
		pts.append(p_body)
	var idx: int = nearest(screen_pos, pts, PICK_RADIUS_PX)
	if idx < 0:
		return false
	var best: Node3D = cands[idx]
	if best == player:
		pet_own()
	elif best.is_in_group(&"cats"):
		best.call("pet")
		spawn_hearts(best, 3)
	elif best.is_in_group(&"npcs"):
		if player != null:
			var to_npc: Vector3 = best.global_position - player.global_position
			if Vector2(to_npc.x, to_npc.z).length() > 0.1:
				player.rotation.y = atan2(to_npc.x, to_npc.z)
			var vis_p: Node = player.get("visual")
			if vis_p != null:
				vis_p.call("play_emote", &"emote_wave")
		best.call("interact")
	else:
		var pid: String = str(best.get("player_id"))
		var dname: String = str(best.get("display_name"))
		var c_id: String = str(best.get("character_id"))
		if dname.is_empty():
			dname = pid.substr(0, 6)
		profile_requested.emit(pid, dname, c_id)
		greet(best)
	return true


## Ekran noktalarından dokunuşa en yakın olanın sırası (yarıçap dışındaysa -1).
static func nearest(screen_pos: Vector2, points: Array[Vector2], radius: float) -> int:
	var best: int = -1
	var best_d: float = radius
	for i: int in points.size():
		if points[i] == Vector2.INF:
			continue
		var d: float = points[i].distance_to(screen_pos)
		if d < best_d:
			best_d = d
			best = i
	return best


func _candidates() -> Array[Node3D]:
	var out: Array[Node3D] = []
	if player != null:
		out.append(player)
	if remotes != null:
		for c: Node in remotes.get_children():
			if c is Node3D and c.has_method("push_state") and (c as Node3D).visible:
				out.append(c)
	if is_inside_tree():
		for c: Node in get_tree().get_nodes_in_group(&"cats"):
			if (c as Node3D).visible and player != null and (c as Node3D).global_position.distance_to(player.global_position) < GREET_MAX_DIST:
				out.append(c)
		for npc: Node in get_tree().get_nodes_in_group(&"npcs"):
			if (npc as Node3D).visible and player != null and (npc as Node3D).global_position.distance_to(player.global_position) < GREET_MAX_DIST:
				out.append(npc)
	return out


## Kendi petini sev.
func pet_own() -> void:
	if _pet_cd > 0.0 or player == null:
		return
	_pet_cd = PET_COOLDOWN_S
	var vis: Node = player.get("visual")
	if vis != null:
		vis.call("play_emote", HAPPY_EMOTES[_happy_i % HAPPY_EMOTES.size()])
	_happy_i += 1
	Sfx.play(&"emote")
	spawn_hearts(player, 5)
	pet_petted.emit()


## Başka bir oyuncuyu selamla: ona dön, el salla, "Selam!" de.
func greet(other: Node3D) -> void:
	if _greet_cd > 0.0 or player == null:
		return
	var to: Vector3 = other.global_position - player.global_position
	if Vector2(to.x, to.z).length() > GREET_MAX_DIST:
		return
	_greet_cd = GREET_COOLDOWN_S
	if Vector2(to.x, to.z).length() > 0.1:
		player.rotation.y = atan2(to.x, to.z)
	var vis: Node = player.get("visual")
	if vis != null:
		vis.call("play_emote", &"emote_wave")
	if Services.net != null:
		Services.net.send_chat(ChatMessage.preset("selam"))
	Sfx.play(&"chat_send")
	spawn_hearts(other, 3)
	player_greeted.emit(str(other.get("player_id")))


## Petin üstünden yükselip kaybolan kalpler.
func spawn_hearts(target: Node3D, count: int) -> void:
	if not is_inside_tree():
		return
	var top: float = 1.0
	var vis: Node = target.get("visual")
	if vis != null and vis.has_method("footprint"):
		top = maxf((vis.call("footprint") as Vector2).y, 0.4)
	for i: int in count:
		var s: Sprite3D = Sprite3D.new()
		s.texture = heart_texture()
		s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		s.pixel_size = 0.008
		s.modulate = HEART_COLOR
		s.no_depth_test = true
		s.shaded = false
		var host: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
		if host == null:
			s.free()
			return
		host.add_child(s)
		var start: Vector3 = target.global_position + Vector3(randf_range(-0.3, 0.3), top * 0.8, randf_range(-0.3, 0.3))
		s.global_position = start
		s.scale = Vector3.ONE * 0.3
		var tw: Tween = s.create_tween().set_parallel(true)
		var delay: float = i * 0.12
		tw.tween_property(s, "scale", Vector3.ONE * randf_range(0.8, 1.1), 0.25).set_delay(delay).set_trans(Tween.TRANS_BACK)
		tw.tween_property(s, "global_position", start + Vector3(randf_range(-0.4, 0.4), 1.0, 0.0), 1.1).set_delay(delay).set_ease(Tween.EASE_OUT)
		tw.tween_property(s, "modulate:a", 0.0, 0.5).set_delay(delay + 0.6)
		tw.chain().tween_callback(s.queue_free)


## 64 px kalp dokusu (font/emoji gerektirmez; Android'de de aynı görünür).
static func heart_texture() -> Texture2D:
	if _heart_tex != null:
		return _heart_tex
	var n: int = 64
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y: int in n:
		for x: int in n:
			var u: float = (x - n * 0.5 + 0.5) / (n * 0.42)
			var v: float = -(y - n * 0.47) / (n * 0.42)
			var f: float = pow(u * u + v * v - 1.0, 3.0) - u * u * v * v * v
			var a: float = clampf(-f * 18.0, 0.0, 1.0)
			# beyaz kenar + iç
			var col: Color = Color(1, 1, 1, a)
			img.set_pixel(x, y, col)
	_heart_tex = ImageTexture.create_from_image(img)
	return _heart_tex
