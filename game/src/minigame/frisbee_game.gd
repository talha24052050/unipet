extends Node3D
## Frizbi mini oyunu (YTÜ Stadyumu): 45 sn boyunca sahanın ortasından atılan frizbileri petinle yakala.
## Frizbi yere inmeden altındaki halkaya koşmalısın; her yakalayış +1, 5'li seride +1 bonus.
## Bitince skor sunucuya gider, yıldız tozu ödülü gelir (MinigameRules / index.js minigameReward).

signal finished(score: int)
signal closed

const GAME_ID: String = "frisbee"
const DURATION_S: float = 45.0
const COUNTDOWN_S: float = 3.0
const CATCH_DIST: float = 1.5
const CATCH_HEIGHT: float = 1.8
const PEAK_H: float = 3.0
const ABANDON_DIST: float = 45.0
const BEST_PATH: String = "user://minigames.cfg"
const DISC_COLORS: Array[Color] = [Color(1.0, 0.45, 0.15), Color(0.2, 0.65, 1.0), Color(0.95, 0.85, 0.2), Color(0.9, 0.3, 0.6)]

var center: Vector3 = Vector3.ZERO
var area: float = 24.0
var player: Node3D
var ui_parent: Node

var score: int = 0
var streak: int = 0
var throws: int = 0
var time_left: float = DURATION_S
var state: StringName = &"countdown"  # countdown | play | result

var _countdown: float = COUNTDOWN_S
var _disc: MeshInstance3D
var _marker: MeshInstance3D
var _from: Vector3
var _to: Vector3
var _flight: float = 2.5
var _t: float = 0.0
var _gap: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _ui: Control
var _hud: Label
var _big: Label
var _result: PanelContainer
var _result_label: Label


func _ready() -> void:
	_rng.randomize()
	_build_ui()
	_disc = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.22
	cm.bottom_radius = 0.26
	cm.height = 0.05
	cm.radial_segments = 16
	cm.rings = 1
	_disc.mesh = cm
	add_child(_disc)
	_disc.visible = false
	_marker = MeshInstance3D.new()
	var tm: TorusMesh = TorusMesh.new()
	tm.inner_radius = 0.75
	tm.outer_radius = 0.95
	tm.rings = 24
	tm.ring_segments = 4
	var mm: StandardMaterial3D = StandardMaterial3D.new()
	mm.albedo_color = Color(1, 0.55, 0.15, 0.85)
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tm.material = mm
	_marker.mesh = tm
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_marker)
	_marker.visible = false
	if Services.net != null:
		Services.net.wallet_updated.connect(_on_wallet)


func _process(delta: float) -> void:
	match state:
		&"countdown":
			_countdown -= delta
			_big.text = str(ceili(_countdown)) if _countdown > 0.0 else "Başla!"
			if _countdown <= -0.5:
				_big.visible = false
				state = &"play"
				_next_throw()
		&"play":
			time_left -= delta
			if player != null and flat(player.global_position - center).length() > ABANDON_DIST:
				_finish(true)
				return
			_update_disc(delta)
			if time_left <= 0.0:
				_finish(false)
	_hud.text = "Frizbi   Süre %d   Skor %d" % [maxi(ceili(time_left), 0), score]


static func flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


## Saha içinde, oyuncudan 4–10 m uzakta, yürünebilir bir hedef. Dikey ekranda yanlar dar: hedef kameranın
## baktığı yönde (±40°) seçilir ki halka ve frizbi ekranda görünsün; olmazsa her yön denenir.
func pick_target(from_player: Vector3) -> Vector3:
	var best: Vector3 = center
	var fwd: float = _camera_yaw()
	for i: int in 16:
		var a: float = fwd + _rng.randf_range(-0.7, 0.7) if i < 10 else _rng.randf() * TAU
		var d: float = _rng.randf_range(4.0, 10.0)
		var p: Vector3 = from_player + Vector3(sin(a) * d, 0.0, cos(a) * d)
		if flat(p - center).length() <= area:
			best = p
			break
	return _snap(best)


## Kameranın yatay bakış açısı (atan2(x, z) biçiminde).
func _camera_yaw() -> float:
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return _rng.randf() * TAU
	var f: Vector3 = -cam.global_basis.z
	return atan2(f.x, f.z)


func _snap(p: Vector3) -> Vector3:
	if not is_inside_tree():
		return p
	var map: RID = get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) > 0:
		var q: Vector3 = NavigationServer3D.map_get_closest_point(map, p)
		if q.distance_to(p) < 6.0:
			return q
	return p


func _next_throw() -> void:
	throws += 1
	_from = _snap(center) + Vector3.UP * 1.2
	_to = pick_target(player.global_position if player != null else center)
	# zorluk: süre azaldıkça frizbi hızlanır
	_flight = lerpf(2.7, 1.6, clampf(1.0 - time_left / DURATION_S, 0.0, 1.0))
	_t = 0.0
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = DISC_COLORS[throws % DISC_COLORS.size()]
	(_disc.mesh as CylinderMesh).material = mat
	_disc.visible = true
	_marker.visible = true
	_marker.global_position = _to + Vector3.UP * 0.05


## Frizbinin uçuştaki konumu (0..1): doğrusal yatay + parabol yükseklik.
func disc_pos(u: float) -> Vector3:
	var p: Vector3 = _from.lerp(_to, u)
	p.y += 4.0 * PEAK_H * u * (1.0 - u)
	return p


