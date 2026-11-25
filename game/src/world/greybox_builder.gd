extends Node3D
## OSM'den üretilmiş greybox bölge verisini (tools/osm/osm_to_greybox.py) sahneye kurar.
## Binalar: taban şekli yukarı uzatılmış, çarpışmalı. Alanlar/yollar: zemin üstünde düz, çarpışmasız.
## NavigationRegion3D'nin çocuğu olmalı: kurulum, bölgenin navmesh pişirmesinden önce (_ready) biter.

const BuildingStyle := preload("res://src/world/building_style.gd")
const BUILDING_WALL_SHADER: Shader = preload("res://assets/shaders/building_wall.gdshader")
const PATH_COBBLE_SHADER: Shader = preload("res://assets/shaders/path_cobble.gdshader")
const ROAD_ASPHALT_SHADER: Shader = preload("res://assets/shaders/road_asphalt.gdshader")
const CYCLEWAY_SHADER: Shader = preload("res://assets/shaders/cycleway.gdshader")
const PARKING_LOT_SHADER: Shader = preload("res://assets/shaders/parking_lot.gdshader")
const GRASS_SHADER: Shader = preload("res://assets/shaders/grass.gdshader")
const GRASS_KINDS: PackedStringArray = ["grass", "park", "garden", "wood"]
const ROAD_KINDS: PackedStringArray = ["residential", "residential_oneway", "service", "parking_aisle"]
const GreeneryDecor := preload("res://src/world/greenery_decor.gd")
## Ortabahçe'yi çevreleyen bina (avlu tespiti için).
const KISLA_NAME: String = "Yıldız Teknik Üniversitesi Davutpaşa Kışlası"
const MESCIT_NAME: String = "Davutpaşa Kışlası Mesciti"
const MERKEZ_KUTUPHANE_NAME: String = "Merkez Kütüphanesi"
const TARIHI_HAMAM_NAME: String = "Tarihi Hamam"
## YTÜ Davutpaşa Kampüsü Lojmanları (Yapı Dergisi Tablo 2 — Munsell Renk Dizgesi 3 blok grubu):
## - Grup 1 (C1, J3, K1, L2): Çakıl Sinterflex seramik kaplama (32,5-9/2) + Sarı merdiven kuleleri
## - Grup 2 (C2, F, J2, L3):  Beyaz Sinterflex seramik kaplama (35-9/1) + Yeşil merdiven kuleleri
## - Grup 3 (J1, K2, L1):     Çimento Sinterflex seramik kaplama (30-5/2) + Turuncu merdiven kuleleri
const LOJMAN_GROUPS: Dictionary = {
	"C1 Blok": "cakil", "J3 Blok": "cakil", "K1 Blok": "cakil", "L2 Blok": "cakil",
	"C2 Blok": "beyaz", "F Blok": "beyaz", "J2 Blok": "beyaz", "L3 Blok": "beyaz",
	"J1 Blok": "cimento", "K2 Blok": "cimento", "L1 Blok": "cimento",
}
const LOJMAN_PALETTES: Dictionary = {
	"cakil": {"wall": Color(0.84, 0.83, 0.76), "roof": Color(0.68, 0.67, 0.62)},
	"beyaz": {"wall": Color(0.87, 0.88, 0.85), "roof": Color(0.71, 0.72, 0.69)},
	"cimento": {"wall": Color(0.57, 0.57, 0.53), "roof": Color(0.46, 0.46, 0.43)},
}
## Ortabahçe (Kışla avlusu) yolları gerçekte pembe-kırmızı beton; dışarıdaki yaya yolları parke.
const PATTERN_COBBLE: int = 0
const PATTERN_PINK_CONCRETE: int = 1
var _courtyard_hull: PackedVector2Array = PackedVector2Array()
## Düz yüzey birleştirme: yollar ve alanlar tek tek MeshInstance olunca ~450 çizim çağrısı oluyordu (telefon).
## _ready'de açılır; aynı malzeme + aynı 150 m hücre → tek mesh. Tek başına çağrılınca (testler) eski davranış.
const BATCH_CELL: float = 300.0
var _batching: bool = false
var _batches: Dictionary = {}  # "matid|cx|cz" -> {"mat", "verts": PackedVector3Array, "uvs": PackedVector2Array}
var _courtyard_poly: PackedVector2Array = PackedVector2Array()

static var _cobble_materials: Dictionary = {}

@export_file("*.json") var data_path: String = ""
## Bina adlarını üstlerinde göster (greybox'ta yön bulmak için).
@export var show_labels: bool = true

const PATH_WIDTHS: Dictionary = {
	"residential": 6.2,
	"residential_oneway": 4.6,
	"service": 4.4,
	"parking_aisle": 3.6,
	"cycleway": 1.6,
	"pedestrian": 4.0,
	"footway": 2.2,
	"path": 1.5,
}
const AREA_COLORS: Dictionary = {
	"park": Color(0.30, 0.49, 0.21),   # zengin zümrüt-yeşil park çimi (Ortabahçe/Yıldızbahçe)
	"garden": Color(0.27, 0.45, 0.20), # koyu botanik bahçe yeşili
	"wood": Color(0.24, 0.41, 0.17),   # koruluk / orman altı derin yeşili
	"grass": Color(0.36, 0.54, 0.24),  # sıcak güneşli çayır yeşili
	"playground": Color(0.76, 0.67, 0.44),
	"pitch": Color(0.28, 0.53, 0.27),
	"parking": Color(0.24, 0.26, 0.29),
}
const BUILDING_COLOR: Color = Color(0.91, 0.93, 0.94)
const GROUND_COLOR: Color = Color(0.38, 0.53, 0.25)  # doğal tepe çimi; parklardan hafif sıcak
const PATH_COLOR: Color = Color(0.91, 0.89, 0.85) # yaya yolu krem/açık gri
const SERVICE_PATH_COLOR: Color = Color(0.290, 0.310, 0.333) # araç yolu koyu gri #4A4F55
## Z-fighting olmasın diye net kot hiyerarşisi: çim (0.05) < otopark (0.078) < araç yolları (0.084..0.094) < bisiklet (0.102) < yaya (0.114).
const AREA_Y: float = 0.05
const PARKING_Y: float = 0.080
const AREA_SUBDIV_M: float = 8.0
const PARKING_SUBDIV_M: float = 2.5
const AISLE_Y: float = 0.084
const SERVICE_Y: float = 0.088
const ROAD_ONEWAY_Y: float = 0.091
const ROAD_Y: float = 0.094
const CYCLE_Y: float = 0.102
const PATH_Y: float = 0.114
const PATH_SUBDIV_M: float = 3.0
const BUILDING_FOUNDATION_M: float = 2.5
const GROUND_MARGIN: float = 30.0
const CampusMap := preload("res://src/ui/campus_map.gd")
const LANDMARKS_PATH: String = "res://data/landmarks.json"
## Kendi 3D mimari alınlık tabelası bulunan ikonik binalarda otomatik küçük mavi kutu tabela üretilmez.
const CUSTOM_SIGN_BUILDINGS: PackedStringArray = [
	"Yıldız Store",
	"Yemekhane",
	"BÜYÜK EV",
	"Davutpaşa Kışlası Mesciti",
	"Elektrik Elektronik Fakültesi",
	"Şehit Prof. Dr. İlhan Varank Kütüphanesi",
	"Merkez Kütüphanesi",
	"Tarihi Hamam",
	"A Blok - Fen Edebiyat Fakültesi Dekanlığı",
	"Eğitim Fakültesi",
	"Yabancı Diller Yüksekokulu",
	"E Blok - İnşaat Mühendisliği",
	"YTÜ Merkez Laboratuvarı",
	"Kapalı Yüzme Havuzu",
]
static var _landmarks: Dictionary = {}
## Cephe tabelası.
const SIGN_HEIGHT_M: float = 3.6
const SIGN_PANEL_H: float = 0.9
const SIGN_CHAR_W: float = 0.38
const SIGN_PAD: float = 0.8
const SIGN_OFFSET: float = 0.12
const SIGN_COLOR: Color = Color(0.12, 0.18, 0.42)
const SIGN_HISTORIC_COLOR: Color = Color(0.45, 0.2, 0.15)
const SIGN_VISIBLE_DISTANCE: float = 90.0
## Geçit kemeri (tarihi binalar).
const PORTAL_PILLAR: Vector3 = Vector3(0.7, 0.0, 0.7)
const PORTAL_BEAM_H: float = 0.6
const PORTAL_COLOR: Color = Color(0.82, 0.74, 0.6)
## Bina adı etiketi: küçük ve sadece yakındayken.
const LABEL_FONT_SIZE: int = 64
const LABEL_PIXEL_SIZE: float = 0.012
const LABEL_OUTLINE: int = 12
const LABEL_VISIBLE_DISTANCE: float = 60.0
## Yürüme yolunun bina duvarını kestiği yerde açılan geçit (ör. Kışla'nın avlu kapıları).
const GATE_WIDTH: float = 4.0
const GATE_HEIGHT: float = 3.2
## Yol ucu duvara bu kadar yakınsa giriş sayılır (metre).
const GATE_TOUCH_DIST: float = 0.6

var building_count: int = 0
var gate_count: int = 0
var _path_lines: Array[PackedVector2Array] = []
## Her yolun kutusu (geçit aramasında sadece binaya yakın yollara bakmak için).
var _path_boxes: Array[Rect2] = []
## Kavşak / bölünmüş OSM yolu düğüm sayacı (uç kapakların yolu kesmesini önler).
var _path_node_counts: Dictionary = {}
## Paralel zıt yönlü tek şeritli (residential_oneway) bulvar segmentleri — arada sahte çim boşluk kalmasın.
var _oneway_segs: Array = []  # [{"a": Vector2, "b": Vector2, "dir": Vector2, "idx": int}]
var _current_path_idx: int = -1


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
	_load_terrain_for(data_path)
	var extent: Rect2 = data_extent(data)
	_build_ground_rect(extent.grow(GROUND_MARGIN))
	_find_courtyard(data)
	_batching = true
	for a: Dictionary in data.get("areas", []):
		_build_area(a)
	var all_paths: Array = data.get("paths", [])
	_index_path_nodes(all_paths)
	for pi: int in all_paths.size():
		var p: Dictionary = all_paths[pi]
		_current_path_idx = pi
		_build_path(p)
		var line: PackedVector2Array = to_polygon(p.get("points", []))
		_path_lines.append(line)
		_path_boxes.append(_poly_box(line))
	_current_path_idx = -1
	for b: Dictionary in data.get("buildings", []):
		_build_building(b)
	_flush_batches()
	_batching = false
	# Binaya bağlı olmayan simge yapılar (kampüs kapıları)
	for n: Node3D in free_landmarks():
		var lp: Vector3 = n.position
		lp.y += TerrainHeight.active_height(lp.x, lp.z)
		n.position = lp
		add_child(n)
	# Yeşil doku (ağaçlar, tarhlar, pist): greybox ile aynı klasörde <ad>_greenery.json
	var decor: Node3D = GreeneryDecor.new()
	decor.name = "GreeneryDecor"
	add_child(decor)
	decor.build_from_file(data_path.replace("_greybox.json", "_greenery.json"))


