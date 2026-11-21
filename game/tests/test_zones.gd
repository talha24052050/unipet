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


func test_navmesh_source_hash_changes_with_data() -> String:
	var NavRegion: GDScript = load("res://src/world/runtime_nav_region.gd")
	var c: RefCounted = ZoneCatalog.load_default()
	var a: String = NavRegion.call("source_hash", c.get_zone("fef"))
	var b: String = NavRegion.call("source_hash", c.get_zone("insaat"))
	if a.length() != 16 or a == b:
		return "bölge özeti yanlış: %s %s" % [a, b]
	if NavRegion.call("source_hash", c.get_zone("fef")) != a:
		return "özet kararlı değil"
	return ""


func test_prebaked_navmeshes_up_to_date() -> String:
	# Bölge verisi değişip tools/nav/bake_zone_navmeshes.gd çalıştırılmadıysa telefonda açılış yavaşlar.
	var NavRegion: GDScript = load("res://src/world/runtime_nav_region.gd")
	var c: RefCounted = ZoneCatalog.load_default()
	var stale: PackedStringArray = []
	for id: String in c.ids():
		var path: String = "res://data/zones/%s_navmesh.res" % id
		var nm: NavigationMesh = load(path) as NavigationMesh if ResourceLoader.exists(path) else null
		if nm == null or str(nm.get_meta("source_hash", "")) != NavRegion.call("source_hash", c.get_zone(id)):
			stale.append(id)
	if not stale.is_empty():
		return "hazır yürüme haritası eski/eksik: %s → tools/nav/bake_zone_navmeshes.gd çalıştır" % ", ".join(stale)
	return ""
