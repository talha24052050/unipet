extends Node3D
## OSM'den üretilmiş greybox bölge verisini (tools/osm/osm_to_greybox.py) sahneye kurar.
## Binalar: taban şekli yukarı uzatılmış, çarpışmalı. Alanlar/yollar: zemin üstünde düz, çarpışmasız.
## NavigationRegion3D'nin çocuğu olmalı: kurulum, bölgenin navmesh pişirmesinden önce (_ready) biter.

@export_file("*.json") var data_path: String = ""
## Bina adlarını üstlerinde göster (greybox'ta yön bulmak için).
@export var show_labels: bool = true

const PATH_WIDTHS: Dictionary = {"footway": 2.0, "path": 1.5, "pedestrian": 4.0, "service": 4.0}
const AREA_COLORS: Dictionary = {
	"park": Color(0.45, 0.68, 0.38),
	"garden": Color(0.5, 0.72, 0.42),
	"grass": Color(0.55, 0.75, 0.45),
	"playground": Color(0.8, 0.7, 0.45),
	"pitch": Color(0.3, 0.55, 0.3),
}
const BUILDING_COLOR: Color = Color(0.86, 0.82, 0.74)
const GROUND_COLOR: Color = Color(0.72, 0.72, 0.7)
const PATH_COLOR: Color = Color(0.9, 0.9, 0.88)
## Z-fighting olmasın diye katmanlar arası küçük yükseklik farkı.
const AREA_Y: float = 0.02
const PATH_Y: float = 0.04
const GROUND_MARGIN: float = 30.0
## Yürüme yolunun bina duvarını kestiği yerde açılan geçit (ör. Kışla'nın avlu kapıları).
const GATE_WIDTH: float = 4.0
const GATE_HEIGHT: float = 3.2
## Yol ucu duvara bu kadar yakınsa giriş sayılır (metre).
const GATE_TOUCH_DIST: float = 0.6

var building_count: int = 0
var gate_count: int = 0
var _path_lines: Array[PackedVector2Array] = []


## true ise data_path yerine Services.current_zone'un greybox verisi yüklenir (ana sahne bunu kullanır).
@export var follow_current_zone: bool = true


func _ready() -> void:
	if follow_current_zone and Services.zones != null and Services.zones.has(Services.current_zone):
		var zp: String = str(Services.zones.get_zone(Services.current_zone)["greybox"])
		if not zp.is_empty():
			data_path = zp
	if data_path.is_empty():
		return
	var data: Dictionary = load_data(data_path)
	if data.is_empty():
		return
	var c: Array = data.get("center", [0, 0])
	_build_ground(float(data.get("radius", 200.0)) + GROUND_MARGIN, Vector2(float(c[0]), float(c[1])))
	for a: Dictionary in data.get("areas", []):
		_build_area(a)
	for p: Dictionary in data.get("paths", []):
		_build_path(p)
		_path_lines.append(to_polygon(p.get("points", [])))
	for b: Dictionary in data.get("buildings", []):
		_build_building(b)


static func load_data(path: String) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_error("Greybox verisi okunamadı: %s" % path)
		return {}
	return parsed


static func to_polygon(points: Array) -> PackedVector2Array:
	var poly: PackedVector2Array = PackedVector2Array()
	for p: Array in points:
		poly.append(Vector2(float(p[0]), float(p[1])))
	return poly


## Duvarda açılacak geçitler: kenar indeksi → [kenar üzerindeki oran (0..1)].
## İki durum: (1) yol duvarı kesip geçiyor, (2) yolun ucu duvara değiyor (OSM'de giriş/pasaj böyle çizilir;
## ör. Kışla'nın avlu kapıları). Köşeye denk gelen giriş, geçit sığacak şekilde komşu kenarın içine kaydırılır.
static func find_gates(poly: PackedVector2Array, paths: Array[PackedVector2Array]) -> Dictionary:
	var gates: Dictionary = {}
	var n: int = poly.size()
	for line: PackedVector2Array in paths:
		if line.size() < 2:
			continue
		# (2) uçlar
		for e: Vector2 in [line[0], line[line.size() - 1]]:
			var best: int = -1
			var best_d: float = GATE_TOUCH_DIST
			for i: int in n:
				var cp: Vector2 = Geometry2D.get_closest_point_to_segment(e, poly[i], poly[(i + 1) % n])
				var dd: float = cp.distance_to(e)
				if dd <= best_d and poly[i].distance_to(poly[(i + 1) % n]) >= GATE_WIDTH + 1.0:
					best_d = dd
					best = i
			if best != -1:
				_add_gate(gates, poly, best, e)
		# (1) kesişimler
		for i: int in n:
			for j: int in line.size() - 1:
				var hit: Variant = Geometry2D.segment_intersects_segment(poly[i], poly[(i + 1) % n], line[j], line[j + 1])
				if hit != null and poly[i].distance_to(poly[(i + 1) % n]) >= GATE_WIDTH + 1.0:
					_add_gate(gates, poly, i, hit)
	return gates


