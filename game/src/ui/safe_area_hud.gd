extends Node
## CanvasLayer altındaki HUD düğümlerini güvenli alan (safe area) içine taşır.
## Düğümlerin ağaçtaki yerini değiştirmez, sadece başlangıç offset'lerine güvenli alan ekler.

@export var top_nodes: Array[NodePath] = []
@export var bottom_nodes: Array[NodePath] = []
@export var fill_controls: Array[NodePath] = []

## node_path -> Vector4(offset_left, offset_top, offset_right, offset_bottom)
var _base_offsets: Dictionary = {}


func _ready() -> void:
	_capture_bases()
	var vp: Viewport = get_viewport()
	if vp != null and not vp.size_changed.is_connected(refresh):
		vp.size_changed.connect(refresh)
	refresh()


func _capture_bases() -> void:
	for path: NodePath in top_nodes + bottom_nodes + fill_controls:
		if _base_offsets.has(path):
			continue
		var c: Control = get_node_or_null(path) as Control
		if c != null:
			_base_offsets[path] = Vector4(c.offset_left, c.offset_top, c.offset_right, c.offset_bottom)


func refresh() -> void:
	apply_insets(SafeArea.get_viewport_insets(get_viewport()))


func apply_insets(insets: Dictionary) -> void:
	_capture_bases()
	var l: float = float(insets.get("left", 0.0))
	var t: float = float(insets.get("top", 0.0))
	var r: float = float(insets.get("right", 0.0))
	var b: float = float(insets.get("bottom", 0.0))

	for path: NodePath in top_nodes:
		var c: Control = get_node_or_null(path) as Control
		if c == null or not _base_offsets.has(path):
			continue
		var base: Vector4 = _base_offsets[path]
		var dx: float = -r if c.anchor_right >= 0.5 else l
		c.offset_left = base.x + dx
		c.offset_right = base.z + dx
		c.offset_top = base.y + t
		c.offset_bottom = base.w + t

	for path: NodePath in bottom_nodes:
		var c: Control = get_node_or_null(path) as Control
		if c == null or not _base_offsets.has(path):
			continue
		var base: Vector4 = _base_offsets[path]
		var dx: float = -r if c.anchor_right >= 0.5 else l
		c.offset_left = base.x + dx
		c.offset_right = base.z + dx
		c.offset_top = base.y - b
		c.offset_bottom = base.w - b

	for path: NodePath in fill_controls:
		var c: Control = get_node_or_null(path) as Control
		if c == null or not _base_offsets.has(path):
			continue
		var base: Vector4 = _base_offsets[path]
		c.offset_left = base.x + l
		c.offset_top = base.y + t
		c.offset_right = base.z - r
		c.offset_bottom = base.w - b
