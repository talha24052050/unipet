extends Node3D
## Koşu yarışı (YTÜ Stadyumu pisti, yarım tur ~214 m): pistte kapılar, başlangıçta "Yarışa katıl".
## Akış sunucuda (RaceRules / index.js): lobi 10 sn → 3-2-1 → koşu → sonuç. Odadaki herkes lobiyi görür, katılabilir.
## Kontrol noktasını yerelde fark eder, sunucuya bildirir; sunucu konum + süreyle doğrular.

const RaceRules := preload("res://src/minigame/race_rules.gd")
const JOIN_SHOW_RADIUS: float = 20.0
const LOCAL_CP_RADIUS: float = 7.0
const RESEND_S: float = 1.0
const GATE_IDLE: Color = Color(0.95, 0.95, 0.95)
const GATE_NEXT: Color = Color(1.0, 0.8, 0.25)
const GATE_DONE: Color = Color(0.35, 0.8, 0.4)

@export var player: Node3D
@export var controller: Node
@export var ui: CanvasLayer

var cps: Array = []
var width: float = 7.5
var view: Dictionary = {"phase": "idle", "racers": []}
var joined: bool = false
var my_cp: int = 0
var finished: bool = false
var _gates: Array[Node3D] = []
var _gate_mats: Array[StandardMaterial3D] = []
var _sent_cp: int = 0
var _sent_at: float = -10.0
var _start_in_s: float = 0.0
var _clock: float = 0.0
var _run_t: float = 0.0
var _button: Button
var _hud: Label
var _big: Label
var _result: PanelContainer
var _result_label: Label
var _reward_text: String = ""
## Son görünümün geldiği an (lobi geri sayımını yerelde akıtmak için).
var _view_at: float = 0.0


func _ready() -> void:
	cps = RaceRules.load_cps()
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(RaceRules.DATA))
	if d is Dictionary:
		width = float(d.get("width", 7.5))
	for i: int in cps.size():
		_build_gate(i)
	_build_ui()
	if Services.net != null:
		Services.net.race_updated.connect(_on_race)
		Services.net.wallet_updated.connect(_on_wallet)
	_refresh_gates()


func _my_id() -> String:
	return Services.net.local_player_id() if Services.net != null else "local"


func _on_race(v: Dictionary) -> void:
	if v.has("error"):
		_flash(str(v["error"]), 1.5)
		Sfx.play(&"care_fail")
		return
	var prev: String = str(view.get("phase", "idle"))
	view = v
	_view_at = _clock
	_start_in_s = float(v.get("start_in", 0)) / 1000.0
	var me: Dictionary = mine()
	var was_joined: bool = joined
	joined = not me.is_empty()
	if joined:
		my_cp = int(me["cp"])
		finished = int(me["place"]) > 0
	var phase: String = str(v["phase"])
	if phase == "lobby" and joined and not was_joined:
		Sfx.play(&"chat_send")
		_walk_to_start()
	if phase == "running" and prev != "running":
		_run_t = -_start_in_s
		_reward_text = ""
		_result.visible = false
	if phase == "done" and prev != "done" and was_joined:
		_show_results()
	if phase == "idle":
		joined = false
		finished = false
		my_cp = 0
		_sent_cp = 0
		if player != null:
			player.set("frozen", false)
	_refresh_gates()


func mine() -> Dictionary:
	for r: Dictionary in view.get("racers", []):
		if str(r["id"]) == _my_id():
			return r
	return {}


## Başlangıçta koşucu sırasına göre yan yana yer (pist genişliği boyunca).
func start_slot(index: int) -> Vector3:
	var c: Array = cps[0]
	var yaw: float = atan2(float(cps[1][0]) - float(c[0]), float(cps[1][1]) - float(c[1]))
	var side: Vector3 = Vector3(cos(yaw), 0.0, -sin(yaw))
	var lane: float = (float(index % 4) - 1.5) * (width / 4.0)
	var back: float = -2.0 - float(index / 4) * 1.5
	return Vector3(float(c[0]), 0.0, float(c[1])) + side * lane + Vector3(sin(yaw), 0.0, cos(yaw)) * back


func _walk_to_start() -> void:
	if controller == null:
		return
	var idx: int = 0
	for i: int in view["racers"].size():
		if str(view["racers"][i]["id"]) == _my_id():
			idx = i
	controller.call("set_destination", start_slot(idx))


