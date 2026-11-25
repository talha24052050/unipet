extends Node3D
## Sami — Tarihi Hamam Kültür Merkezi / ARTLAB Yapay Zeka Zirvesi önünde duran 3B Voksel Chibi etkileşimli NPC:
## - Referans 8 açılı piksel-art karakter sayfasından üretilmiş eklemli 3B voksel modeli (sami.glb) yükler.
## - Tarihi Hamam'ın -2.00 m çökük taş avlusunda (ana kemerli giriş kapısı, dev ARTLAB afişi ve ESLAB minibüsü
##   arasındaki karşılamada) durur; oyuncu yaklaşınca ona dönüp el sallar ("Wave") ve konuşma balonu açar.
## - Oyuncu doğrudan Sami'ye dokunduğunda (PetInteraction -> interact()) veya yakındaki "💬 Sami ile Konuş"
##   butonuna bastığında interaktif diyalog kartı açılır.

signal interacted(topic: String)

const MODEL_PATH: String = "res://assets/npcs/sami/sami.glb"
const CHAT_BUBBLE_SCENE: PackedScene = preload("res://scenes/ui/chat_bubble.tscn")

## Tarihi Hamam yerel eksenleri (tarihi_hamam.gd ile birebir aynı): s=19.20, d=3.35, y=-2.00 (tam ARTLAB afişi önü!)
const HAMAM_ORIGIN: Vector2 = Vector2(44.56, -161.98)
const HAMAM_U: Vector2 = Vector2(-0.630079, 0.776531)
const HAMAM_N: Vector2 = Vector2(-0.776519, -0.630094)
const LOCAL_S: float = 19.20
const LOCAL_D: float = 3.35
const SUNK_Y: float = -2.00

const ACTIVE_DIST_M: float = 95.0
const LOOK_AT_DIST_M: float = 10.5
const AUTO_GREET_DIST_M: float = 7.8
const INTERACT_DIST_M: float = 6.2
const AUTO_CLOSE_DIST_M: float = 9.8
const AUTO_GREET_COOLDOWN_S: float = 28.0

@export var player: Node3D
@export var ui: CanvasLayer

var visual: Node3D
var _anim: AnimationPlayer
var _bubble: Node3D
var _default_yaw: float = 0.0
var _greet_cd: float = 0.0
var _return_idle_t: float = 0.0

var _hud_layer: CanvasLayer
var _talk_btn: Button
var _dialog_card: PanelContainer
var _dialog_lbl: Label


static func world_spawn_position() -> Vector3:
	var xz: Vector2 = HAMAM_ORIGIN + HAMAM_U * LOCAL_S + HAMAM_N * LOCAL_D
	return Vector3(xz.x, SUNK_Y, xz.y)


func _ready() -> void:
	if player == null and has_node("../Player"):
		player = get_node("../Player") as Node3D
	if ui == null and has_node("../UI"):
		ui = get_node("../UI") as CanvasLayer
	add_to_group(&"npcs")
	build()