static func _add_gate(gates: Dictionary, poly: PackedVector2Array, i: int, at: Vector2) -> void:
	var a: Vector2 = poly[i]
	var b: Vector2 = poly[(i + 1) % poly.size()]
	var edge_len: float = a.distance_to(b)
	var margin: float = (GATE_WIDTH * 0.5 + 0.3) / edge_len
	var t: float = clampf(a.distance_to(Geometry2D.get_closest_point_to_segment(at, a, b)) / edge_len, margin, 1.0 - margin)
	var list: Array = gates.get(i, [])
	if list.all(func(o: float) -> bool: return absf(o - t) * edge_len > GATE_WIDTH):
		list.append(t)
	gates[i] = list


## Taban çokgenini `height` kadar yukarı uzatan kapalı mesh. Çokgen basit değilse null.
## `paths` verilirse, yolların duvarı kestiği yerlerde GATE_WIDTH genişliğinde, GATE_HEIGHT yüksekliğinde geçit açılır
## (geçidin üstündeki duvar ve çatı kalır).
static func extrude_polygon(poly: PackedVector2Array, height: float, paths: Array[PackedVector2Array] = []) -> ArrayMesh:
	# XZ düzleminde (x, z) → saat yönü/tersi fark etmesin diye tek yöne çevir.
	if Geometry2D.is_polygon_clockwise(poly):
		poly.reverse()
	var gates: Dictionary = find_gates(poly, paths) if not paths.is_empty() else {}
	var tris: PackedInt32Array = Geometry2D.triangulate_polygon(poly)
	if tris.is_empty():
		return null
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)  # düz gölgeleme (köşeler yumuşatılmasın)
	# Çatı (yukarı bakan)
	for i: int in range(0, tris.size(), 3):
		for k: int in [0, 1, 2]:
			var v: Vector2 = poly[tris[i + k]]
			st.add_vertex(Vector3(v.x, height, v.y))
	# Duvarlar
	var n: int = poly.size()
	for i: int in n:
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % n]
		var a0: Vector3 = Vector3(a.x, 0.0, a.y)
		var b0: Vector3 = Vector3(b.x, 0.0, b.y)
		if gates.has(i):
			_add_wall_with_gates(st, a, b, height, gates[i])
			continue
		var a1: Vector3 = Vector3(a.x, height, a.y)
		var b1: Vector3 = Vector3(b.x, height, b.y)
		for v: Vector3 in [a0, b1, a1, a0, b0, b1]:
			st.add_vertex(v)
	st.generate_normals()
	return st.commit()


## Duvar parçası: [t0, t1] aralığı, [y0, y1] yüksekliği.
static func _add_wall_piece(st: SurfaceTool, a: Vector2, b: Vector2, t0: float, t1: float, y0: float, y1: float) -> void:
	var p: Vector2 = a.lerp(b, t0)
	var q: Vector2 = a.lerp(b, t1)
	var p0: Vector3 = Vector3(p.x, y0, p.y)
	var q0: Vector3 = Vector3(q.x, y0, q.y)
	var p1: Vector3 = Vector3(p.x, y1, p.y)
	var q1: Vector3 = Vector3(q.x, y1, q.y)
	for v: Vector3 in [p0, q1, p1, p0, q0, q1]:
		st.add_vertex(v)


## Geçitli duvar: geçitlerin arası tam boy, geçidin üstü (lento) GATE_HEIGHT'tan yukarısı.
static func _add_wall_with_gates(st: SurfaceTool, a: Vector2, b: Vector2, height: float, ts: Array) -> void:
	var half: float = GATE_WIDTH * 0.5 / a.distance_to(b)
	var sorted: Array = ts.duplicate()
	sorted.sort()
	var cursor: float = 0.0
	for t: float in sorted:
		_add_wall_piece(st, a, b, cursor, t - half, 0.0, height)
		if height > GATE_HEIGHT:
			_add_wall_piece(st, a, b, t - half, t + half, GATE_HEIGHT, height)
		cursor = t + half
	_add_wall_piece(st, a, b, cursor, 1.0, 0.0, height)


