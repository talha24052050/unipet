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


func _paths(d: Dictionary) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for p: Dictionary in d["paths"]:
		out.append(Greybox.to_polygon(p["points"]))
	return out


func test_kisla_has_gates() -> String:
	var d: Dictionary = Greybox.load_data(DATA)
	for b: Dictionary in d["buildings"]:
		if str(b.get("name", "")).contains("Kışla") and not str(b.get("name", "")).contains("Mescit"):
			var poly: PackedVector2Array = Greybox.to_polygon(b["points"])
			if Geometry2D.is_polygon_clockwise(poly):
				poly.reverse()
			var n: int = 0
			for list: Array in Greybox.find_gates(poly, _paths(d)).values():
				n += list.size()
			if n < 2:
				return "Kışla'da %d geçit var, en az 2 olmalı (avludan çıkılamaz)" % n
			return ""
	return "Kışla bulunamadı"


func test_gate_cuts_wall() -> String:
	var square: PackedVector2Array = PackedVector2Array([Vector2(0, 0), Vector2(20, 0), Vector2(20, 20), Vector2(0, 20)])
	var path: Array[PackedVector2Array] = [PackedVector2Array([Vector2(10, -5), Vector2(10, 25)])]
	var gates: Dictionary = Greybox.find_gates(square, path)
	if gates.size() != 2:
		return "kare içinden geçen yol 2 duvarı kesmeli: %s" % gates
	var entry: Array[PackedVector2Array] = [PackedVector2Array([Vector2(10, -5), Vector2(10, 0)])]
	if Greybox.find_gates(square, entry).size() != 1:
		return "duvarda biten yol (giriş) tek geçit açmalı"
	var corner: Array[PackedVector2Array] = [PackedVector2Array([Vector2(-5, -5), Vector2(0, 0)])]
	if Greybox.find_gates(square, corner).is_empty():
		return "köşede biten giriş komşu kenara kaydırılmalı"
	var m: ArrayMesh = Greybox.extrude_polygon(square, 6.0, path)
	var v: PackedVector3Array = m.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for p: Vector3 in v:
		if p.y < Greybox.GATE_HEIGHT - 0.01 and absf(p.x - 10.0) < Greybox.GATE_WIDTH * 0.5 - 0.01 and (p.z < 0.01 or p.z > 19.99):
			return "geçit aralığında yerde duvar köşesi var: %s" % p
	return ""



func test_edge_outward_and_sign_edge() -> String:
	var sq: PackedVector2Array = PackedVector2Array([Vector2(0, 0), Vector2(20, 0), Vector2(20, 10), Vector2(0, 10)])
	for i: int in 4:
		var n: Vector2 = Greybox.edge_outward(sq, i)
		var mid: Vector2 = (sq[i] + sq[(i + 1) % 4]) * 0.5
		if Geometry2D.is_point_in_polygon(mid + n, sq):
			return "kenar %d normali içe bakıyor" % i
	var path: Array[PackedVector2Array] = [PackedVector2Array([Vector2(-5, 15), Vector2(25, 15)])]
	if Greybox.sign_edge(sq, path, 3.0) != 2:
		return "tabela yola bakan kenarda olmalı (2): %d" % Greybox.sign_edge(sq, path, 3.0)
	return ""


func test_landmark_models_load() -> String:
	var f: FileAccess = FileAccess.open(Greybox.LANDMARKS_PATH, FileAccess.READ)
	if f == null:
		return "landmarks.json yok"
	var names: Dictionary = (JSON.parse_string(f.get_as_text()) as Dictionary)["buildings"]
	if names.size() < 5:
		return "en az 5 simge bina bekleniyordu: %d" % names.size()
	for n: String in names:
		var d: Node3D = Greybox.landmark_decor(n)
		if d == null:
			return "süs modeli yüklenemedi: %s" % n
		d.free()
	return ""