func build() -> void:
	if visual != null:
		return
	var spawn_p: Vector3 = world_spawn_position()
	position = spawn_p
	# Merdiven 1'den çökük avluya inen oyuncuları karşılayacak açı
	var look_dir: Vector2 = (HAMAM_N * 0.88 - HAMAM_U * 0.35).normalized()
	_default_yaw = atan2(look_dir.x, look_dir.y)
	rotation.y = _default_yaw

	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)

	if ResourceLoader.exists(MODEL_PATH):
		var model_inst: Node3D = (load(MODEL_PATH) as PackedScene).instantiate() as Node3D
		model_inst.name = "SamiVoxelModel"
		visual.add_child(model_inst)
		for m: Node in model_inst.find_children("*", "MeshInstance3D", true, false):
			(m as MeshInstance3D).visibility_range_end = ACTIVE_DIST_M
		var aps: Array[Node] = model_inst.find_children("*", "AnimationPlayer", true, false)
		if not aps.is_empty():
			_anim = aps[0] as AnimationPlayer
			for loop_name: String in ["Idle", "Walk"]:
				if _anim.has_animation(loop_name):
					_anim.get_animation(loop_name).loop_mode = Animation.LOOP_LINEAR
			_play_anim("Idle")

	# Oyuncunun içinden geçmemesi için silindir çarpıştırıcı
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "SamiCollision"
	var cs: CollisionShape3D = CollisionShape3D.new()
	var cyl: CylinderShape3D = CylinderShape3D.new()
	cyl.radius = 0.34
	cyl.height = 1.40
	cs.shape = cyl
	cs.position = Vector3(0.0, 0.70, 0.0)
	body.add_child(cs)
	add_child(body)

	# Kafa üstü isim & unvan etiketi
	var name_lbl: Label3D = Label3D.new()
	name_lbl.name = "SamiNameLabel"
	name_lbl.text = "✨ Sami\nSKY LAB • ARTLAB Ekibi"
	name_lbl.font_size = 26
	name_lbl.pixel_size = 0.0046
	name_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_lbl.modulate = Color(1.0, 0.95, 0.74)
	name_lbl.outline_size = 8
	name_lbl.outline_modulate = Color(0.06, 0.10, 0.22, 0.96)
	name_lbl.visibility_range_end = 52.0
	name_lbl.position = Vector3(0.0, 1.64, 0.0)
	add_child(name_lbl)

	# 3B konuşma balonu (kafa üstü unvan etiketinin üstünde, çakışmasız)
	_bubble = CHAT_BUBBLE_SCENE.instantiate() as Node3D
	_bubble.name = "ChatBubble"
	_bubble.position = Vector3(0.0, 2.24, 0.0)
	add_child(_bubble)

	_build_hud()


func footprint() -> Vector2:
	return Vector2(0.36, 1.42)


func is_dialog_open() -> bool:
	return _dialog_card != null and _dialog_card.visible