static func flat_polygon_mesh(poly: PackedVector2Array, y: float) -> ArrayMesh:
	if Geometry2D.is_polygon_clockwise(poly):
		poly.reverse()
	var tris: PackedInt32Array = Geometry2D.triangulate_polygon(poly)
	if tris.is_empty():
		return null
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for i: int in range(0, tris.size(), 3):
		for k: int in [0, 1, 2]:
			var v: Vector2 = poly[tris[i + k]]
			st.add_vertex(Vector3(v.x, y, v.y))
	return st.commit()


func _material(color: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	return m


## Zemin bölge merkezinde (bölge dosyaları kampüs koordinatı kullanır; Ortabahçe'de merkez orijin).
func _build_ground(half_size: float, center: Vector2 = Vector2.ZERO) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Ground"
	body.position = Vector3(center.x, -0.1, center.y)
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(half_size * 2.0, 0.2, half_size * 2.0)
	shape.shape = box
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = box.size
	bm.material = _material(GROUND_COLOR)
	mesh.mesh = bm
	body.add_child(shape)
	body.add_child(mesh)
	add_child(body)


func _build_building(b: Dictionary) -> void:
	var poly: PackedVector2Array = to_polygon(b.get("points", []))
	var height: float = float(b.get("height", 10.0))
	var mesh: ArrayMesh = extrude_polygon(poly, height, _path_lines)
	gate_count += _count_gates(poly)
	if mesh == null:
		push_warning("Bina üçgenlenemedi, atlandı: %s" % b.get("name", "?"))
		return
	mesh.surface_set_material(0, _material(BUILDING_COLOR))
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Building%d" % building_count
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	var shape: CollisionShape3D = CollisionShape3D.new()
	var trimesh: ConcavePolygonShape3D = mesh.create_trimesh_shape()
	trimesh.backface_collision = true
	shape.shape = trimesh
	body.add_child(mi)
	body.add_child(shape)
	var label_text: String = str(b.get("name", ""))
	if show_labels and not label_text.is_empty():
		var label: Label3D = Label3D.new()
		label.text = label_text
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 96
		label.pixel_size = 0.02
		label.outline_size = 16
		var c: Vector2 = _polygon_center(poly)
		if not Geometry2D.is_point_in_polygon(c, poly):
			c = poly[0]  # halka/U şekilli binada merkez dışarıda kalır (ör. Kışla avlusu)
		label.position = Vector3(c.x, height + 2.0, c.y)
		body.add_child(label)
	add_child(body)
	building_count += 1


func _build_area(a: Dictionary) -> void:
	var poly: PackedVector2Array = to_polygon(a.get("points", []))
	var mesh: ArrayMesh = flat_polygon_mesh(poly, AREA_Y)
	if mesh == null:
		return
	var color: Color = AREA_COLORS.get(str(a.get("kind", "grass")), AREA_COLORS["grass"])
	mesh.surface_set_material(0, _material(color))
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	add_child(mi)


func _build_path(p: Dictionary) -> void:
	var pts: PackedVector2Array = to_polygon(p.get("points", []))
	var width: float = PATH_WIDTHS.get(str(p.get("kind", "footway")), 2.0)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for i: int in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		if a.distance_to(b) < 0.01:
			continue
		var side: Vector2 = (b - a).normalized().orthogonal() * (width * 0.5)
		var q: Array[Vector3] = [
			Vector3(a.x + side.x, PATH_Y, a.y + side.y), Vector3(a.x - side.x, PATH_Y, a.y - side.y),
			Vector3(b.x - side.x, PATH_Y, b.y - side.y), Vector3(b.x + side.x, PATH_Y, b.y + side.y),
		]
		for v: Vector3 in [q[0], q[2], q[1], q[0], q[3], q[2]]:
			st.add_vertex(v)
	var mesh: ArrayMesh = st.commit()
	if mesh.get_surface_count() == 0:
		return
	mesh.surface_set_material(0, _material(PATH_COLOR))
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	add_child(mi)


func _count_gates(poly: PackedVector2Array) -> int:
	var p: PackedVector2Array = poly.duplicate()
	if Geometry2D.is_polygon_clockwise(p):
		p.reverse()
	var total: int = 0
	for list: Array in find_gates(p, _path_lines).values():
		total += list.size()
	return total


static func _polygon_center(poly: PackedVector2Array) -> Vector2:
	var sum: Vector2 = Vector2.ZERO
	for v: Vector2 in poly:
		sum += v
	return sum / maxf(1.0, poly.size())
