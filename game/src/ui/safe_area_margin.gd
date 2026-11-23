extends MarginContainer
## Mevcut kenar boşluklarına (margin) cihazın güvenli alan (safe area) payını ekler.
## İstediğin kenarı apply_* bayraklarıyla açıp kapatabilirsin; sahne yapısını bozmaz.

@export var apply_left: bool = true
@export var apply_top: bool = true
@export var apply_right: bool = true
@export var apply_bottom: bool = true

var _base_captured: bool = false
var _base_left: int = 0
var _base_top: int = 0
var _base_right: int = 0
var _base_bottom: int = 0


func _ready() -> void:
	_capture_base()
	var vp: Viewport = get_viewport()
	if vp != null and not vp.size_changed.is_connected(refresh):
		vp.size_changed.connect(refresh)
	refresh()


func _capture_base() -> void:
	if _base_captured:
		return
	_base_captured = true
	_base_left = get_theme_constant("margin_left")
	_base_top = get_theme_constant("margin_top")
	_base_right = get_theme_constant("margin_right")
	_base_bottom = get_theme_constant("margin_bottom")


func refresh() -> void:
	apply_insets(SafeArea.get_viewport_insets(get_viewport()))


func apply_insets(insets: Dictionary) -> void:
	_capture_base()
	var l: int = roundi(float(insets.get("left", 0.0))) if apply_left else 0
	var t: int = roundi(float(insets.get("top", 0.0))) if apply_top else 0
	var r: int = roundi(float(insets.get("right", 0.0))) if apply_right else 0
	var b: int = roundi(float(insets.get("bottom", 0.0))) if apply_bottom else 0
	add_theme_constant_override("margin_left", _base_left + l)
	add_theme_constant_override("margin_top", _base_top + t)
	add_theme_constant_override("margin_right", _base_right + r)
	add_theme_constant_override("margin_bottom", _base_bottom + b)