func _load_terrain_for(greybox_path: String) -> void:
	if not TerrainHeight.enabled:
		TerrainHeight.active = null
		return
	var terrain_path: String = greybox_path.replace("_greybox.json", "_terrain.json")
	TerrainHeight.active = TerrainHeight.load_from_file(terrain_path)


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
## `floor_y` negatif verilirse duvarlar temel olarak aşağı uzar (eğimli arazide binalar havada kalmasın).
## `paths` verilirse, yolların duvarı kestiği yerlerde GATE_WIDTH genişliğinde, GATE_HEIGHT yüksekliğinde geçit açılır
## (geçidin üstündeki duvar ve çatı kalır).
static func extrude_polygon(poly: PackedVector2Array, height: float, paths: Array[PackedVector2Array] = [], floor_y: float = 0.0) -> ArrayMesh:
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
			var v3: Vector3 = Vector3(v.x, height, v.y)
			st.set_uv(Vector2(2.0, v3.y))
			st.add_vertex(v3)
	# Duvarlar
	var n: int = poly.size()
	for i: int in n:
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % n]
		var a0: Vector3 = Vector3(a.x, floor_y, a.y)
		var b0: Vector3 = Vector3(b.x, floor_y, b.y)
		if gates.has(i):
			_add_wall_with_gates(st, a, b, height, gates[i], floor_y)
			continue
		var a1: Vector3 = Vector3(a.x, height, a.y)
		var b1: Vector3 = Vector3(b.x, height, b.y)
		for v: Vector3 in [a0, b1, a1, a0, b0, b1]:
			st.set_uv(Vector2(2.0, v.y))
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
		st.set_uv(Vector2(2.0, v.y))
		st.add_vertex(v)


## Geçitli duvar: geçitlerin arası tam boy, geçidin üstü (lento) GATE_HEIGHT'tan yukarısı.
static func _add_wall_with_gates(st: SurfaceTool, a: Vector2, b: Vector2, height: float, ts: Array, floor_y: float = 0.0) -> void:
	var half: float = GATE_WIDTH * 0.5 / a.distance_to(b)
	var sorted: Array = ts.duplicate()
	sorted.sort()
	var cursor: float = 0.0
	for t: float in sorted:
		_add_wall_piece(st, a, b, cursor, t - half, floor_y, height)
		if height > GATE_HEIGHT:
			_add_wall_piece(st, a, b, t - half, t + half, GATE_HEIGHT, height)
		cursor = t + half
	_add_wall_piece(st, a, b, cursor, 1.0, floor_y, height)


static func flat_polygon_mesh(poly: PackedVector2Array, y: float, sample_terrain: bool = false, subdiv_m: float = AREA_SUBDIV_M, max_depth: int = 6) -> ArrayMesh:
	if Geometry2D.is_polygon_clockwise(poly):
		poly.reverse()
	var tris: PackedInt32Array = Geometry2D.triangulate_polygon(poly)
	if tris.is_empty():
		return null
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(0, tris.size(), 3):
		var a: Vector2 = poly[tris[i]]
		var b: Vector2 = poly[tris[i + 1]]
		var c: Vector2 = poly[tris[i + 2]]
		if sample_terrain:
			_emit_terrain_tri(st, a, b, c, y, 0, subdiv_m, max_depth)
		else:
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(a.x, y, a.y))
			st.add_vertex(Vector3(b.x, y, b.y))
			st.add_vertex(Vector3(c.x, y, c.y))
	return st.commit()


## Eğimli arazide büyük çim/park/otopark üçgenlerini özyinelemeli alt-bölerek zemine oturtur (z-fighting önler).
static func _emit_terrain_tri(st: SurfaceTool, a: Vector2, b: Vector2, c: Vector2, y_off: float, depth: int, subdiv_m: float = AREA_SUBDIV_M, max_depth: int = 6) -> void:
	var ab: float = a.distance_squared_to(b)
	var bc: float = b.distance_squared_to(c)
	var ca: float = c.distance_squared_to(a)
	var max_sq: float = maxf(ab, maxf(bc, ca))
	# Sadece çökük avluya değen üçgenler incelir (eskiden 124×124 m'lik kare: mobilde gereksiz binlerce üçgen).
	var near_hamam: bool = _tri_touches_hamam_pit(a, b, c)
	var eff_subdiv: float = minf(subdiv_m, 1.1) if near_hamam else subdiv_m
	var eff_max_depth: int = maxi(max_depth, 9) if near_hamam else max_depth
	if depth < eff_max_depth and max_sq > eff_subdiv * eff_subdiv:
		if ab >= bc and ab >= ca:
			var m: Vector2 = (a + b) * 0.5
			_emit_terrain_tri(st, a, m, c, y_off, depth + 1, subdiv_m, max_depth)
			_emit_terrain_tri(st, m, b, c, y_off, depth + 1, subdiv_m, max_depth)
		elif bc >= ab and bc >= ca:
			var m: Vector2 = (b + c) * 0.5
			_emit_terrain_tri(st, a, b, m, y_off, depth + 1, subdiv_m, max_depth)
			_emit_terrain_tri(st, a, m, c, y_off, depth + 1, subdiv_m, max_depth)
		else:
			var m: Vector2 = (c + a) * 0.5
			_emit_terrain_tri(st, a, b, m, y_off, depth + 1, subdiv_m, max_depth)
			_emit_terrain_tri(st, m, b, c, y_off, depth + 1, subdiv_m, max_depth)
		return
	if near_hamam and (_in_hamam_sunk_pit(a.x, a.y) or _in_hamam_sunk_pit(b.x, b.y) or _in_hamam_sunk_pit(c.x, c.y)):
		return
	for v: Vector2 in [a, b, c]:
		st.set_normal(TerrainHeight.active_normal(v.x, v.y))
		st.add_vertex(Vector3(v.x, TerrainHeight.active_height(v.x, v.y) + y_off, v.y))


const WATER_COLOR: Color = Color(0.22, 0.47, 0.6)


func _water_material() -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = WATER_COLOR
	m.roughness = 0.08
	m.metallic = 0.25
	m.metallic_specular = 0.8
	return m