func _build_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.name = "SamiHudLayer"
	_hud_layer.layer = 1
	add_child(_hud_layer)

	_talk_btn = Button.new()
	_talk_btn.name = "TalkToSamiButton"
	_talk_btn.text = "💬 Sami ile Konuş"
	_talk_btn.visible = false
	_talk_btn.anchor_left = 0.5
	_talk_btn.anchor_top = 1.0
	_talk_btn.anchor_right = 0.5
	_talk_btn.anchor_bottom = 1.0
	_talk_btn.offset_left = -165.0
	_talk_btn.offset_right = 165.0
	_talk_btn.offset_top = -156.0
	_talk_btn.offset_bottom = -88.0
	_talk_btn.add_theme_font_size_override("font_size", 22)
	_talk_btn.pressed.connect(func() -> void: interact())
	_hud_layer.add_child(_talk_btn)

	_dialog_card = PanelContainer.new()
	_dialog_card.name = "SamiDialogCard"
	_dialog_card.visible = false
	_dialog_card.anchor_left = 0.5
	_dialog_card.anchor_top = 0.5
	_dialog_card.anchor_right = 0.5
	_dialog_card.anchor_bottom = 0.5
	_dialog_card.offset_left = -310.0
	_dialog_card.offset_right = 310.0
	_dialog_card.offset_top = -225.0
	_dialog_card.offset_bottom = 78.0
	var st: StyleBoxFlat = StyleBoxFlat.new()
	st.bg_color = Color(0.08, 0.12, 0.22, 0.96)
	st.border_width_left = 3
	st.border_width_top = 3
	st.border_width_right = 3
	st.border_width_bottom = 3
	st.border_color = Color(0.46, 0.72, 1.0, 0.95)
	st.set_corner_radius_all(20)
	st.content_margin_left = 18.0
	st.content_margin_right = 18.0
	st.content_margin_top = 14.0
	st.content_margin_bottom = 14.0
	_dialog_card.add_theme_stylebox_override("panel", st)
	_hud_layer.add_child(_dialog_card)

	var vb: VBoxContainer = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	_dialog_card.add_child(vb)

	var header: HBoxContainer = HBoxContainer.new()
	vb.add_child(header)

	var title: Label = Label.new()
	title.text = "✨ Sami  ·  YTÜ SKY LAB / ARTLAB"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.46))
	header.add_child(title)

	var close_btn: Button = Button.new()
	close_btn.name = "CloseSamiDialogButton"
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(46, 44)
	close_btn.add_theme_font_size_override("font_size", 19)
	close_btn.pressed.connect(func() -> void:
		Sfx.play(&"ui_click")
		close_dialog())
	header.add_child(close_btn)

	_dialog_lbl = Label.new()
	_dialog_lbl.name = "SamiDialogText"
	_dialog_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialog_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dialog_lbl.add_theme_font_size_override("font_size", 18)
	_dialog_lbl.add_theme_color_override("font_color", Color(0.93, 0.96, 1.0))
	vb.add_child(_dialog_lbl)

	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	vb.add_child(btn_row)

	var topics: Array[Dictionary] = [
		{"id": "artlab", "label": "🤖 ARTLAB Zirvesi"},
		{"id": "campus", "label": "☕ ESLAB & Kampüs"},
		{"id": "cheer", "label": "🙌 Selam Çak!"},
	]
	for tp: Dictionary in topics:
		var tb: Button = Button.new()
		tb.name = "Topic_%s" % str(tp["id"])
		tb.text = str(tp["label"])
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.custom_minimum_size = Vector2(0, 50)
		tb.add_theme_font_size_override("font_size", 16)
		var tid: String = str(tp["id"])
		tb.pressed.connect(func() -> void: select_topic(tid))
		btn_row.add_child(tb)


func interact() -> void:
	Sfx.play(&"chat_send")
	if player != null:
		var p3: Vector3 = _node_pos(player)
		var my3: Vector3 = _node_pos(self)
		var d: Vector2 = Vector2(p3.x - my3.x, p3.z - my3.z)
		if d.length() > 0.05:
			rotation.y = atan2(d.x, d.y)
	if _dialog_card != null:
		_dialog_card.visible = true
	if _talk_btn != null:
		_talk_btn.visible = false
	_say(
		"Selam! Ben Sami 👋 Tarihi Hamam'da 2 gün sonra başlayacak SKY LAB ARTLAB Yapay Zeka Zirvesi için hazırlık yapıyoruz. Kampüste nasıl gidiyor?",
		"Selam! ARTLAB Zirvesi'ne hazır mısın? 🤖",
		"Wave",
		1.6
	)
	if has_node("../PetInteraction"):
		var pi: Node = get_node("../PetInteraction")
		if pi.has_method("spawn_hearts"):
			pi.call("spawn_hearts", self, 3)
	interacted.emit("greet")


func select_topic(topic_id: String) -> void:
	Sfx.play(&"ui_click")
	match topic_id:
		"artlab":
			_say(
				"🤖 ARTLAB Yapay Zeka Zirvesi 2 gün sonra tam burada, Tarihi Hamam'da! Derin öğrenme, üretken YZ, otonom sistemler ve sektör panelleri var — üstelik UniPet de ilk kez vitrinde!",
				"2 gün sonra Tarihi Hamam'da buluşuyoruz! 🚀",
				"Talk",
				1.9
			)
		"campus":
			_say(
				"☕ Sol taraftaki gümüş Espressolab (ESLAB) kahve minibüsünden kahveni kapabilirsin! Kampüsü gezmek için de caddedeki duraktan Mavi Ring'e veya denk gelirsen efsane 41AT'ye atla!",
				"ESLAB'dan kahveni al, Ring ile turla! ☕🚌",
				"Talk",
				1.9
			)
		"cheer":
			_say(
				"🐾 Harikasın! Petinle beraber Davutpaşa Kampüsü'ne çok yakışmışsınız. Yıldız tozlarını toplamayı ve kafelerde diğer YTÜ'lülerle tanışmayı unutma!",
				"UniPet kampüste efsane olacak! 🐾✨",
				"Jump",
				1.1
			)
			if has_node("../PetInteraction"):
				var pi: Node = get_node("../PetInteraction")
				if pi.has_method("spawn_hearts"):
					pi.call("spawn_hearts", self, 5)
	interacted.emit(topic_id)


