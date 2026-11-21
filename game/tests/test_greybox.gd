extends RefCounted

const Greybox := preload("res://src/world/greybox_builder.gd")
const DATA: String = "res://data/zones/ortabahce_greybox.json"


func test_data_loads() -> String:
	var d: Dictionary = Greybox.load_data(DATA)
	if (d.get("buildings", []) as Array).is_empty():
		return "bina yok"
	var names: Array = (d["areas"] as Array).map(func(a: Dictionary) -> String: return str(a.get("name", "")))
	if not names.has("Ortabahçe"):
		return "Ortabahçe alanı yok"
	return ""


func test_all_buildings_triangulate() -> String:
	var d: Dictionary = Greybox.load_data(DATA)
	for b: Dictionary in d["buildings"]:
		var poly: PackedVector2Array = Greybox.to_polygon(b["points"])
		if Greybox.extrude_polygon(poly, float(b["height"])) == null:
			return "üçgenlenemedi: %s" % b.get("name", "?")
	return ""


func test_spawn_not_inside_building() -> String:
	var d: Dictionary = Greybox.load_data(DATA)
	for b: Dictionary in d["buildings"]:
		if Geometry2D.is_point_in_polygon(Vector2.ZERO, Greybox.to_polygon(b["points"])):
			return "başlangıç noktası bina içinde: %s" % b.get("name", "?")
	return ""


func test_extrude_faces_outward() -> String:
	var square: PackedVector2Array = PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10)])
	var m: ArrayMesh = Greybox.extrude_polygon(square, 5.0)
	var v: PackedVector3Array = m.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	# Godot'ta ön yüz saat yönü: normal = (c-a) x (b-a)
	var roof: Vector3 = (v[2] - v[0]).cross(v[1] - v[0])
	if roof.y <= 0.0:
		return "çatı aşağı bakıyor"
	var w: int = v.size() - 3
	var wall: Vector3 = (v[w + 2] - v[w]).cross(v[w + 1] - v[w]).normalized()
	var wall_center: Vector3 = (v[w] + v[w + 1] + v[w + 2]) / 3.0
	var outward: Vector3 = Vector3(wall_center.x - 5.0, 0.0, wall_center.z - 5.0)
	if wall.dot(outward) <= 0.0:
		return "duvar içe bakıyor"
	return ""