func _material(color: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	return m


## Verideki bina/alan/yol köşelerinin kapsadığı dikdörtgen (XZ). Boşsa merkez/yarıçaptan.
static func data_extent(data: Dictionary) -> Rect2:
	var r: Rect2 = Rect2()
	var first: bool = true
	for key: String in ["buildings", "areas", "paths"]:
		for item: Dictionary in data.get(key, []):
			for p: Array in item.get("points", []):
				var v: Vector2 = Vector2(float(p[0]), float(p[1]))
				if first:
					r = Rect2(v, Vector2.ZERO)
					first = false
				else:
					r = r.expand(v)
	if first:
		var c: Array = data.get("center", [0, 0])
		var rad: float = float(data.get("radius", 200.0))
		r = Rect2(Vector2(float(c[0]) - rad, float(c[1]) - rad), Vector2(rad * 2.0, rad * 2.0))
	return r


func _build_ground_rect(rect: Rect2) -> void:
	if TerrainHeight.enabled and TerrainHeight.active != null:
		_build_terrain_ground(rect, TerrainHeight.active)
		return
	var c: Vector2 = rect.get_center()
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Ground"
	body.position = Vector3(c.x, -0.1, c.y)
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(rect.size.x, 0.2, rect.size.y)
	shape.shape = box
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = box.size
	bm.material = _grass_material(GROUND_COLOR)
	mesh.mesh = bm
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(shape)
	body.add_child(mesh)
	add_child(body)


const MERKEZ_LIB_ORIGIN: Vector2 = Vector2(-74.33, -236.71)
const MERKEZ_LIB_U: Vector2 = Vector2(0.809885, 0.586589)
const MERKEZ_LIB_V: Vector2 = Vector2(-0.586589, 0.809885)
const MERKEZ_LIB_UPPER_Y: float = -0.42
const MERKEZ_LIB_SUNK_Y: float = -3.92

const HAMAM_ORIGIN: Vector2 = Vector2(44.56, -161.98)
const HAMAM_U: Vector2 = Vector2(-0.630079, 0.776531)
const HAMAM_N: Vector2 = Vector2(-0.776519, -0.630094)
const HAMAM_UPPER_Y: float = 0.00
const HAMAM_SUNK_Y: float = -2.00
static var HAMAM_PIT_AABB: Rect2 = _hamam_pit_aabb(3.0)


static func _in_merkez_sunk_pit(wx: float, wz: float) -> bool:
	var rx: float = wx - MERKEZ_LIB_ORIGIN.x
	var rz: float = wz - MERKEZ_LIB_ORIGIN.y
	var lu: float = rx * MERKEZ_LIB_U.x + rz * MERKEZ_LIB_U.y
	var lv: float = rx * MERKEZ_LIB_V.x + rz * MERKEZ_LIB_V.y
	return lu >= 18.42 and lu <= 58.20 and lv >= 18.12 and lv <= 31.25


## Üçgenin AABB'si Hamam çökük avlusunun (3 m paylı) dünya AABB'siyle kesişiyor mu.
static func _tri_touches_hamam_pit(a: Vector2, b: Vector2, c: Vector2) -> bool:
	var lo: Vector2 = Vector2(minf(a.x, minf(b.x, c.x)), minf(a.y, minf(b.y, c.y)))
	var hi: Vector2 = Vector2(maxf(a.x, maxf(b.x, c.x)), maxf(a.y, maxf(b.y, c.y)))
	return hi.x >= HAMAM_PIT_AABB.position.x and lo.x <= HAMAM_PIT_AABB.end.x \
		and hi.y >= HAMAM_PIT_AABB.position.y and lo.y <= HAMAM_PIT_AABB.end.y


static func _hamam_pit_aabb(margin: float) -> Rect2:
	var r: Rect2 = Rect2(HAMAM_ORIGIN + HAMAM_U * 0.15 + HAMAM_N * -0.45, Vector2.ZERO)
	for s: float in [0.15, 75.45]:
		for d: float in [-0.45, 8.80]:
			r = r.expand(HAMAM_ORIGIN + HAMAM_U * s + HAMAM_N * d)
	return r.grow(margin)


static func _in_hamam_sunk_pit(wx: float, wz: float) -> bool:
	var rx: float = wx - HAMAM_ORIGIN.x
	var rz: float = wz - HAMAM_ORIGIN.y
	var ls: float = rx * HAMAM_U.x + rz * HAMAM_U.y
	var ld: float = rx * HAMAM_N.x + rz * HAMAM_N.y
	return ls >= 0.15 and ls <= 75.45 and ld >= -0.45 and ld <= 8.80


func _build_terrain_ground(rect: Rect2, th: TerrainHeight) -> void:
	# Zemin mesh'ini TerrainHeight ızgarasıyla birebir hizala (yollar ve binalarla 0.0 mm örtüşme).
	# Yeni Merkez Kütüphanesi (-3.5 m) ve Tarihi Hamam (-2.0 m) çökük avlularında zemin açılır.
	var has_merkez_pit: bool = rect.has_point(Vector2(-48.0, -198.0))
	var has_hamam_pit: bool = rect.has_point(Vector2(21.0, -133.0))
	var c0: int = clampi(floori((rect.position.x - th.min_x) / th.step), 0, th.cols - 2)
	var r0: int = clampi(floori((rect.position.y - th.min_z) / th.step), 0, th.rows - 2)
	var c1: int = clampi(ceili((rect.end.x - th.min_x) / th.step), c0 + 1, th.cols - 1)
	var r1: int = clampi(ceili((rect.end.y - th.min_z) / th.step), r0 + 1, th.rows - 1)
	var nx: int = c1 - c0 + 1
	var nz: int = r1 - r0 + 1

	var verts: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	verts.resize(nx * nz)
	normals.resize(nx * nz)
	uvs.resize(nx * nz)

	for r: int in nz:
		var gr: int = r0 + r
		var z: float = th.min_z + float(gr) * th.step
		for c: int in nx:
			var gc: int = c0 + c
			var x: float = th.min_x + float(gc) * th.step
			var idx: int = r * nx + c
			verts[idx] = Vector3(x, th.heights[gr * th.cols + gc], z)
			normals[idx] = th.normal_at(x, z)
			uvs[idx] = Vector2(x * 0.05, z * 0.05)

	var indices: PackedInt32Array = PackedInt32Array()
	for r: int in nz - 1:
		var z0: float = th.min_z + float(r0 + r) * th.step
		for c: int in nx - 1:
			var x0: float = th.min_x + float(c0 + c) * th.step
			var cx_cell: float = x0 + th.step * 0.5
			var cz_cell: float = z0 + th.step * 0.5
			var near_merkez: bool = has_merkez_pit and absf(cx_cell + 48.0) < 52.0 and absf(cz_cell + 198.0) < 52.0
			var near_hamam: bool = has_hamam_pit and HAMAM_PIT_AABB.intersects(Rect2(x0, z0, th.step, th.step), true)
			if near_merkez or near_hamam:
				var sub: int = 8
				var ds: float = th.step / float(sub)
				for sr: int in sub:
					var sz0: float = z0 + float(sr) * ds
					var sz1: float = sz0 + ds
					for sc: int in sub:
						var sx0: float = x0 + float(sc) * ds
						var sx1: float = sx0 + ds
						if near_merkez and (_in_merkez_sunk_pit(sx0, sz0) or _in_merkez_sunk_pit(sx1, sz0) or _in_merkez_sunk_pit(sx1, sz1) or _in_merkez_sunk_pit(sx0, sz1)):
							continue
						if near_hamam and (_in_hamam_sunk_pit(sx0, sz0) or _in_hamam_sunk_pit(sx1, sz0) or _in_hamam_sunk_pit(sx1, sz1) or _in_hamam_sunk_pit(sx0, sz1)):
							continue
						var base_vi: int = verts.size()
						for qpt: Vector2 in [Vector2(sx0, sz0), Vector2(sx1, sz0), Vector2(sx1, sz1), Vector2(sx0, sz1)]:
							verts.append(Vector3(qpt.x, th.height_at(qpt.x, qpt.y), qpt.y))
							normals.append(th.normal_at(qpt.x, qpt.y))
							uvs.append(Vector2(qpt.x * 0.05, qpt.y * 0.05))
						indices.append(base_vi)
						indices.append(base_vi + 1)
						indices.append(base_vi + 2)
						indices.append(base_vi)
						indices.append(base_vi + 2)
						indices.append(base_vi + 3)
				continue
			var i00: int = r * nx + c
			var i10: int = i00 + 1
			var i01: int = i00 + nx
			var i11: int = i01 + 1
			indices.append(i00)
			indices.append(i10)
			indices.append(i11)
			indices.append(i00)
			indices.append(i11)
			indices.append(i01)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var terrain_mesh: ArrayMesh = ArrayMesh.new()
	terrain_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	terrain_mesh.surface_set_material(0, _grass_material(GROUND_COLOR))

	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Ground"
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.shape = terrain_mesh.create_trimesh_shape()
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = terrain_mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(shape)
	body.add_child(mi)
	if has_merkez_pit:
		_add_merkez_sunk_ground_colliders(body)
	if has_hamam_pit:
		_add_hamam_sunk_ground_colliders(body)
	add_child(body)


static func _add_hamam_sunk_ground_colliders(body: StaticBody3D) -> void:
	# Tarihi Hamam -2.00 m çökük avlusu + 2 merdiven rampası (20.3°) + istinat/çit bariyerleri.
	var hxf: Transform3D = Transform3D(
		Basis(Vector3(HAMAM_U.x, 0.0, HAMAM_U.y), Vector3.UP, Vector3(HAMAM_N.x, 0.0, HAMAM_N.y)),
		Vector3(HAMAM_ORIGIN.x, 0.0, HAMAM_ORIGIN.y)
	)
	var boxes: Array = [
		# -2.00 m çökük taş avlu tabanı (s=0.15..75.45, d=-0.45..8.80)
		[Vector3(75.30, 0.50, 9.25), Vector3(37.80, HAMAM_SUNK_Y - 0.25, 4.175)],
		# Üst yol kenarı yaya kaldırımı sahanlığı (d=8.80..11.40, y=0.00)
		[Vector3(75.30, 0.50, 2.60), Vector3(37.80, HAMAM_UPPER_Y - 0.25, 10.10)],
		# Yol kenarı istinat + krem çit bariyerleri (merdiven açıklıkları s=11.2..15.6 ve s=35.8..39.8 hariç)
		[Vector3(11.05, 3.15, 0.34), Vector3(5.675, HAMAM_SUNK_Y + 1.575, 8.80)],
		[Vector3(20.20, 3.15, 0.34), Vector3(25.70, HAMAM_SUNK_Y + 1.575, 8.80)],
		[Vector3(35.65, 3.15, 0.34), Vector3(57.625, HAMAM_SUNK_Y + 1.575, 8.80)],
		# Sağ uç (s=75.45) ve sol köşe (s=0.15, d=5.2..8.8) yan istinat duvarları
		[Vector3(0.36, 3.15, 9.00), Vector3(75.45, HAMAM_SUNK_Y + 1.575, 4.30)],
		[Vector3(0.36, 3.15, 3.65), Vector3(0.15, HAMAM_SUNK_Y + 1.575, 6.98)],
		# Tarihi Hamam 3 ana bina kütlesi (navmesh engelleri)
		[Vector3(17.60, 9.20, 14.80), Vector3(8.80, 2.60, -7.40)],
		[Vector3(18.20, 10.20, 17.43), Vector3(26.70, 3.10, -8.235)],
		[Vector3(39.65, 6.40, 16.95), Vector3(55.625, 1.20, -8.475)],
	]
	for b_def: Array in boxes:
		var cs: CollisionShape3D = CollisionShape3D.new()
		var bs: BoxShape3D = BoxShape3D.new()
		bs.size = b_def[0]
		cs.shape = bs
		cs.transform = hxf * Transform3D(Basis.IDENTITY, b_def[1])
		body.add_child(cs)
	# ESLAB kahve minibüsü navmesh/fizik engeli (ana kapı solunda: s=5.65, d=3.35)
	var v_cs: CollisionShape3D = CollisionShape3D.new()
	var v_bs: BoxShape3D = BoxShape3D.new()
	v_bs.size = Vector3(2.22, 2.55, 5.25)
	v_cs.shape = v_bs
	v_cs.transform = hxf * Transform3D(Basis(Vector3.UP, deg_to_rad(-22.0)), Vector3(5.65, HAMAM_SUNK_Y + 1.28, 3.35))
	body.add_child(v_cs)
	# İki adet 20.3° yürüyüş merdiveni rampası (d=3.40 @ -2.00 m -> d=8.80 @ 0.00 m)
	var r_len: float = sqrt(5.40 * 5.40 + 2.00 * 2.00)
	var z_dir: Vector3 = Vector3(0.0, 2.00 / r_len, 5.40 / r_len)
	var y_dir: Vector3 = Vector3(0.0, 5.40 / r_len, -2.00 / r_len)
	for st_def: Array in [[13.40, 4.40], [37.80, 4.00]]:
		var r_cs: CollisionShape3D = CollisionShape3D.new()
		var r_bs: BoxShape3D = BoxShape3D.new()
		r_bs.size = Vector3(float(st_def[1]), 0.40, r_len)
		r_cs.shape = r_bs
		var r_mid: Vector3 = Vector3(float(st_def[0]), -1.00, 6.10) - y_dir * 0.20
		r_cs.transform = hxf * Transform3D(Basis(Vector3.RIGHT, y_dir, z_dir), r_mid)
		body.add_child(r_cs)


static func _add_merkez_sunk_ground_colliders(body: StaticBody3D) -> void:
	# Navmesh ve oyuncu fiziği için Yeni Merkez Kütüphanesi -1. kat çökük avlusu + sağ merdiven rampası + sol amfi + üst teras.
	var lxf: Transform3D = Transform3D(
		Basis(Vector3(MERKEZ_LIB_U.x, 0.0, MERKEZ_LIB_U.y), Vector3.UP, Vector3(MERKEZ_LIB_V.x, 0.0, MERKEZ_LIB_V.y)),
		Vector3(MERKEZ_LIB_ORIGIN.x, 0.0, MERKEZ_LIB_ORIGIN.y)
	)
	var boxes: Array = [
		# -1. kat çökük avlu tabanı (u=18.42..50.20, v=18.12..31.25, üst kot = MERKEZ_LIB_SUNK_Y)
		[Vector3(31.8, 0.5, 13.15), Vector3(34.31, MERKEZ_LIB_SUNK_Y - 0.25, 24.685)],
		# Üst gezinti terası (siyah cam küp önü: u=18.42..58.20, v=31.25..35.80)
		[Vector3(39.8, 0.9, 4.55), Vector3(38.31, MERKEZ_LIB_UPPER_Y - 0.45, 33.525)],
		# Merdiven başı üst sahanlık (u=58.20..62.60, v=18.12..35.80)
		[Vector3(4.4, 0.9, 17.68), Vector3(60.40, MERKEZ_LIB_UPPER_Y - 0.45, 26.96)],
		# İstinat duvarı + üst korkuluk bariyeri (v=31.25, u=18.42..58.20)
		[Vector3(39.78, 4.65, 0.36), Vector3(38.31, MERKEZ_LIB_SUNK_Y + 2.325, 31.25)],
	]
	# Sol taraftaki 6 ahşap amfi oturma basamağı (aşağı inerken solda: v=24.95..31.25, u=50.20..58.20)
	for ti: int in 6:
		var u_hi: float = 58.20 - float(ti) * (8.0 / 6.0)
		var u_lo: float = u_hi - (8.0 / 6.0)
		var y_seat: float = MERKEZ_LIB_UPPER_Y - float(ti + 1) * 0.50
		var h_seat: float = y_seat - (MERKEZ_LIB_SUNK_Y - 0.30)
		boxes.append([Vector3(8.0 / 6.0, h_seat, 6.30), Vector3((u_lo + u_hi) * 0.5, y_seat - h_seat * 0.5, 28.10)])
	for b_def: Array in boxes:
		var cs: CollisionShape3D = CollisionShape3D.new()
		var bs: BoxShape3D = BoxShape3D.new()
		bs.size = b_def[0]
		cs.shape = bs
		cs.transform = lxf * Transform3D(Basis.IDENTITY, b_def[1])
		body.add_child(cs)
	# Sağ taraftaki yürüyüş merdiveni eğimli rampa çarpıştırıcısı (u=50.20..58.20, v=18.12..24.95, 23.6° <= 45°)
	var r_len: float = sqrt(8.0 * 8.0 + 3.5 * 3.5)
	var t_dir: Vector3 = Vector3(8.0 / r_len, 3.5 / r_len, 0.0)
	var n_dir: Vector3 = Vector3(-3.5 / r_len, 8.0 / r_len, 0.0)
	var r_cs: CollisionShape3D = CollisionShape3D.new()
	var r_bs: BoxShape3D = BoxShape3D.new()
	r_bs.size = Vector3(r_len, 0.40, 6.83)
	r_cs.shape = r_bs
	var r_mid: Vector3 = Vector3(54.20, (MERKEZ_LIB_SUNK_Y + MERKEZ_LIB_UPPER_Y) * 0.5, 21.535) - n_dir * 0.20
	r_cs.transform = lxf * Transform3D(Basis(t_dir, n_dir, Vector3(0.0, 0.0, 1.0)), r_mid)
	body.add_child(r_cs)
	# Üst sahanlıktan doğal araziye yumuşak geçiş rampası (u=62.60..66.60, v=18.12..35.80)
	var o_len: float = sqrt(4.0 * 4.0 + 0.30 * 0.30)
	var ot_dir: Vector3 = Vector3(4.0 / o_len, -0.30 / o_len, 0.0)
	var on_dir: Vector3 = Vector3(0.30 / o_len, 4.0 / o_len, 0.0)
	var o_cs: CollisionShape3D = CollisionShape3D.new()
	var o_bs: BoxShape3D = BoxShape3D.new()
	o_bs.size = Vector3(o_len, 0.40, 17.68)
	o_cs.shape = o_bs
	var o_mid: Vector3 = Vector3(64.60, MERKEZ_LIB_UPPER_Y - 0.15, 26.96) - on_dir * 0.20
	o_cs.transform = lxf * Transform3D(Basis(ot_dir, on_dir, Vector3(0.0, 0.0, 1.0)), o_mid)
	body.add_child(o_cs)


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
	bm.material = _grass_material(GROUND_COLOR)
	mesh.mesh = bm
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(shape)
	body.add_child(mesh)
	add_child(body)


func _build_building(b: Dictionary) -> void:
	var poly: PackedVector2Array = to_polygon(b.get("points", []))
	var height: float = landmark_height(str(b.get("name", "")), float(b.get("height", 10.0)))
	var kind: String = str(b.get("kind", ""))
	# OSM building=roof: duvarsız sundurma/gölgelik (eskiden dolu kutu çiziliyordu)
	if kind == "roof":
		_build_canopy(poly, height)
		return
	# OSM building:min_level: binalar arası havada köprü — altı açık (eskiden yerden yükselip yolu kapatıyordu)
	var name_text: String = str(b.get("name", ""))
	var has_terrain: bool = TerrainHeight.enabled and TerrainHeight.active != null
	# Tarihi Hamam (b#49) ve içindeki isimsiz OSM alt-kütlesi (b#44), kampüs modunda TarihiHamam düğümüyle
	# -2.0 m çökük avludan yükselen gerçek 3 kütleli Osmanlı almaşık mimarisiyle inşa edilir.
	if has_terrain and (name_text == TARIHI_HAMAM_NAME or (name_text.is_empty() and poly.size() == 4 and poly[0].distance_to(HAMAM_ORIGIN) < 1.2)):
		building_count += 1
		return
	var is_merkez_lib: bool = name_text == MERKEZ_KUTUPHANE_NAME
	var min_h: float = clampf(float(b.get("min_height", 0.0)), 0.0, height - 1.0)
	var ref_y: float = MERKEZ_LIB_UPPER_Y if (has_terrain and is_merkez_lib) else (_polygon_avg_height(poly) if has_terrain else 0.0)
	var min_y: float = _polygon_min_height(poly) if has_terrain else 0.0
	var floor_y: float = -((ref_y - min_y) + BUILDING_FOUNDATION_M) if (has_terrain and min_h <= 0.0) else 0.0
	if has_terrain and is_merkez_lib:
		floor_y = minf(floor_y, -4.60)  # -1. kat çökük avlu (-3.50 m) tabanının altına kesintisiz duvar!
	# Sadece kutusu binanın kutusuyla kesişen yollar (kampüsün tamamında 300+ yol × 140 bina çok yavaştı).
	var near_paths: Array[PackedVector2Array] = _paths_near(_poly_box(poly).grow(GATE_TOUCH_DIST + 1.0))
	var no_paths: Array[PackedVector2Array] = []
	var mesh: ArrayMesh = extrude_polygon(poly, height - min_h, near_paths if min_h <= 0.0 else no_paths, floor_y)
	if min_h <= 0.0:
		gate_count += _count_gates(poly, near_paths)
	if mesh == null:
		push_warning("Bina üçgenlenemedi, atlandı: %s" % b.get("name", "?"))
		return

	var area: float = BuildingStyle.polygon_area(poly)
	var style: StringName = BuildingStyle.style_for(name_text, height, area, kind)
	var sdata: Dictionary = BuildingStyle.get_style_data(style)
	var colour: String = str(b.get("colour", ""))
	var wall_color: Color = Color.html(colour) if Color.html_is_valid(colour) else sdata["wall_color"]

	var is_kisla: bool = name_text == KISLA_NAME
	var is_mescit: bool = name_text == MESCIT_NAME
	var lojman_grp: String = str(LOJMAN_GROUPS.get(name_text, ""))
	var is_lojman: bool = not lojman_grp.is_empty()
	var unique_mat: bool = is_kisla or is_mescit or is_merkez_lib
	var mat_key: String = ("lojman|%s" % lojman_grp) if is_lojman else ("%s|%s" % [style, colour])
	var wall_mat: ShaderMaterial = _style_materials.get(mat_key) if not unique_mat and _style_materials.has(mat_key) else ShaderMaterial.new()
	if not unique_mat:
		_style_materials[mat_key] = wall_mat
	wall_mat.shader = BUILDING_WALL_SHADER
	if is_merkez_lib:
		wall_mat.set_shader_parameter("wall_color", Color(0.94, 0.94, 0.93))
		wall_mat.set_shader_parameter("window_color", Color(0.08, 0.12, 0.17))
		wall_mat.set_shader_parameter("frame_color", Color(0.09, 0.10, 0.12))
		wall_mat.set_shader_parameter("roof_color", Color(0.88, 0.89, 0.88))
		wall_mat.set_shader_parameter("style", 6)
		wall_mat.set_shader_parameter("lib_origin", Vector2(-74.33, -236.71))
		wall_mat.set_shader_parameter("lib_u", Vector2(0.8099, 0.5866))
		wall_mat.set_shader_parameter("lib_v", Vector2(-0.5866, 0.8099))
	elif is_lojman:
		var pal: Dictionary = LOJMAN_PALETTES[lojman_grp]
		wall_mat.set_shader_parameter("wall_color", pal["wall"])
		wall_mat.set_shader_parameter("window_color", Color(0.11, 0.15, 0.20))
		wall_mat.set_shader_parameter("frame_color", Color(0.14, 0.15, 0.17))
		wall_mat.set_shader_parameter("roof_color", pal["roof"])
		wall_mat.set_shader_parameter("style", 5)
	else:
		wall_mat.set_shader_parameter("wall_color", Color(0.78, 0.77, 0.71) if is_mescit else wall_color)
		wall_mat.set_shader_parameter("window_color", sdata["window_color"])
		wall_mat.set_shader_parameter("frame_color", sdata["frame_color"])
		wall_mat.set_shader_parameter("roof_color", Color(0.56, 0.54, 0.48) if is_mescit else sdata["roof_color"])
		wall_mat.set_shader_parameter("style", sdata["shader_style"])
		if is_mescit:
			wall_mat.set_shader_parameter("sparse_stone", true)
		if is_kisla and _courtyard_hull.size() >= 3:
			var cc: Vector2 = Vector2.ZERO
			for v: Vector2 in _courtyard_hull:
				cc += v
			wall_mat.set_shader_parameter("outer_stone", true)
			wall_mat.set_shader_parameter("courtyard_center", cc / float(_courtyard_hull.size()))

	mesh.surface_set_material(0, wall_mat)
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Building%d" % building_count
	body.position.y = ref_y + min_h
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	var shape: CollisionShape3D = CollisionShape3D.new()
	var trimesh: ConcavePolygonShape3D = mesh.create_trimesh_shape()
	trimesh.backface_collision = true
	shape.shape = trimesh
	if _batching and not unique_mat and min_h <= 0.0:
		_batch_mesh(mesh, wall_mat, _poly_box(poly).get_center(), ref_y, true)  # aynı stil + hücre → tek çizim
		mi.free()
	else:
		body.add_child(mi)
	body.add_child(shape)

	# Tarihi binalara ve OSM'de roof:shape=hipped/pyramidal olanlara kırma çatı
	var roof_shape: String = str(b.get("roof", ""))
	if style == BuildingStyle.STYLE_HISTORIC or roof_shape in ["hipped", "pyramidal"]:
		var roof_h: float = 1.35 if is_mescit else (2.5 if style == BuildingStyle.STYLE_HISTORIC else clampf(sqrt(area) * 0.12, 1.2, 3.0))
		var roof_mesh: ArrayMesh = build_hip_roof(poly, height - min_h, roof_h, 2.0)
		if roof_mesh != null:
			var roof_mat: StandardMaterial3D = _material(Color(0.56, 0.54, 0.48) if is_mescit else sdata["roof_color"])
			roof_mesh.surface_set_material(0, roof_mat)
			var roof_mi: MeshInstance3D = MeshInstance3D.new()
			roof_mi.name = "Roof"
			roof_mi.mesh = roof_mesh
			body.add_child(roof_mi)

	if show_labels and not name_text.is_empty() and min_h <= 0.0 and not CUSTOM_SIGN_BUILDINGS.has(name_text):
		# Havada asılı yazı yerine cepheye tabela: yola en yakın duvara, kapı hizasının üstüne.
		var sign: Node3D = build_sign(poly, height, near_paths, CampusMap.short_name(name_text), style == BuildingStyle.STYLE_HISTORIC)
		if sign != null:
			# Süs modeli tabela yeri verdiyse (ör. Büyük Ev: çatı alnı) oraya taşı: [x, y, z, yaw]
			landmark_decor("")
			var sp: Variant = (_landmarks.get("_signs", {}) as Dictionary).get(name_text)
			if sp is Array and (sp as Array).size() == 4:
				sign.position = Vector3(float(sp[0]), float(sp[1]), float(sp[2]))
				sign.rotation = Vector3(0.0, float(sp[3]), 0.0)
			body.add_child(sign)
	# Simge binalar: Blender'da üretilmiş süs modeli (korniş, baca, kubbe…; art/blender/landmarks.py).
	var decor: Node3D = landmark_decor(name_text)
	if decor != null:
		# Süs modelindeki "duvar" yüzeyleri binanın pencereli duvar malzemesini kullansın (ör. Kışla giriş bölümleri)
		apply_wall_material(decor, wall_mat)
		body.add_child(decor)
	# Tarihi binalarda (Kışla vb.) geçitlere taş kemer çerçevesi.
	if style == BuildingStyle.STYLE_HISTORIC:
		for portal: Node3D in build_portals(poly, near_paths, height):
			body.add_child(portal)
	add_child(body)
	building_count += 1



## Sundurma/gölgelik (OSM building=roof): ince çatı tablası + köşelerde ince direkler; altından geçilir.
const CANOPY_THICK: float = 0.3
const CANOPY_POST: float = 0.25
const CANOPY_COLOR: Color = Color(0.62, 0.64, 0.66)
const CANOPY_MAX_POSTS: int = 10


func _build_canopy(poly: PackedVector2Array, height: float) -> void:
	var slab: ArrayMesh = extrude_polygon(poly, CANOPY_THICK)
	if slab == null:
		return
	var has_terrain: bool = TerrainHeight.enabled and TerrainHeight.active != null
	var base_y: float = _polygon_avg_height(poly) if has_terrain else 0.0
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Canopy%d" % building_count
	body.position.y = base_y
	var mat: StandardMaterial3D = _shared_material(CANOPY_COLOR)
	slab.surface_set_material(0, mat)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = slab
	mi.position.y = height - CANOPY_THICK
	body.add_child(mi)
	var step: int = maxi(1, ceili(float(poly.size()) / CANOPY_MAX_POSTS))
	var post_extra: float = 1.5 if has_terrain else 0.0
	var post: BoxMesh = BoxMesh.new()
	post.size = Vector3(CANOPY_POST, height - CANOPY_THICK + post_extra, CANOPY_POST)
	post.material = mat
	var post_shape: BoxShape3D = BoxShape3D.new()
	post_shape.size = post.size
	for i: int in range(0, poly.size(), step):
		# köşeden içeri 0.4 m: direk tablanın altında kalsın
		var c: Vector2 = poly[i].lerp(_polygon_center(poly), clampf(0.4 / maxf(poly[i].distance_to(_polygon_center(poly)), 0.01), 0.0, 0.5))
		var p: MeshInstance3D = MeshInstance3D.new()
		p.mesh = post
		p.position = Vector3(c.x, (height - CANOPY_THICK) - post.size.y * 0.5, c.y)
		body.add_child(p)
		var cs: CollisionShape3D = CollisionShape3D.new()
		cs.shape = post_shape
		cs.position = p.position
		body.add_child(cs)
	add_child(body)
	building_count += 1


func _build_area(a: Dictionary) -> void:
	var poly: PackedVector2Array = to_polygon(a.get("points", []))
	var kind: String = str(a.get("kind", "grass"))
	var is_water: bool = str(a.get("name", "")).to_lower().contains("havuz")
	var is_parking: bool = kind == "parking"
	var has_terrain: bool = TerrainHeight.enabled and TerrainHeight.active != null
	var y_off: float = PARKING_Y if is_parking else AREA_Y
	var mesh: ArrayMesh
	if has_terrain and (is_water or kind == "pitch" or kind == "playground"):
		var ctr: Vector2 = _polygon_center(poly)
		mesh = flat_polygon_mesh(poly, TerrainHeight.active_height(ctr.x, ctr.y) + y_off, false)
	elif is_parking:
		mesh = flat_polygon_mesh(poly, y_off, has_terrain, PARKING_SUBDIV_M, 9)
	else:
		mesh = flat_polygon_mesh(poly, y_off, has_terrain)
	if mesh == null:
		return
	var color: Color = AREA_COLORS.get(kind, AREA_COLORS["grass"])
	var mat: Material = _water_material() if is_water \
		else (_get_parking_material() if is_parking \
		else (_grass_material(color) if GRASS_KINDS.has(kind) else _shared_material(color)))
	if _batching:
		_batch_mesh(mesh, mat, _poly_box(poly).get_center(), 0.0, false)
		return
	mesh.surface_set_material(0, mat)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # düz yüzey: gölge geçişinde boşa çizilmesin
	add_child(mi)


static func is_road_kind(kind: String) -> bool:
	return ROAD_KINDS.has(kind)


static func _path_layer(kind: String) -> int:
	if is_road_kind(kind):
		return 1
	if kind == "cycleway":
		return 2
	return 0


static func _path_y_for(kind: String) -> float:
	match kind:
		"residential":
			return ROAD_Y
		"residential_oneway":
			return ROAD_ONEWAY_Y
		"service":
			return SERVICE_Y
		"parking_aisle":
			return AISLE_Y
		"cycleway":
			return CYCLE_Y
		_:
			return PATH_Y


func _build_path(p: Dictionary) -> void:
	var raw_pts: PackedVector2Array = to_polygon(p.get("points", []))
	# Ardışık çok yakın düğümleri temizle (köşe birleştirmeyi bozmasın)
	var pts: PackedVector2Array = PackedVector2Array()
	for pt: Vector2 in raw_pts:
		if pts.is_empty() or pts[pts.size() - 1].distance_to(pt) >= 0.05:
			pts.append(pt)
	var m: int = pts.size()
	if m < 2:
		return
	var kind: String = str(p.get("kind", "footway"))
	var is_road: bool = is_road_kind(kind)
	var is_cycle: bool = kind == "cycleway"
	var base_w: float = PATH_WIDTHS.get(kind, 2.2)
	var half_w: float = base_w * 0.5
	var y_off: float = _path_y_for(kind)
	var has_terrain: bool = TerrainHeight.enabled and TerrainHeight.active != null

	# Her segment için yön, sol/sağ yarı-genişlik ve uzunluk.
	# Paralel zıt yönlü ana bulvarlarda (residential_oneway) iç kenar (UV.x=0) tam orta eksene genişler
	# (arada sahte çim şeridi kalmaz; iki yarı çift düz beyaz orta çizgide sıfır boşlukla birleşir).
	var seg_dirs: Array[Vector2] = []
	var seg_lefts: Array[Vector2] = []
	var seg_rights: Array[Vector2] = []
	var seg_widths: Array[float] = []
	var seg_lens: Array[float] = []
	var cum_s: Array[float] = [0.0]
	var is_boulevard_half: bool = false
	if kind == "residential_oneway" and not _oneway_segs.is_empty():
		var paired_segs: int = 0
		for i: int in m - 1:
			var d0: Vector2 = pts[i + 1] - pts[i]
			var L0: float = d0.length()
			var dn0: Vector2 = d0 / maxf(L0, 0.0001)
			var mid0: Vector2 = (pts[i] + pts[i + 1]) * 0.5
			var opp_d: float = _nearest_opposite_oneway(mid0, dn0, _current_path_idx)
			if opp_d >= 3.6 and opp_d <= 9.6:
				paired_segs += 1
		is_boulevard_half = paired_segs > 0

	for i: int in m - 1:
		var d: Vector2 = pts[i + 1] - pts[i]
		var L: float = d.length()
		var dn: Vector2 = d / maxf(L, 0.0001)
		var ortho: Vector2 = dn.orthogonal()  # sürücü solu (+UV.x=0 -> iç eksen)
		var w_l: float = half_w
		var w_r: float = half_w
		if is_boulevard_half:
			var mid0: Vector2 = (pts[i] + pts[i + 1]) * 0.5
			var opp_d: float = _nearest_opposite_oneway(mid0, dn, _current_path_idx)
			w_l = clampf(opp_d * 0.5, 2.3, 4.15) if (opp_d >= 3.6 and opp_d <= 9.6) else 3.2
			w_r = 2.60
		seg_dirs.append(dn)
		seg_lefts.append(ortho * w_l)
		seg_rights.append(ortho * w_r)
		seg_widths.append(w_l + w_r)
		seg_lens.append(L)
		cum_s.append(cum_s[i] + L)

	var width: float = seg_widths[0]
	# Segment uç kenar noktaları (yumuşak dönüşlerde sınırlandırılmış miter birleşimi, sert dönüşte köşe yelpazesi)
	var start_l: Array[Vector2] = []
	var start_r: Array[Vector2] = []
	var end_l: Array[Vector2] = []
	var end_r: Array[Vector2] = []
	for i: int in m - 1:
		start_l.append(pts[i] + seg_lefts[i])
		start_r.append(pts[i] - seg_rights[i])
		end_l.append(pts[i + 1] + seg_lefts[i])
		end_r.append(pts[i + 1] - seg_rights[i])

	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for i: int in range(1, m - 1):
		var d_prev: Vector2 = seg_dirs[i - 1]
		var d_next: Vector2 = seg_dirs[i]
		var dot_v: float = d_prev.dot(d_next)
		var wl_avg: float = (seg_lefts[i - 1].length() + seg_lefts[i].length()) * 0.5
		var wr_avg: float = (seg_rights[i - 1].length() + seg_rights[i].length()) * 0.5
		if dot_v > 0.25:
			var sum_s: Vector2 = seg_lefts[i - 1].normalized() + seg_lefts[i].normalized()
			if sum_s.length_squared() > 0.0001:
				var bis: Vector2 = sum_s.normalized()
				var denom: float = maxf(0.55, bis.dot(seg_lefts[i - 1].normalized()))
				var ml: Vector2 = pts[i] + bis * minf(wl_avg / denom, wl_avg * 1.35)
				var mr: Vector2 = pts[i] - bis * minf(wr_avg / denom, wr_avg * 1.35)
				end_l[i - 1] = ml
				start_l[i] = ml
				end_r[i - 1] = mr
				start_r[i] = mr
		else:
			# Sert dönüşlerde dış kenar boşluğunu 3 segmentli yuvarlak köşe yelpazesiyle kapat.
			# Godot Vector2.orthogonal() = (y, -x): turn_cross < 0 ise dış kenar sağ (-side), > 0 ise sol (+side).
			var turn_cross: float = d_prev.x * d_next.y - d_prev.y * d_next.x
			var outer_a: Vector2 = end_r[i - 1] if turn_cross < 0.0 else end_l[i - 1]
			var outer_b: Vector2 = start_r[i] if turn_cross < 0.0 else start_l[i]
			var edge_u: float = 1.0 if turn_cross < 0.0 else 0.0
			var r_fan: float = wr_avg if turn_cross < 0.0 else wl_avg
			_emit_path_corner_fan(st, pts[i], outer_a, outer_b, r_fan, edge_u, cum_s[i], seg_widths[i], y_off, has_terrain)

	# Segment şeritleri (eğime göre 3 m alt-bölüm, UV.y = gerçek metre)
	for i: int in m - 1:
		var seg_len: float = seg_lens[i]
		var seg_w: float = seg_widths[i]
		var subdiv: int = maxi(1, ceili(seg_len / PATH_SUBDIV_M)) if has_terrain else 1
		var s0_base: float = cum_s[i]
		for s: int in subdiv:
			var t0: float = float(s) / float(subdiv)
			var t1: float = float(s + 1) / float(subdiv)
			var p0: Vector2 = start_l[i].lerp(end_l[i], t0)
			var p1: Vector2 = start_r[i].lerp(end_r[i], t0)
			var p2: Vector2 = start_r[i].lerp(end_r[i], t1)
			var p3: Vector2 = start_l[i].lerp(end_l[i], t1)
			var sy0: float = s0_base + seg_len * t0
			var sy1: float = s0_base + seg_len * t1
			_emit_path_tri(st, p0, p2, p1, Vector2(0.0, sy0), Vector2(1.0, sy1), Vector2(1.0, sy0), seg_w, y_off, has_terrain)
			_emit_path_tri(st, p0, p3, p2, Vector2(0.0, sy0), Vector2(0.0, sy1), Vector2(1.0, sy1), seg_w, y_off, has_terrain)

	# Başlangıç ve bitiş yuvarlak uç kapakları: kavşak/birleşim düğümünde saf asfalt/parke ve alçak kot,
	# çıkmaz uçlarda bordürlü yuvarlak kapak.
	var layer: int = _path_layer(kind)
	var cap_r0: float = seg_rights[0].length()
	var cap_r1: float = seg_rights[m - 2].length()
	_emit_path_end_cap(st, pts[0], -seg_dirs[0], seg_lefts[0], cap_r0, cum_s[0], seg_widths[0], y_off, has_terrain, _is_shared_path_node(pts[0], layer) or is_boulevard_half, layer)
	_emit_path_end_cap(st, pts[m - 1], seg_dirs[m - 2], seg_lefts[m - 2], cap_r1, cum_s[m - 1], seg_widths[m - 2], y_off, has_terrain, _is_shared_path_node(pts[m - 1], layer) or is_boulevard_half, layer)

	var mesh: ArrayMesh = st.commit()
	if mesh.get_surface_count() == 0:
		return
	var mid: Vector2 = pts[m / 2]
	var asphalt_kind: String = "boulevard_half" if is_boulevard_half else kind
	var mat: Material = _get_asphalt_material(asphalt_kind) if is_road \
		else (_get_cycleway_material() if is_cycle \
		else _get_cobble_material(PATTERN_PINK_CONCRETE if in_courtyard(mid) else PATTERN_COBBLE))
	if _batching:
		_batch_mesh(mesh, mat, mid, 0.0, false)
		return
	mesh.surface_set_material(0, mat)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _index_path_nodes(paths: Array) -> void:
	_path_node_counts.clear()
	_oneway_segs.clear()
	for pi: int in paths.size():
		var p: Dictionary = paths[pi]
		var kind: String = str(p.get("kind", "footway"))
		var layer: int = _path_layer(kind)
		var seen: Dictionary = {}
		var pts_arr: Array = p.get("points", [])
		for pt: Array in pts_arr:
			var key: Vector3i = Vector3i(layer, roundi(float(pt[0]) * 4.0), roundi(float(pt[1]) * 4.0))
			if seen.has(key):
				continue
			seen[key] = true
			_path_node_counts[key] = int(_path_node_counts.get(key, 0)) + 1
		if kind == "residential_oneway":
			for k: int in pts_arr.size() - 1:
				var a: Vector2 = Vector2(float(pts_arr[k][0]), float(pts_arr[k][1]))
				var b: Vector2 = Vector2(float(pts_arr[k + 1][0]), float(pts_arr[k + 1][1]))
				var d: Vector2 = b - a
				var L: float = d.length()
				if L >= 1.0:
					_oneway_segs.append({"a": a, "b": b, "dir": d / L, "idx": pi})


func _nearest_opposite_oneway(pt: Vector2, dir: Vector2, own_idx: int) -> float:
	var best: float = INF
	var left_dir: Vector2 = dir.orthogonal()
	for s: Dictionary in _oneway_segs:
		if int(s["idx"]) == own_idx:
			continue
		if dir.dot(s["dir"] as Vector2) > -0.65:
			continue
		var cp: Vector2 = Geometry2D.get_closest_point_to_segment(pt, s["a"] as Vector2, s["b"] as Vector2)
		var rel: Vector2 = cp - pt
		# Yalnızca sürücünün SOLUNDA (iç eksende) duran karşı şeridi eşleştir
		if rel.dot(left_dir) <= 0.5:
			continue
		var dist: float = rel.length()
		if dist < best:
			best = dist
	return best


func _is_shared_path_node(pt: Vector2, layer: int) -> bool:
	var key: Vector3i = Vector3i(layer, roundi(pt.x * 4.0), roundi(pt.y * 4.0))
	return int(_path_node_counts.get(key, 0)) >= 2


static func _emit_path_tri(
	st: SurfaceTool,
	a: Vector2, b: Vector2, c: Vector2,
	ua: Vector2, ub: Vector2, uc: Vector2,
	width: float, y_off: float, has_terrain: bool, cap_flag: float = 0.0
) -> void:
	# Godot sağ el koordinatında saat yönü (+Y normal): ((c - a) x (b - a)).y > 0
	var cross_y: float = (c.y - a.y) * (b.x - a.x) - (c.x - a.x) * (b.y - a.y)
	if absf(cross_y) < 1e-6:
		return
	if cross_y < 0.0:
		var tmp_v: Vector2 = b
		b = c
		c = tmp_v
		var tmp_u: Vector2 = ub
		ub = uc
		uc = tmp_u
	var verts: Array[Vector2] = [a, b, c]
	var uvs: Array[Vector2] = [ua, ub, uc]
	for k: int in 3:
		var v: Vector2 = verts[k]
		var vy: float = (TerrainHeight.active_height(v.x, v.y) if has_terrain else 0.0) + y_off
		st.set_normal(TerrainHeight.active_normal(v.x, v.y) if has_terrain else Vector3.UP)
		st.set_uv(uvs[k])
		st.set_uv2(Vector2(width, cap_flag))
		st.add_vertex(Vector3(v.x, vy, v.y))


static func _emit_path_corner_fan(
	st: SurfaceTool,
	center: Vector2, outer_a: Vector2, outer_b: Vector2,
	half_w: float, edge_u: float, s_pos: float,
	width: float, y_off: float, has_terrain: bool
) -> void:
	var va: Vector2 = (outer_a - center).normalized()
	var vb: Vector2 = (outer_b - center).normalized()
	var total_arc: float = absf(va.angle_to(vb)) * half_w
	var prev: Vector2 = outer_a
	var prev_s: float = s_pos
	for k: int in range(1, 4):
		var f: float = float(k) / 3.0
		var dir: Vector2 = va.lerp(vb, f).normalized()
		var curr: Vector2 = outer_b if k == 3 else center + dir * half_w
		var curr_s: float = s_pos + total_arc * f
		_emit_path_tri(st, center, prev, curr, Vector2(0.5, s_pos), Vector2(edge_u, prev_s), Vector2(edge_u, curr_s), width, y_off, has_terrain)
		prev = curr
		prev_s = curr_s


static func _emit_path_end_cap(
	st: SurfaceTool,
	center: Vector2, out_dir: Vector2, side_vec: Vector2,
	half_w: float, s_pos: float,
	width: float, y_off: float, has_terrain: bool,
	is_junction: bool = false, layer: int = 0
) -> void:
	# Kavşak/birleşim uçlarında kapak hem ana şeridin altında hem de bordürsüz (cap_flag=1.0)
	# çizilir; böylece engebeli arazide dahi karşı yolu kesen bordür/çizgi görünmez.
	var j_sink: float = 0.015 if layer == 1 else (0.006 if layer == 2 else 0.008)
	var sink: float = j_sink if is_junction else 0.003
	var cap_y: float = y_off - sink
	var cap_flag: float = 1.0 if is_junction else 0.0
	var left_dir: Vector2 = side_vec.normalized()
	var steps: int = 4
	var prev: Vector2 = center + left_dir * half_w
	var prev_ang: float = 0.0
	for k: int in range(1, steps + 1):
		var ang: float = PI * float(k) / float(steps)  # 0: +left, PI/2: +out_dir, PI: -left
		var dir: Vector2 = left_dir * cos(ang) + out_dir * sin(ang)
		var curr: Vector2 = center + dir * half_w
		var edge_u: float = 0.0 if k <= steps / 2 else 1.0
		var s_a: float = s_pos + prev_ang * half_w
		var s_b: float = s_pos + ang * half_w
		_emit_path_tri(st, center, prev, curr, Vector2(0.5, s_pos), Vector2(edge_u, s_a), Vector2(edge_u, s_b), width, cap_y, has_terrain, cap_flag)
		prev = curr
		prev_ang = ang


var _shared_materials: Dictionary = {}
var _style_materials: Dictionary = {}  # bina stili -> ortak duvar ShaderMaterial
var _grass_materials: Dictionary = {}


const GRASS_NOISE_SIZE: int = 128
static var _grass_noise_tex: NoiseTexture2D


## Çim alacalığı için küçük, dikişsiz gürültü dokusu (oyun açılırken üretilir; repoda dosya yok).
static func _grass_noise() -> NoiseTexture2D:
	if _grass_noise_tex == null:
		var n: FastNoiseLite = FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.frequency = 0.03
		n.fractal_octaves = 3
		n.seed = 2405
		_grass_noise_tex = NoiseTexture2D.new()
		_grass_noise_tex.width = GRASS_NOISE_SIZE
		_grass_noise_tex.height = GRASS_NOISE_SIZE
		_grass_noise_tex.seamless = true
		_grass_noise_tex.generate_mipmaps = true
		_grass_noise_tex.noise = n
	return _grass_noise_tex


## Alacalı çim (aynı renk = aynı malzeme, birleştirmeye uygun).
func _grass_material(color: Color) -> ShaderMaterial:
	if not _grass_materials.has(color):
		var m: ShaderMaterial = ShaderMaterial.new()
		m.shader = GRASS_SHADER
		m.set_shader_parameter("base_color", color)
		m.set_shader_parameter("noise_tex", _grass_noise())
		_grass_materials[color] = m
	return _grass_materials[color]


## Aynı renk = aynı malzeme nesnesi (birleştirme anahtarı malzeme kimliği).
func _shared_material(color: Color) -> StandardMaterial3D:
	if not _shared_materials.has(color):
		_shared_materials[color] = _material(color)
	return _shared_materials[color]


func _batch_mesh(mesh: ArrayMesh, mat: Material, at: Vector2, y_offset: float = 0.0, cast_shadow: bool = false) -> void:
	var arr: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var uvs: Variant = arr[Mesh.ARRAY_TEX_UV]
	var idx: Variant = arr[Mesh.ARRAY_INDEX]
	var key: String = "%d|%d|%d|%d" % [mat.get_instance_id(), floori(at.x / BATCH_CELL), floori(at.y / BATCH_CELL), 1 if cast_shadow else 0]
	if not _batches.has(key):
		_batches[key] = {"mat": mat, "shadow": cast_shadow, "verts": PackedVector3Array(), "uvs": PackedVector2Array(), "uv2s": PackedVector2Array(), "normals": PackedVector3Array()}
	var b: Dictionary = _batches[key]
	var bv: PackedVector3Array = b["verts"]
	var bu: PackedVector2Array = b["uvs"]
	var bn: PackedVector3Array = b["normals"]
	var b2: PackedVector2Array = b["uv2s"]
	var uv2: Variant = arr[Mesh.ARRAY_TEX_UV2]
	var has_uv2: bool = uv2 is PackedVector2Array and not (uv2 as PackedVector2Array).is_empty()
	var nrm: Variant = arr[Mesh.ARRAY_NORMAL]
	var has_uv: bool = uvs is PackedVector2Array and not (uvs as PackedVector2Array).is_empty()
	var has_n: bool = nrm is PackedVector3Array and not (nrm as PackedVector3Array).is_empty()
	var order: PackedInt32Array = idx if idx is PackedInt32Array and not (idx as PackedInt32Array).is_empty() else PackedInt32Array(range(verts.size()))
	var shift: Vector3 = Vector3(0.0, y_offset, 0.0)
	for i: int in order:
		bv.append(verts[i] + shift)
		bu.append((uvs as PackedVector2Array)[i] if has_uv else Vector2.ZERO)
		bn.append((nrm as PackedVector3Array)[i] if has_n else Vector3.UP)
		b2.append((uv2 as PackedVector2Array)[i] if has_uv2 else Vector2.ZERO)
	b["uv2s"] = b2
	b["verts"] = bv
	b["uvs"] = bu
	b["normals"] = bn


func _flush_batches() -> void:
	for key: String in _batches:
		var b: Dictionary = _batches[key]
		var verts: PackedVector3Array = b["verts"]
		if verts.is_empty():
			continue
		var normals: PackedVector3Array = b["normals"]
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = b["uvs"]
		arrays[Mesh.ARRAY_TEX_UV2] = b["uv2s"]
		var mesh: ArrayMesh = ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, b["mat"])
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "Batch"
		mi.mesh = mesh
		if not bool(b.get("shadow", false)):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	_batches.clear()


