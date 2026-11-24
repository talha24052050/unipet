extends RefCounted
## Kampüs yer listesi (landmark) verisi testleri (ROADMAP 5.4 / Task 010).

const ALLOWED_KINDS: PackedStringArray = [
	"food",
	"faculty",
	"dorm",
	"sport",
	"landmark",
	"service",
	"gate",
	"transport",
]

const MIN_CAMPUS_X: float = -500.0
const MAX_CAMPUS_X: float = 900.0
const MIN_CAMPUS_Z: float = -700.0
const MAX_CAMPUS_Z: float = 850.0


func _load_places() -> Variant:
	var path: String = "res://data/places.json"
	if not FileAccess.file_exists(path):
		return null
	var text: String = FileAccess.get_file_as_string(path)
	return JSON.parse_string(text)


func test_places_file_loads_and_schema_valid() -> String:
	var data = _load_places()
	if data == null or not (data is Dictionary):
		return "places.json yüklenemedi veya sözlük değil"
	var places: Array = (data as Dictionary).get("places", [])
	if places.size() < 38:
		return "beklenenden az yer kaydı var: %d (en az 38 bekleniyordu)" % places.size()

	for i in range(places.size()):
		var p = places[i]
		if not (p is Dictionary):
			return "yer kaydı %d sözlük değil" % i
		var d: Dictionary = p as Dictionary
		for key: String in ["id", "name", "kind", "pos", "zone", "source"]:
			if not d.has(key):
				return "yer kaydı %d '%s' alanına sahip değil" % [i, key]

		var id: String = str(d["id"]).strip_edges()
		if id.is_empty():
			return "yer kaydı %d boş id içeriyor" % i

		var name: String = str(d["name"]).strip_edges()
		if name.is_empty():
			return "%s: boş isim içeriyor" % id

		var kind: String = str(d["kind"])
		if not ALLOWED_KINDS.has(kind):
			return "%s: geçersiz kind '%s'" % [id, kind]

		var source: String = str(d["source"])
		if source != "osm" and source != "manual":
			return "%s: geçersiz source '%s'" % [id, source]

		if source == "osm":
			var osm_name: String = str(d.get("osm_name", "")).strip_edges()
			if osm_name.is_empty():
				return "%s: osm kaynağı ancak osm_name boş" % id

		var pos: Array = d.get("pos", [])
		if pos.size() != 2:
			return "%s: pos 2 elemanlı değil" % id

	return ""


func test_places_ids_unique() -> String:
	var data = _load_places()
	if data == null or not (data is Dictionary):
		return "places.json yüklenemedi"
	var places: Array = (data as Dictionary).get("places", [])
	var seen: Dictionary = {}
	for p in places:
		var d: Dictionary = p as Dictionary
		var id: String = str(d.get("id", ""))
		if seen.has(id):
			return "mükerrer yer id bulundu: '%s'" % id
		seen[id] = true
	return ""


func test_places_within_campus_bounds() -> String:
	var data = _load_places()
	if data == null or not (data is Dictionary):
		return "places.json yüklenemedi"
	var places: Array = (data as Dictionary).get("places", [])
	for p in places:
		var d: Dictionary = p as Dictionary
		var id: String = str(d.get("id", ""))
		var pos: Array = d.get("pos", [])
		var x: float = float(pos[0])
		var z: float = float(pos[1])
		if x < MIN_CAMPUS_X or x > MAX_CAMPUS_X:
			return "%s: x koordinatı kampüs sınırları dışında (%f, sınır: [%f, %f])" % [
				id, x, MIN_CAMPUS_X, MAX_CAMPUS_X
			]
		if z < MIN_CAMPUS_Z or z > MAX_CAMPUS_Z:
			return "%s: z koordinatı kampüs sınırları dışında (%f, sınır: [%f, %f])" % [
				id, z, MIN_CAMPUS_Z, MAX_CAMPUS_Z
			]
	return ""


func test_required_landmarks_present_and_zoned() -> String:
	var data = _load_places()
	if data == null or not (data is Dictionary):
		return "places.json yüklenemedi"
	var places: Array = (data as Dictionary).get("places", [])
	var by_id: Dictionary = {}
	for p in places:
		var d: Dictionary = p as Dictionary
		by_id[str(d.get("id", ""))] = d

	var required: PackedStringArray = [
		"yemekhane",
		"ortabahce",
		"insaat_fakultesi",
		"ytu_stadyumu",
	]

	for req_id: String in required:
		if not by_id.has(req_id):
			return "zorunlu yer bulunamadı: '%s'" % req_id
		var place: Dictionary = by_id[req_id]
		var zone: String = str(place.get("zone", "")).strip_edges()
		if zone.is_empty():
			return "zorunlu yer bir bölgeye düşmüyor: '%s'" % req_id

	return ""


func test_all_place_spawns_outside_solid_buildings() -> String:
	var data = _load_places()
	var gb: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/zones/kampus_greybox.json"))
	if not (data is Dictionary) or not (gb is Dictionary):
		return "places.json veya kampus_greybox.json yüklenemedi"
	var polys: Array[PackedVector2Array] = []
	for b: Dictionary in (gb as Dictionary).get("buildings", []):
		if str(b.get("kind", "")) == "roof":
			continue
		var pts: Array = b.get("points", [])
		if pts.size() < 3:
			continue
		var poly: PackedVector2Array = PackedVector2Array()
		for pt: Array in pts:
			poly.append(Vector2(float(pt[0]), float(pt[1])))
		polys.append(poly)
	for p: Dictionary in (data as Dictionary).get("places", []):
		var id: String = str(p.get("id", ""))
		if not p.has("spawn"):
			return "%s: güvenli 'spawn' alanı eksik" % id
		var sp: Array = p["spawn"]
		if sp.size() != 2:
			return "%s: 'spawn' 2 elemanlı değil" % id
		var sxz: Vector2 = Vector2(float(sp[0]), float(sp[1]))
		for poly: PackedVector2Array in polys:
			if Geometry2D.is_point_in_polygon(sxz, poly):
				return "%s: spawn koordinatı (%s) hâlâ bir binanın içinde!" % [id, str(sxz)]
	return ""