func _update_disc(delta: float) -> void:
	if _gap > 0.0:
		_gap -= delta
		if _gap <= 0.0 and time_left > 0.0:
			_next_throw()
		return
	if not _disc.visible:
		return
	_t += delta
	var u: float = clampf(_t / _flight, 0.0, 1.0)
	var p: Vector3 = disc_pos(u)
	_disc.global_position = p
	_disc.rotation = Vector3(0.25, _t * 14.0, 0.0)
	var s: float = lerpf(1.4, 0.8, u)
	_marker.scale = Vector3(s, 1.0, s)
	if player != null and can_catch(u, p, player.global_position):
		caught()
	elif u >= 1.0:
		missed()


## Yakalama: frizbi inişteyken (yolun ortasını geçmiş), yatayda yakın ve yeterince alçak.
static func can_catch(u: float, disc: Vector3, pet: Vector3) -> bool:
	return u > 0.45 and flat(disc - pet).length() <= CATCH_DIST and disc.y - pet.y <= CATCH_HEIGHT


func caught() -> void:
	streak += 1
	score += 1
	if streak % 5 == 0:
		score += 1
		_flash("Seri x%d! +1" % streak)
	Sfx.play(&"care_ok")
	var vis: Node = player.get("visual") if player != null else null
	if vis != null:
		vis.call("play_emote", &"emote_jump")
	_end_throw()


func missed() -> void:
	streak = 0
	Sfx.play(&"care_fail")
	_end_throw()


func _end_throw() -> void:
	if _disc != null:
		_disc.visible = false
	if _marker != null:
		_marker.visible = false
	_gap = 0.6


func _flash(text: String) -> void:
	if _big == null:
		return
	_big.text = text
	_big.visible = true
	var tw: Tween = _big.create_tween()
	tw.tween_interval(0.8)
	tw.tween_callback(func() -> void: _big.visible = state == &"countdown")


func _finish(abandoned: bool) -> void:
	state = &"result"
	_disc.visible = false
	_marker.visible = false
	var best: int = save_best(score)
	if abandoned:
		_result_label.text = "Sahadan çıktın, oyun bitti.\nSkor: %d" % score
	else:
		_result_label.text = "Skor: %d   (en iyi: %d)\nÖdül hesaplanıyor..." % [score, best]
		if Services.net != null:
			Services.net.send_minigame_result(GAME_ID, score)
	_result.visible = true
	Sfx.play(&"teleport")
	finished.emit(score)


func _on_wallet(w: Dictionary) -> void:
	if state != &"result" or not w.has("reward"):
		return
	var r: int = int(w["reward"])
	_result_label.text = "Skor: %d   (en iyi: %d)\n%s" % [score, load_best(),
		("+%d yıldız tozu!" % r) if r > 0 else "Bugünkü mini oyun ödülü doldu ya da skor düşük."]
	if r > 0:
		Sfx.play(&"care_ok")


static func load_best() -> int:
	var cfg: ConfigFile = ConfigFile.new()
	return int(cfg.get_value("frisbee", "best", 0)) if cfg.load(BEST_PATH) == OK else 0


static func save_best(s: int) -> int:
	var best: int = maxi(load_best(), s)
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(BEST_PATH)
	cfg.set_value("frisbee", "best", best)
	cfg.save(BEST_PATH)
	return best


func _styled_label(size: int, color: Color, outline: int) -> Label:
	var l: Label = Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.12, 0.3))
	l.add_theme_constant_override("outline_size", outline)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build_ui() -> void:
	_ui = Control.new()
	_ui.name = "FrisbeeUI"
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(ui_parent if ui_parent != null else self).add_child(_ui)
	_hud = _styled_label(34, Color.WHITE, 10)
	_hud.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_hud.offset_left = -260.0
	_hud.offset_right = 260.0
	_hud.offset_top = 310.0
	_ui.add_child(_hud)
	_big = _styled_label(96, Color(1, 0.84, 0.35), 16)
	_big.set_anchors_preset(Control.PRESET_CENTER)
	_big.offset_left = -300.0
	_big.offset_right = 300.0
	_big.offset_top = -200.0
	_big.offset_bottom = -60.0
	_ui.add_child(_big)
	_result = PanelContainer.new()
	_result.add_to_group(&"joystick_blocker")
	_result.set_anchors_preset(Control.PRESET_CENTER)
	_result.offset_left = -300.0
	_result.offset_right = 300.0
	_result.offset_top = -170.0
	_result.offset_bottom = 170.0
	_result.visible = false
	var vb: VBoxContainer = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	_result_label = Label.new()
	_result_label.add_theme_font_size_override("font_size", 32)
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_result_label)
	var row: HBoxContainer = HBoxContainer.new()
	var again: Button = _result_button("Tekrar")
	again.pressed.connect(func() -> void:
		Sfx.play(&"ui_click")
		restart())
	var close_b: Button = _result_button("Kapat")
	close_b.pressed.connect(func() -> void:
		Sfx.play(&"ui_click")
		close())
	row.add_child(again)
	row.add_child(close_b)
	vb.add_child(row)
	_result.add_child(vb)
	_ui.add_child(_result)


func _result_button(text: String) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 96)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 30)
	return b


func restart() -> void:
	score = 0
	streak = 0
	throws = 0
	time_left = DURATION_S
	_countdown = COUNTDOWN_S
	_gap = 0.0
	_result.visible = false
	_big.visible = true
	state = &"countdown"


func close() -> void:
	closed.emit()
	queue_free()


func _exit_tree() -> void:
	if is_instance_valid(_ui):
		_ui.queue_free()