static var _asphalt_materials: Dictionary = {}
static var _cycleway_material: ShaderMaterial
static var _parking_material: ShaderMaterial


static func _get_asphalt_material(kind: String = "service") -> ShaderMaterial:
	var variant: String = "boulevard_half" if kind == "boulevard_half" \
		else ("two_way" if kind == "residential" \
		else ("aisle" if kind == "parking_aisle" else "single"))
	if not _asphalt_materials.has(variant):
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = ROAD_ASPHALT_SHADER
		mat.set_shader_parameter("is_boulevard_half", variant == "boulevard_half")
		mat.set_shader_parameter("yellow_white_curb", variant == "two_way")
		mat.set_shader_parameter("draw_center_line", variant == "two_way")
		mat.set_shader_parameter("draw_curbs", variant != "aisle")
		_asphalt_materials[variant] = mat
	return _asphalt_materials[variant]


static func _get_cycleway_material() -> ShaderMaterial:
	if _cycleway_material == null:
		_cycleway_material = ShaderMaterial.new()
		_cycleway_material.shader = CYCLEWAY_SHADER
	return _cycleway_material


static func _get_parking_material() -> ShaderMaterial:
	if _parking_material == null:
		_parking_material = ShaderMaterial.new()
		_parking_material.shader = PARKING_LOT_SHADER
	return _parking_material


