extends Button
## Oyun ekranındaki "Harita" butonu: kampüs haritasını açar, oyuncunun konumunu "buradasın" için iletir.

const CampusMap := preload("res://src/ui/campus_map.gd")

## Konumu iletilecek oyuncu (boşsa ../../Player denenir).
@export var player: Node3D


func _ready() -> void:
	pressed.connect(_open)


func _open() -> void:
	var p: Node3D = player if player != null else get_node_or_null("../../Player") as Node3D
	CampusMap.open_from(get_tree(), p.global_position if p != null else Vector3.INF)
