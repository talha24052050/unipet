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

var building_count: int = 0


func _ready() -> void:
	if data_path.is_empty():
		return
	var data: Dictionary = load_data(data_path)
	if data.is_empty():
		return
	_build_ground(float(data.get("radius", 200.0)) + GROUND_MARGIN)
	for a: Dictionary in data.get("areas", []):
		_build_area(a)
	for p: Dictionary in data.get("paths", []):
		_build_path(p)
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


## Taban çokgenini `height` kadar yukarı uzatan kapalı mesh. Çokgen basit değilse null.
static func extrude_polygon(poly: PackedVector2Array, height: float) -> ArrayMesh:
	# XZ düzleminde (x, z) → saat yönü/tersi fark etmesin diye tek yöne çevir.
	if Geometry2D.is_polygon_clockwise(poly):
		poly.reverse()
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
		var a1: Vector3 = Vector3(a.x, height, a.y)
		var b1: Vector3 = Vector3(b.x, height, b.y)
		for v: Vector3 in [a0, b1, a1, a0, b0, b1]:
			st.add_vertex(v)
	st.generate_normals()
	return st.commit()


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


func _build_ground(half_size: float) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Ground"
	body.position = Vector3(0.0, -0.1, 0.0)
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
	var mesh: ArrayMesh = extrude_polygon(poly, height)
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


static func _polygon_center(poly: PackedVector2Array) -> Vector2:
	var sum: Vector2 = Vector2.ZERO
	for v: Vector2 in poly:
		sum += v
	return sum / maxf(1.0, poly.size())