static func _get_cobble_material(pattern: int = PATTERN_COBBLE) -> ShaderMaterial:
	var key: int = pattern
	if not _cobble_materials.has(key):
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = PATH_COBBLE_SHADER
		mat.set_shader_parameter("pattern", pattern)
		_cobble_materials[key] = mat
	return _cobble_materials[key]


func _find_courtyard(data: Dictionary) -> void:
	for b: Dictionary in data.get("buildings", []):
		if str(b.get("name", "")) == KISLA_NAME:
			_courtyard_poly = to_polygon(b.get("points", []))
			_courtyard_hull = Geometry2D.convex_hull(_courtyard_poly)
			return


## Kışla'nın çevrelediği avlunun (Ortabahçe) içinde mi?
func in_courtyard(p: Vector2) -> bool:
	return _courtyard_hull.size() >= 3 and Geometry2D.is_point_in_polygon(p, _courtyard_hull) \
		and not Geometry2D.is_point_in_polygon(p, _courtyard_poly)


## Tarihi binalara kırma (hip) çatı mesh'i üretir.
## Çokgen ofseti başarısız olursa null döner (çağıran düz çatıda kalır).
static func build_hip_roof(poly: PackedVector2Array, base_height: float, roof_height: float = 2.5, depth: float = 2.0) -> ArrayMesh:
	var base_poly: PackedVector2Array = poly.duplicate()
	if Geometry2D.is_polygon_clockwise(base_poly):
		base_poly.reverse()

	var off: Array[PackedVector2Array] = Geometry2D.offset_polygon(base_poly, -depth)
	if off.is_empty():
		off = Geometry2D.offset_polygon(base_poly, -depth * 0.5)
	if off.is_empty():
		return null

	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)

	var has_geometry: bool = false

	for inner_poly: PackedVector2Array in off:
		if inner_poly.size() < 3:
			continue

		var hole_poly: PackedVector2Array = inner_poly.duplicate()
		if not Geometry2D.is_polygon_clockwise(hole_poly):
			hole_poly.reverse()

		var best_i: int = 0
		var best_j: int = 0
		var min_d_sq: float = INF
		for i: int in base_poly.size():
			for j: int in hole_poly.size():
				var d_sq: float = base_poly[i].distance_squared_to(hole_poly[j])
				if d_sq < min_d_sq:
					min_d_sq = d_sq
					best_i = i
					best_j = j

		var bridge_poly: PackedVector2Array = PackedVector2Array()
		var bridge_y: PackedFloat32Array = PackedFloat32Array()

		var n_base: int = base_poly.size()
		for k: int in n_base:
			var idx: int = (best_i + k) % n_base
			bridge_poly.append(base_poly[idx])
			bridge_y.append(base_height)
		bridge_poly.append(base_poly[best_i])
		bridge_y.append(base_height)

		var n_in: int = hole_poly.size()
		for k: int in n_in:
			var idx: int = (best_j + k) % n_in
			bridge_poly.append(hole_poly[idx])
			bridge_y.append(base_height + roof_height)
		bridge_poly.append(hole_poly[best_j])
		bridge_y.append(base_height + roof_height)

		bridge_poly.append(base_poly[best_i])
		bridge_y.append(base_height)

		var slope_tris: PackedInt32Array = Geometry2D.triangulate_polygon(bridge_poly)
		if slope_tris.is_empty():
			continue

		for t: int in range(0, slope_tris.size(), 3):
			var i0: int = slope_tris[t]
			var i1: int = slope_tris[t + 1]
			var i2: int = slope_tris[t + 2]
			var v0: Vector3 = Vector3(bridge_poly[i0].x, bridge_y[i0], bridge_poly[i0].y)
			var v1: Vector3 = Vector3(bridge_poly[i1].x, bridge_y[i1], bridge_poly[i1].y)
			var v2: Vector3 = Vector3(bridge_poly[i2].x, bridge_y[i2], bridge_poly[i2].y)
			var norm: Vector3 = (v2 - v0).cross(v1 - v0)
			if norm.y <= 0.0:
				st.add_vertex(v0)
				st.add_vertex(v2)
				st.add_vertex(v1)
			else:
				st.add_vertex(v0)
				st.add_vertex(v1)
				st.add_vertex(v2)

		var top_poly: PackedVector2Array = inner_poly.duplicate()
		if Geometry2D.is_polygon_clockwise(top_poly):
			top_poly.reverse()
		var top_tris: PackedInt32Array = Geometry2D.triangulate_polygon(top_poly)
		for t: int in range(0, top_tris.size(), 3):
			for k: int in [0, 1, 2]:
				var pt: Vector2 = top_poly[top_tris[t + k]]
				st.add_vertex(Vector3(pt.x, base_height + roof_height, pt.y))

		has_geometry = true

	if not has_geometry:
		return null

	st.generate_normals()
	return st.commit()