func _process(delta: float) -> void:
	_clock += delta
	var phase: String = str(view.get("phase", "idle"))
	var near: bool = player != null and cps.size() > 0 and \
		Vector2(player.global_position.x - float(cps[0][0]), player.global_position.z - float(cps[0][1])).length() <= JOIN_SHOW_RADIUS
	_button.visible = (phase == "idle" or phase == "lobby") and (near or joined)
	_button.text = "Yarıştan ayrıl" if joined else "Koşu yarışına katıl"
	match phase:
		"lobby":
			var left: float = maxf(float(view.get("lobby_in", 0)) / 1000.0 - (_clock - _view_at), 0.0)
			_hud.visible = true
			_hud.text = "Yarış %d sn sonra · %d koşucu" % [ceili(left), view["racers"].size()]
		"running":
			_run_t += delta
			_hud.visible = joined
			if joined and _run_t < 0.0:
				player.set("frozen", true)
				_hud.text = "Hazır ol!"
				_big.visible = true
				_big.text = str(ceili(-_run_t))
			elif joined:
				if bool(player.get("frozen")):
					player.set("frozen", false)
					_flash("Koş!", 0.8)
					Sfx.play(&"teleport")
				if not finished:
					_check_cp()
				_hud.text = "Kapı %d/%d   %s   Sıra %d/%d" % [my_cp, cps.size() - 1, fmt_time(maxf(_run_t, 0.0)),
					my_rank(), view["racers"].size()]
		_:
			_hud.visible = false


func _check_cp() -> void:
	var i: int = my_cp + 1
	if i >= cps.size() or player == null:
		return
	var p: Vector3 = player.global_position
	if Vector2(p.x - float(cps[i][0]), p.z - float(cps[i][1])).length() > LOCAL_CP_RADIUS:
		return
	if _sent_cp == i and _clock - _sent_at < RESEND_S:
		return
	_sent_cp = i
	_sent_at = _clock
	if Services.net != null:
		Services.net.send_race("cp", i)
	Sfx.play(&"ui_click")


func my_rank() -> int:
	var s: Array = RaceRules.standings(view.get("racers", []))
	for k: int in s.size():
		if str(s[k]["id"]) == _my_id():
			return k + 1
	return 0


static func fmt_time(sec: float) -> String:
	return "%02d:%04.1f" % [int(sec) / 60, fmod(sec, 60.0)]


func toggle_join() -> void:
	Sfx.play(&"ui_click")
	if Services.net != null:
		Services.net.send_race("leave" if joined else "join")


func _on_wallet(w: Dictionary) -> void:
	# ödül, bitiriş görünümünden önce gelebilir (sunucusuz modda hep önce): yarıştayken gelen ödülü sakla
	if not joined or str(view.get("phase", "")) != "running" or not w.has("reward"):
		return
	var r: int = int(w["reward"])
	_reward_text = ("+%d yıldız tozu!" % r) if r > 0 else "Bugünkü mini oyun ödülü doldu."
	if _result.visible:
		_show_results()


func _show_results() -> void:
	var lines: PackedStringArray = ["Yarış bitti!"]
	var k: int = 0
	for r: Dictionary in RaceRules.standings(view.get("racers", [])):
		k += 1
		var who: String = "Sen" if str(r["id"]) == _my_id() else (str(r["name"]) if not str(r["name"]).is_empty() else "Koşucu")
		var t: String = fmt_time(float(r["time"]) / 1000.0) if int(r["place"]) > 0 else "bitiremedi"
		lines.append("%d. %s  %s" % [k, who, t])
	if not _reward_text.is_empty():
		lines.append(_reward_text)
	_result_label.text = "\n".join(lines)
	_result.visible = true
	if my_rank() == 1 and int(mine().get("place", 0)) == 1:
		var vis: Node = player.get("visual") if player != null else null
		if vis != null:
			vis.call("play_emote", &"emote_dance")
		Sfx.play(&"care_ok")


