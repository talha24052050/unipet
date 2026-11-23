extends Control
## Başka bir Control düğümünün hemen altında konumlanır; hedef boyutlandığında veya
## gizlendiğinde otomatik güncellenir. HUD elemanlarının üst üste binmesini önler.

@export var target_path: NodePath
@export var gap: float = 10.0
@export var fallback_top: float = 64.0

var _target: Control


func _ready() -> void:
	_bind_target()
	sync_position.call_deferred()


func _bind_target() -> void:
	if target_path.is_empty():
		return
	var node: Node = get_node_or_null(target_path)
	if node is Control:
		_target = node as Control
		if not _target.resized.is_connected(sync_position):
			_target.resized.connect(sync_position)
		if not _target.item_rect_changed.is_connected(sync_position):
			_target.item_rect_changed.connect(sync_position)
		if not _target.visibility_changed.is_connected(sync_position):
			_target.visibility_changed.connect(sync_position)


func sync_position() -> void:
	if _target == null or not is_instance_valid(_target):
		_bind_target()
	if _target != null and is_instance_valid(_target) and _target.visible:
		var bottom_y: float = _target.global_position.y + _target.size.y if _target.is_inside_tree() else _target.position.y + _target.size.y
		if bottom_y > 0.0:
			if is_inside_tree():
				global_position.y = bottom_y + gap
			else:
				position.y = bottom_y + gap
			return
	position.y = fallback_top
