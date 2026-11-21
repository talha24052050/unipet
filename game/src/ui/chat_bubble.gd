extends Node3D
## Petin başının üstünde duran, kameraya bakan konuşma baloncuğu.
## 4 saniye sonra otomatik kaybolur; yeni mesaj eskisinin yerini alır.

const DEFAULT_DURATION: float = 4.0

@export var duration: float = DEFAULT_DURATION

var _timer: float = 0.0

@onready var _sprite: Sprite3D = $Sprite3D
@onready var _viewport: SubViewport = $SubViewport
@onready var _label: Label = $SubViewport/PanelContainer/MarginContainer/Label


func _ready() -> void:
	visible = false
	_ensure_nodes()
	if _sprite != null and _viewport != null:
		_sprite.texture = _viewport.get_texture()


func _ensure_nodes() -> void:
	if _sprite == null:
		_sprite = get_node_or_null("Sprite3D")
	if _viewport == null:
		_viewport = get_node_or_null("SubViewport")
	if _label == null:
		_label = get_node_or_null("SubViewport/PanelContainer/MarginContainer/Label")


func _process(delta: float) -> void:
	if _timer > 0.0:
		_timer -= delta
		if _timer <= 0.0:
			_timer = 0.0
			visible = false


func show_message(text: String, dur: float = -1.0) -> void:
	var clean: String = text.strip_edges()
	if clean.is_empty():
		return
	_ensure_nodes()
	if _label != null:
		_label.text = clean
	_timer = dur if dur > 0.0 else duration
	_update_height()
	visible = true


func hide_bubble() -> void:
	_timer = 0.0
	visible = false


func is_showing() -> bool:
	return visible and _timer > 0.0


func current_text() -> String:
	_ensure_nodes()
	return _label.text if _label != null else ""


func _update_height() -> void:
	var p: Node = get_parent()
	if p != null and "visual" in p and p.visual != null and p.visual.has_method("footprint"):
		var fp: Vector2 = p.visual.footprint()
		position.y = fp.y + 0.35