# ---------------- görseller ----------------
func _build_gate(i: int) -> void:
	var c: Array = cps[i]
	var j: int = mini(i + 1, cps.size() - 1)
	var k: int = maxi(i - 1, 0)
	var yaw: float = atan2(float(cps[j][0]) - float(cps[k][0]), float(cps[j][1]) - float(cps[k][1]))
	var g: Node3D = Node3D.new()
	add_child(g)
	var cx: float = float(c[0])
	var cz: float = float(c[1])
	g.position = Vector3(cx, TerrainHeight.active_height(cx, cz), cz)
	g.rotation.y = yaw
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = GATE_IDLE
	mat.emission_enabled = true
	mat.emission = GATE_IDLE
	mat.emission_energy_multiplier = 0.0
	var half: float = width * 0.5 + 0.6
	for side: float in [-1.0, 1.0]:
		var post: MeshInstance3D = MeshInstance3D.new()
		var cm: CylinderMesh = CylinderMesh.new()
		cm.top_radius = 0.12
		cm.bottom_radius = 0.12
		cm.height = 3.2
		cm.radial_segments = 8
		cm.rings = 1
		cm.material = mat
		post.mesh = cm
		post.position = Vector3(side * half, 1.6, 0.0)
		g.add_child(post)
	var bar: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(half * 2.0 + 0.3, 0.5, 0.12)
	bm.material = mat
	bar.mesh = bm
	bar.position = Vector3(0.0, 3.2, 0.0)
	g.add_child(bar)
	var label: Label3D = Label3D.new()
	label.text = "BAŞLANGIÇ" if i == 0 else ("BİTİŞ" if i == cps.size() - 1 else str(i))
	if i == 0:
		label.text = "KOŞU YARIŞI\nBAŞLANGIÇ"
	label.font_size = 64
	label.pixel_size = 0.01
	label.outline_size = 16
	label.modulate = Color(0.1, 0.12, 0.3)
	label.outline_modulate = Color.WHITE
	label.position = Vector3(0.0, 3.9 if i == 0 else 3.2, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	g.add_child(label)
	for n: Node in g.get_children():
		if n is GeometryInstance3D:
			(n as GeometryInstance3D).visibility_range_end = 160.0
	_gates.append(g)
	_gate_mats.append(mat)


func _refresh_gates() -> void:
	var running: bool = str(view.get("phase", "idle")) == "running" and joined
	for i: int in _gate_mats.size():
		var c: Color = GATE_IDLE
		if running:
			if i <= my_cp and i > 0:
				c = GATE_DONE
			elif i == my_cp + 1:
				c = GATE_NEXT
		elif i == 0 or i == cps.size() - 1:
			c = GATE_NEXT
		_gate_mats[i].albedo_color = c
		_gate_mats[i].emission = c
		_gate_mats[i].emission_energy_multiplier = 0.8 if c == GATE_NEXT else 0.0


func _flash(text: String, dur: float) -> void:
	_big.text = text
	_big.visible = true
	var tw: Tween = _big.create_tween()
	tw.tween_interval(dur)
	tw.tween_callback(func() -> void: _big.visible = false)


func _label(size: int, color: Color, outline: int) -> Label:
	var l: Label = Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.12, 0.3))
	l.add_theme_constant_override("outline_size", outline)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build_ui() -> void:
	var root: Control = Control.new()
	root.name = "RaceUI"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_button = Button.new()
	_button.name = "RaceButton"
	_button.add_theme_font_size_override("font_size", 30)
	_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_button.offset_left = -200.0
	_button.offset_right = 200.0
	_button.offset_top = -490.0
	_button.offset_bottom = -394.0
	_button.visible = false
	_button.add_to_group(&"joystick_blocker")
	_button.pressed.connect(toggle_join)
	root.add_child(_button)
	_hud = _label(34, Color.WHITE, 10)
	_hud.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_hud.offset_left = -330.0
	_hud.offset_right = 330.0
	_hud.offset_top = 310.0
	_hud.visible = false
	root.add_child(_hud)
	_big = _label(110, Color(1, 0.84, 0.35), 18)
	_big.set_anchors_preset(Control.PRESET_CENTER)
	_big.offset_left = -330.0
	_big.offset_right = 330.0
	_big.offset_top = -220.0
	_big.offset_bottom = -60.0
	_big.visible = false
	root.add_child(_big)
	_result = PanelContainer.new()
	_result.add_to_group(&"joystick_blocker")
	_result.set_anchors_preset(Control.PRESET_CENTER)
	_result.offset_left = -300.0
	_result.offset_right = 300.0
	_result.offset_top = -220.0
	_result.offset_bottom = 220.0
	_result.visible = false
	var vb: VBoxContainer = VBoxContainer.new()
	_result_label = Label.new()
	_result_label.add_theme_font_size_override("font_size", 30)
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(_result_label)
	var ok: Button = Button.new()
	ok.text = "Tamam"
	ok.custom_minimum_size = Vector2(0, 96)
	ok.add_theme_font_size_override("font_size", 30)
	ok.pressed.connect(func() -> void:
		Sfx.play(&"ui_click")
		_result.visible = false)
	vb.add_child(ok)
	_result.add_child(vb)
	root.add_child(_result)
	if ui != null:
		ui.add_child.call_deferred(root)
	else:
		add_child(root)