func _paths_near(box: Rect2) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for i: int in _path_lines.size():
		if _path_boxes[i].intersects(box, true):
			out.append(_path_lines[i])
	return out


static func _poly_box(poly: PackedVector2Array) -> Rect2:
	if poly.is_empty():
		return Rect2()
	var r: Rect2 = Rect2(poly[0], Vector2.ZERO)
	for v: Vector2 in poly:
		r = r.expand(v)
	return r


func _count_gates(poly: PackedVector2Array, paths: Array[PackedVector2Array]) -> int:
	var p: PackedVector2Array = poly.duplicate()
	if Geometry2D.is_polygon_clockwise(p):
		p.reverse()
	var total: int = 0
	for list: Array in find_gates(p, paths).values():
		total += list.size()
	return total


## OSM'de kat sayısı eksik/yanlış simge binalar için yükseklik (landmarks.json "heights"). Yoksa verilen.
static func landmark_height(building_name: String, fallback: float) -> float:
	landmark_decor("")  # manifest yüklensin
	return float((_landmarks.get("_heights", {}) as Dictionary).get(building_name, fallback))


## landmarks GLB'lerinde duvar rengindeki yüzey malzemeleri (make_landmarks.py COLORS anahtarı "lm_<ad>").
const DECOR_WALL_MATERIALS: PackedStringArray = ["lm_kisla_wall"]


