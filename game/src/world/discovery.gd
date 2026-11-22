extends Node
## Kampüs keşfi: oyuncu bir yere (data/places.json) yürüyerek yaklaşınca o yer "keşfedildi" olur,
## profile kaydedilir ve bildirim çıkar. Haritadan ışınlanmak sayılmaz: doğduktan / ışınlandıktan sonra
## en az Config.DISCOVER_MIN_WALK metre yürümüş olmak gerekir.

const LocalProfile := preload("res://src/core/local_profile.gd")
const PLACES_DATA: String = "res://data/places.json"
const CHECK_INTERVAL_S: float = 0.5
## Tek kontrolde bundan fazla yer değiştirme = ışınlanma (yürüme sayılmaz).
const TELEPORT_JUMP_M: float = 12.0

signal place_discovered(place: Dictionary, found: int, total: int)

@export var player: Node3D

var places: Array = []
var walked: float = 0.0
var _last: Vector3 = Vector3.INF
var _timer: float = 0.0
var _discovered: PackedStringArray = PackedStringArray()


func _ready() -> void:
	places = load_places()
	_discovered = LocalProfile.load_or_default().get("discovered")


static func load_places(path: String = PLACES_DATA) -> Array:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []
	var d: Variant = JSON.parse_string(f.get_as_text())
	return (d as Dictionary).get("places", []) if d is Dictionary else []


## Yeni keşfedilen yer id'leri: yarıçap içinde olup listede olmayanlar.
static func newly_found(pos: Vector2, place_list: Array, discovered: PackedStringArray, radius: float) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for p: Dictionary in place_list:
		var id: String = str(p.get("id", ""))
		if id.is_empty() or discovered.has(id):
			continue
		var pp: Array = p.get("pos", [0, 0])
		if pos.distance_to(Vector2(float(pp[0]), float(pp[1]))) <= radius:
			out.append(id)
	return out


func _process(delta: float) -> void:
	_timer += delta
	if _timer < CHECK_INTERVAL_S or player == null:
		return
	_timer = 0.0
	tick(player.global_position)


## Bir kontrol adımı (testler doğrudan çağırır).
func tick(pos: Vector3) -> void:
	if _last != Vector3.INF:
		var step: float = Vector2(pos.x - _last.x, pos.z - _last.z).length()
		if step > TELEPORT_JUMP_M:
			walked = 0.0
		else:
			walked += step
	_last = pos
	if walked < Config.DISCOVER_MIN_WALK:
		return
	var found: PackedStringArray = newly_found(Vector2(pos.x, pos.z), places, _discovered, Config.DISCOVER_RADIUS)
	if found.is_empty():
		return
	_discovered.append_array(found)
	var prof: RefCounted = LocalProfile.load_or_default()
	prof.set("discovered", _discovered)
	prof.call("save")
	for id: String in found:
		for p: Dictionary in places:
			if str(p.get("id", "")) == id:
				_announce(p)
				place_discovered.emit(p, _discovered.size(), places.size())


func _announce(p: Dictionary) -> void:
	if not is_inside_tree() or get_tree().current_scene == null:
		return
	Sfx.play(&"care_ok")
	var hud: Node = get_tree().current_scene.find_child("CareHud", true, false)
	if hud != null and hud.has_method("show_toast"):
		hud.call("show_toast", "Yeni yer keşfettin: %s  (%d/%d)" % [str(p.get("name", "")), _discovered.size(), places.size()], 4.0)
