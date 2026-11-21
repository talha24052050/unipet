extends RefCounted

const ZoneCatalog := preload("res://src/world/zone_catalog.gd")
const Greybox := preload("res://src/world/greybox_builder.gd")


func test_catalog_loads_all_zones() -> String:
	var c: RefCounted = ZoneCatalog.load_default()
	if c.ids().size() != 7 or not c.has("ortabahce") or c.default_id != "ortabahce":
		return "bölge listesi yanlış: %s" % [c.ids()]
	return ""


func test_zone_data_valid_and_spawn_free() -> String:
	var c: RefCounted = ZoneCatalog.load_default()
	for id: String in c.ids():
		var z: Dictionary = c.get_zone(id)
		var d: Dictionary = Greybox.load_data(z["greybox"])
		if (d.get("buildings", []) as Array).is_empty():
			return "%s: bina yok" % id
		var spawn: Vector2 = z["spawn"]
		if spawn.distance_to(z["center"]) > float(z["radius"]):
			return "%s: doğuş noktası bölge dışında" % id
		for b: Dictionary in d["buildings"]:
			var poly: PackedVector2Array = Greybox.to_polygon(b["points"])
			if Geometry2D.is_point_in_polygon(spawn, poly):
				return "%s: doğuş noktası bina içinde (%s)" % [id, b.get("name", "?")]
			if Greybox.extrude_polygon(poly, float(b["height"])) == null:
				return "%s: üçgenlenemeyen bina %s" % [id, b.get("name", "?")]
	return ""