static func apply_wall_material(node: Node, wall_mat: Material) -> void:
	for mi: Node in node.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (mi as MeshInstance3D).mesh
		for i: int in m.get_surface_count():
			var sm: Material = m.surface_get_material(i)
			if sm != null and DECOR_WALL_MATERIALS.has(sm.resource_name):
				(mi as MeshInstance3D).set_surface_override_material(i, wall_mat)


## Bina adı -> süs modeli (game/data/landmarks.json). Yoksa null.
static func landmark_decor(building_name: String) -> Node3D:
	if _landmarks.is_empty():
		var f: FileAccess = FileAccess.open(LANDMARKS_PATH, FileAccess.READ)
		_landmarks = {"_loaded": true}
		if f != null:
			var data: Variant = JSON.parse_string(f.get_as_text())
			if data is Dictionary:
				_landmarks.merge((data as Dictionary).get("buildings", {}))
				_landmarks["_heights"] = (data as Dictionary).get("heights", {})
				_landmarks["_signs"] = (data as Dictionary).get("signs", {})
	if building_name.is_empty():
		return null
	var path: String = str(_landmarks.get(building_name, ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var node: Node3D = (load(path) as PackedScene).instantiate() as Node3D
	node.name = "Landmark"
	return node


## landmarks.json "free" listesi: binaya bağlı olmayan süs modelleri (kapılar). Sahne koordinatlarında.
static func free_landmarks() -> Array[Node3D]:
	var out: Array[Node3D] = []
	var f: FileAccess = FileAccess.open(LANDMARKS_PATH, FileAccess.READ)
	if f == null:
		return out
	var data: Variant = JSON.parse_string(f.get_as_text())
	if not data is Dictionary:
		return out
	for path: Variant in (data as Dictionary).get("free", []):
		if ResourceLoader.exists(str(path)):
			var n: Node3D = (load(str(path)) as PackedScene).instantiate() as Node3D
			n.name = "Gate"
			out.append(n)
	return out


## Kenarın dışa bakan birim normali (XZ). Çokgen yönünden bağımsız: kenar ortasının hemen dışı çokgen dışında olmalı.
static func edge_outward(poly: PackedVector2Array, i: int) -> Vector2:
	var a: Vector2 = poly[i]
	var b: Vector2 = poly[(i + 1) % poly.size()]
	var n: Vector2 = (b - a).normalized().orthogonal()
	var mid: Vector2 = (a + b) * 0.5
	return n if not Geometry2D.is_point_in_polygon(mid + n * 0.3, poly) else -n


## Tabela için duvar seçimi: orta noktası yollara en yakın, yeterince uzun kenar. Kenar indeksi (-1 = yok).
static func sign_edge(poly: PackedVector2Array, paths: Array[PackedVector2Array], min_len: float) -> int:
	var best: int = -1
	var best_d: float = INF
	for i: int in poly.size():
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % poly.size()]
		if a.distance_to(b) < min_len:
			continue
		var mid: Vector2 = (a + b) * 0.5
		var d: float = 1e6 - a.distance_to(b)  # yol yoksa en uzun kenar
		for line: PackedVector2Array in paths:
			for j: int in line.size() - 1:
				d = minf(d, mid.distance_to(Geometry2D.get_closest_point_to_segment(mid, line[j], line[j + 1])))
		if d < best_d:
			best_d = d
			best = i
	return best


func build_sign(poly: PackedVector2Array, height: float, paths: Array[PackedVector2Array], text: String, historic: bool) -> Node3D:
	var width: float = SIGN_PAD + text.length() * SIGN_CHAR_W
	var i: int = sign_edge(poly, paths, width + 1.0)
	if i == -1:
		return null
	var a: Vector2 = poly[i]
	var b: Vector2 = poly[(i + 1) % poly.size()]
	var n: Vector2 = edge_outward(poly, i)
	var mid: Vector2 = (a + b) * 0.5 + n * SIGN_OFFSET
	var y: float = minf(SIGN_HEIGHT_M, height - SIGN_PANEL_H)
	var root: Node3D = Node3D.new()
	root.name = "Sign"
	root.position = Vector3(mid.x, y, mid.y)
	# Tabelanın önü (+Z) duvarın dışına baksın.
	root.rotation.y = atan2(n.x, n.y)
	var panel: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(width, SIGN_PANEL_H, 0.08)
	box.material = _material(SIGN_HISTORIC_COLOR if historic else SIGN_COLOR)
	panel.mesh = box
	panel.visibility_range_end = SIGN_VISIBLE_DISTANCE
	root.add_child(panel)
	var label: Label3D = Label3D.new()
	label.text = text
	label.font_size = 64
	label.pixel_size = 0.0085
	label.outline_size = 0
	label.modulate = Color(1, 0.97, 0.88)
	label.position = Vector3(0, 0, 0.05)
	label.double_sided = false
	label.visibility_range_end = SIGN_VISIBLE_DISTANCE
	root.add_child(label)
	return root


## Tarihi binanın geçitlerine iki sütun + üst kiriş (geçit açıklığının dış yüzünde).
func build_portals(poly: PackedVector2Array, paths: Array[PackedVector2Array], height: float) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var p: PackedVector2Array = poly.duplicate()
	if Geometry2D.is_polygon_clockwise(p):
		p.reverse()
	var gates: Dictionary = find_gates(p, paths)
	var mat: StandardMaterial3D = _material(PORTAL_COLOR)
	var pillar_h: float = minf(GATE_HEIGHT + PORTAL_BEAM_H, height)
	for i: int in gates:
		var a: Vector2 = p[i]
		var b: Vector2 = p[(i + 1) % p.size()]
		var dir: Vector2 = (b - a).normalized()
		var n: Vector2 = edge_outward(p, i)
		for t: float in gates[i]:
			var c: Vector2 = a.lerp(b, t) + n * (PORTAL_PILLAR.z * 0.5)
			var root: Node3D = Node3D.new()
			root.name = "Portal"
			root.position = Vector3(c.x, 0.0, c.y)
			root.rotation.y = atan2(n.x, n.y)
			for side: float in [-1.0, 1.0]:
				var pillar: MeshInstance3D = MeshInstance3D.new()
				var pm: BoxMesh = BoxMesh.new()
				pm.size = Vector3(PORTAL_PILLAR.x, pillar_h, PORTAL_PILLAR.z)
				pm.material = mat
				pillar.mesh = pm
				pillar.position = Vector3(side * (GATE_WIDTH * 0.5 + PORTAL_PILLAR.x * 0.5), pillar_h * 0.5, 0.0)
				root.add_child(pillar)
			var beam: MeshInstance3D = MeshInstance3D.new()
			var bm: BoxMesh = BoxMesh.new()
			bm.size = Vector3(GATE_WIDTH + PORTAL_PILLAR.x * 2.0, PORTAL_BEAM_H, PORTAL_PILLAR.z)
			bm.material = mat
			beam.mesh = bm
			beam.position = Vector3(0.0, GATE_HEIGHT + PORTAL_BEAM_H * 0.5, 0.0)
			root.add_child(beam)
			out.append(root)
	return out


static func _polygon_center(poly: PackedVector2Array) -> Vector2:
	var sum: Vector2 = Vector2.ZERO
	for v: Vector2 in poly:
		sum += v
	return sum / maxf(1.0, poly.size())


static func _polygon_avg_height(poly: PackedVector2Array) -> float:
	if poly.is_empty():
		return 0.0
	var total: float = 0.0
	for v: Vector2 in poly:
		total += TerrainHeight.active_height(v.x, v.y)
	return total / float(poly.size())


static func _polygon_min_height(poly: PackedVector2Array) -> float:
	if poly.is_empty():
		return 0.0
	var m: float = TerrainHeight.active_height(poly[0].x, poly[0].y)
	for i: int in range(1, poly.size()):
		m = minf(m, TerrainHeight.active_height(poly[i].x, poly[i].y))
	return m


static func _polygon_max_height(poly: PackedVector2Array) -> float:
	if poly.is_empty():
		return 0.0
	var m: float = TerrainHeight.active_height(poly[0].x, poly[0].y)
	for i: int in range(1, poly.size()):
		m = maxf(m, TerrainHeight.active_height(poly[i].x, poly[i].y))
	return m
