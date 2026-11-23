extends Node3D
## Kampüs kedileri (data/cats.json): yerlerinde doğar; uzaktakiler işlem yapmaz (mobil performans).

const DATA: String = "res://data/cats.json"
const CampusCat := preload("res://src/world/campus_cat.gd")
const ACTIVE_DIST: float = 70.0
const CHECK_S: float = 1.0

@export var player: Node3D

var cats: Array[Node3D] = []
var _timer: float = 0.0
var _spawned: bool = false


static func load_spots() -> Array:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	return (d as Dictionary).get("spots", []) if d is Dictionary else []


func _process(delta: float) -> void:
	if not _spawned:
		_spawn()  # navigasyon haritası ilk karelerde hazır olmayabilir: yere oturtma ilk güncellemede
		return
	_timer += delta
	if _timer < CHECK_S or player == null:
		return
	_timer = 0.0
	var pp: Vector3 = player.global_position
	for c: Node3D in cats:
		var on: bool = Vector2(c.global_position.x - pp.x, c.global_position.z - pp.z).length() < ACTIVE_DIST
		c.visible = on
		c.set_process(on)


func _spawn() -> void:
	var map: RID = get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return
	# harita sürümü var ama bölge (önceden pişmiş navmesh) henüz eklenmemiş olabilir: en yakın nokta (0,0,0) döner
	var spots: Array = load_spots()
	if spots.is_empty():
		return
	var probe: Vector3 = Vector3(float(spots[0]["x"]), 0, float(spots[0]["z"]))
	if Vector2(NavigationServer3D.map_get_closest_point(map, probe).x - probe.x, NavigationServer3D.map_get_closest_point(map, probe).z - probe.z).length() > 15.0:
		return
	_spawned = true
	var k: int = 0
	for s: Dictionary in spots:
		var home: Vector3 = Vector3(float(s["x"]), 0, float(s["z"]))
		home = NavigationServer3D.map_get_closest_point(map, home)
		for i: int in int(s.get("count", 1)):
			var c: Node3D = CampusCat.new()
			c.add_to_group(&"cats")
			add_child(c)
			c.call("setup", 7919 * (k + 1), home, float(s.get("r", 10.0)))
			var a: float = float(k) * 2.4
			c.global_position = NavigationServer3D.map_get_closest_point(map, home + Vector3(cos(a), 0, sin(a)) * 2.0)
			c.set("player", player)
			cats.append(c)
			k += 1
