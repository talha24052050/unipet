extends Node3D
## Mini oyun alanları (data/minigames.json): sahada uzaktan görünen tabela; oyuncu yaklaşınca "Frizbi oyna" butonu.

const DATA: String = "res://data/minigames.json"
const FrisbeeGame := preload("res://src/minigame/frisbee_game.gd")
const CHECK_S: float = 0.3

@export var player: Node3D
@export var ui: CanvasLayer

var spots: Array = []
var game: Node = null
var near: Dictionary = {}
var _button: Button
var _timer: float = 0.0


func _ready() -> void:
	spots = load_spots()
	for s: Dictionary in spots:
		_build_sign(s)
	_button = Button.new()
	_button.name = "MinigameButton"
	_button.add_theme_font_size_override("font_size", 32)
	_button.custom_minimum_size = Vector2(320, 96)
	_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_button.offset_left = -160.0
	_button.offset_right = 160.0
	_button.offset_top = -380.0
	_button.offset_bottom = -284.0
	_button.visible = false
	_button.add_to_group(&"joystick_blocker")
	_button.pressed.connect(start)
	if ui != null:
		ui.add_child.call_deferred(_button)


static func load_spots() -> Array:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	return (d as Dictionary).get("games", []) if d is Dictionary else []


func _build_sign(s: Dictionary) -> void:
	var label: Label3D = Label3D.new()
	label.text = "%s oyna!" % str(s["name"])
	label.font_size = 96
	label.pixel_size = 0.01
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(1, 0.84, 0.35)
	label.outline_size = 24
	label.outline_modulate = Color(0.1, 0.12, 0.3)
	label.visibility_range_end = 120.0
	label.visibility_range_begin = 16.0  # yakında ekranı kaplamasın (buton zaten çıkıyor)
	add_child(label)
	var sx: float = float(s["x"])
	var sz: float = float(s["z"])
	label.position = Vector3(sx, TerrainHeight.active_height(sx, sz) + 4.0, sz)


## Oyuncu hangi alanın içinde (yoksa {}).
static func spot_at(pos: Vector3, list: Array) -> Dictionary:
	for s: Dictionary in list:
		if Vector2(pos.x - float(s["x"]), pos.z - float(s["z"])).length() <= float(s["r"]):
			return s
	return {}


func _process(delta: float) -> void:
	_timer += delta
	if _timer < CHECK_S or player == null:
		return
	_timer = 0.0
	near = spot_at(player.global_position, spots)
	_button.visible = not near.is_empty() and game == null
	if _button.visible:
		_button.text = "%s oyna" % str(near["name"])


func start() -> void:
	if near.is_empty() or game != null:
		return
	Sfx.play(&"ui_click")
	var g: Node3D = FrisbeeGame.new()
	var fx: float = float(near["x"])
	var fz: float = float(near["z"])
	g.center = Vector3(fx, TerrainHeight.active_height(fx, fz), fz)
	g.area = float(near.get("area", 24.0))
	g.player = player
	g.ui_parent = ui
	g.closed.connect(func() -> void: game = null)
	game = g
	add_child(g)
	_button.visible = false