func close_dialog() -> void:
	if _dialog_card != null:
		_dialog_card.visible = false


func _say(card_text: String, bubble_text: String, anim_name: String, dur: float) -> void:
	if _dialog_lbl != null:
		_dialog_lbl.text = card_text
	if _bubble != null and _bubble.has_method("show_message"):
		_bubble.call("show_message", bubble_text)
	_play_anim(anim_name)
	_return_idle_t = dur


func _play_anim(anim_name: String) -> void:
	if _anim != null and _anim.has_animation(anim_name):
		_anim.play(anim_name, 0.15)


static func _node_pos(n: Node3D) -> Vector3:
	return n.global_position if n.is_inside_tree() else n.position


func _is_ui_modal_open() -> bool:
	if ui == null:
		return false
	var cm: Node = ui.get_node_or_null("ChatMenu")
	if cm != null:
		var po: Control = cm.get("_panel_overlay") as Control
		if po != null and po.visible:
			return true
	for ch: Node in ui.get_children():
		if ch is Control and (ch as Control).visible:
			var nm: String = ch.name
			if nm.ends_with("Overlay") or nm.ends_with("Panel") or nm.ends_with("Modal"):
				return true
	return false


func _process(delta: float) -> void:
	_greet_cd = maxf(0.0, _greet_cd - delta)
	if _return_idle_t > 0.0:
		_return_idle_t -= delta
		if _return_idle_t <= 0.0:
			_play_anim("Idle")

	if player == null:
		return

	var p3: Vector3 = _node_pos(player)
	var my3: Vector3 = _node_pos(self)
	var d_xz: Vector2 = Vector2(p3.x - my3.x, p3.z - my3.z)
	var dist: float = d_xz.length()

	var active_near: bool = dist <= ACTIVE_DIST_M
	if visual != null:
		visual.visible = active_near
	if not active_near:
		if _talk_btn != null:
			_talk_btn.visible = false
		return

	# Yakındaki oyuncuya yumuşakça dön; uzaksa merdiven karşılama açısına dön
	var target_yaw: float = atan2(d_xz.x, d_xz.y) if dist <= LOOK_AT_DIST_M and dist > 0.1 else _default_yaw
	rotation.y = lerp_angle(rotation.y, target_yaw, minf(1.0, delta * 5.0))

	# İlk yaklaşmada otomatik el sallama ve karşılama balonu
	if dist <= AUTO_GREET_DIST_M and _greet_cd <= 0.0 and not is_dialog_open():
		_greet_cd = AUTO_GREET_COOLDOWN_S
		if _bubble != null and _bubble.has_method("show_message"):
			_bubble.call("show_message", "Selam! Tarihi Hamam & ARTLAB'a hoş geldin! 👋")
		_play_anim("Wave")
		_return_idle_t = 1.5

	if is_dialog_open() and (dist > AUTO_CLOSE_DIST_M or _is_ui_modal_open()):
		close_dialog()

	if _talk_btn != null:
		var riding: bool = false
		if has_node("../CampusTransit"):
			riding = int(get_node("../CampusTransit").get("riding_bus_idx")) >= 0
		_talk_btn.visible = (dist <= INTERACT_DIST_M) and (not is_dialog_open()) and (not _is_ui_modal_open()) and (not riding)
