extends RefCounted
## Kampüs bölgeleri (game/data/zones/zones.json). Her bölge ayrı oda + ayrı greybox verisi.

const PATH: String = "res://data/zones/zones.json"

var default_id: String = "ortabahce"
## id -> {"id", "name", "center": Vector2, "radius": float, "spawn": Vector2, "greybox": String, "props": String}
var _zones: Dictionary = {}
var _order: PackedStringArray = []


static func load_default() -> RefCounted:
	var c: RefCounted = new()
	c.load_from(PATH)
	return c


func load_from(path: String) -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		push_error("Bölge listesi okunamadı: %s" % path)
		return
	default_id = str((data as Dictionary).get("default", default_id))
	for z: Dictionary in (data as Dictionary).get("zones", []):
		var c: Array = z.get("center", [0, 0])
		var s: Array = z.get("spawn", c)
		var id: String = str(z["id"])
		_zones[id] = {
			"id": id,
			"name": str(z.get("name", id)),
			"center": Vector2(float(c[0]), float(c[1])),
			"radius": float(z.get("radius", 200.0)),
			"spawn": Vector2(float(s[0]), float(s[1])),
			"greybox": str(z.get("greybox", "")),
			"props": str(z.get("props", "")),
		}
		_order.append(id)


func has(id: String) -> bool:
	return _zones.has(id)


func get_zone(id: String) -> Dictionary:
	return _zones.get(id, _zones.get(default_id, {}))


func ids() -> PackedStringArray:
	return _order
