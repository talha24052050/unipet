extends Node3D
## Ortabahçe (Kışla avlusu) dokusu — Street View/drone referansına göre:
## avlu sık ağaçlı (fıstık çamı + çınar), yol kavşaklarında kırmızı çiçekli yuvarlak tarhlar.
## Konumlar veriden ve sabit tohumdan üretilir (her açılışta aynı); veri dosyası/navmesh değişmez.

const KISLA_NAME: String = "Yıldız Teknik Üniversitesi Davutpaşa Kışlası"
const TREE_MODELS: Dictionary = {
	"pine": "res://assets/props/tree_stonepine.glb",
	"plane": "res://assets/props/tree_plane.glb",
}
const PINE_SHARE: float = 0.55
const TREE_SPACING: float = 9.0       # ağaçlar arası en az mesafe
const TREE_PATH_CLEARANCE: float = 3.2
const TREE_WALL_CLEARANCE: float = 10.0
const TREE_ATTEMPTS: int = 6000
const MAX_TREES: int = 420
const TREE_RADIUS: float = 0.4
const TREE_COLLIDER_H: float = 4.0
const BED_RADIUS: float = 3.2
const BED_HEIGHT: float = 0.45
const BED_MIN_PATHS: int = 3
const BED_JOIN_DIST: float = 1.5
const VISIBILITY_END: float = 260.0
const SEED: int = 24052050
const FLOWERBED_SHADER: Shader = preload("res://assets/shaders/flowerbed.gdshader")

var tree_count: int = 0
var bed_count: int = 0


## data: greybox verisi; path_lines: yolların XZ çizgileri (greybox_builder'dan).
func build(data: Dictionary, path_lines: Array[PackedVector2Array]) -> void:
	var kisla: PackedVector2Array = PackedVector2Array()
	for b: Dictionary in data.get("buildings", []):
		if str(b.get("name", "")) == KISLA_NAME:
			for q: Array in b.get("points", []):
				kisla.append(Vector2(float(q[0]), float(q[1])))
	if kisla.size() < 3:
		return
	var hull: PackedVector2Array = Geometry2D.convex_hull(kisla)
	var box: Rect2 = Rect2(hull[0], Vector2.ZERO)
	for v: Vector2 in hull:
		box = box.expand(v)
	var near_lines: Array[PackedVector2Array] = []
	for line: PackedVector2Array in path_lines:
		for v: Vector2 in line:
			if box.grow(5.0).has_point(v):
				near_lines.append(line)
				break
	_build_trees(kisla, hull, box, near_lines)
	_build_beds(hull, kisla, near_lines)


func _in_courtyard(p: Vector2, kisla: PackedVector2Array, hull: PackedVector2Array, wall_clear: float) -> bool:
	if not Geometry2D.is_point_in_polygon(p, hull) or Geometry2D.is_point_in_polygon(p, kisla):
		return false
	return _dist_to_poly(p, kisla) > wall_clear


static func _dist_to_poly(p: Vector2, poly: PackedVector2Array) -> float:
	var d: float = INF
	for i: int in poly.size():
		d = minf(d, p.distance_to(Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()])))
	return d


static func _dist_to_lines(p: Vector2, lines: Array[PackedVector2Array]) -> float:
	var d: float = INF
	for line: PackedVector2Array in lines:
		for j: int in line.size() - 1:
			d = minf(d, p.distance_to(Geometry2D.get_closest_point_to_segment(p, line[j], line[j + 1])))
	return d


func _build_trees(kisla: PackedVector2Array, hull: PackedVector2Array, box: Rect2, lines: Array[PackedVector2Array]) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED
	var placed: Array[Vector2] = []
	var kinds: Dictionary = {"pine": [], "plane": []}
	for i: int in TREE_ATTEMPTS:
		if placed.size() >= MAX_TREES:
			break
		var p: Vector2 = Vector2(rng.randf_range(box.position.x, box.end.x), rng.randf_range(box.position.y, box.end.y))
		if not _in_courtyard(p, kisla, hull, TREE_WALL_CLEARANCE) or _dist_to_lines(p, lines) < TREE_PATH_CLEARANCE:
			continue
		var ok: bool = true
		for q: Vector2 in placed:
			if q.distance_squared_to(p) < TREE_SPACING * TREE_SPACING:
				ok = false
				break
		if not ok:
			continue
		placed.append(p)
		(kinds["pine" if rng.randf() < PINE_SHARE else "plane"] as Array).append(
			Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.85, 1.2)), Vector3(p.x, 0.0, p.y)))
	tree_count = placed.size()
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "CourtyardTreeColliders"
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = TREE_RADIUS
	shape.height = TREE_COLLIDER_H
	for p: Vector2 in placed:
		var col: CollisionShape3D = CollisionShape3D.new()
		col.shape = shape
		col.position = Vector3(p.x, TREE_COLLIDER_H * 0.5, p.y)
		body.add_child(col)
	add_child(body)
	for kind: String in kinds:
		_add_multimesh(TREE_MODELS[kind], kinds[kind])


func _add_multimesh(path: String, xforms: Array) -> void:
	if xforms.is_empty() or not ResourceLoader.exists(path):
		return
	var scene: Node = (load(path) as PackedScene).instantiate()
	for mi: Node in scene.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (mi as MeshInstance3D).mesh
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = m
		mm.instance_count = xforms.size()
		for i: int in xforms.size():
			mm.set_instance_transform(i, (xforms[i] as Transform3D) * (mi as MeshInstance3D).transform)
		var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.visibility_range_end = VISIBILITY_END
		add_child(mmi)
	scene.free()


## Avludaki yol kavşakları (≥3 yol ucu/köşesi bir arada) → yuvarlak çiçek tarhı.
func _build_beds(hull: PackedVector2Array, kisla: PackedVector2Array, lines: Array[PackedVector2Array]) -> void:
	var pts: Array[Vector2] = []
	for line: PackedVector2Array in lines:
		for v: Vector2 in line:
			if _in_courtyard(v, kisla, hull, 15.0):
				pts.append(v)
	var centers: Array[Vector2] = []
	for v: Vector2 in pts:
		var n: int = 0
		for w: Vector2 in pts:
			if v.distance_to(w) < BED_JOIN_DIST:
				n += 1
		if n < BED_MIN_PATHS:
			continue
		var dup: bool = false
		for c: Vector2 in centers:
			if c.distance_to(v) < BED_RADIUS * 3.0:
				dup = true
				break
		if not dup:
			centers.append(v)
	bed_count = centers.size()
	if centers.is_empty():
		return
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = BED_RADIUS
	cyl.bottom_radius = BED_RADIUS + 0.15
	cyl.height = BED_HEIGHT
	cyl.radial_segments = 14
	cyl.rings = 1
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = FLOWERBED_SHADER
	cyl.material = mat
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = cyl
	mm.instance_count = centers.size()
	for i: int in centers.size():
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(centers[i].x, BED_HEIGHT * 0.5, centers[i].y)))
	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.visibility_range_end = VISIBILITY_END
	add_child(mmi)
