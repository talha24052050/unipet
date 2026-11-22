extends RefCounted

const PropPlacer := preload("res://src/world/prop_placer.gd")
const Greybox := preload("res://src/world/greybox_builder.gd")
const ORTABAHCE_PROPS_DATA: String = "res://data/zones/ortabahce_props.json"
const ORTABAHCE_GREYBOX_DATA: String = "res://data/zones/ortabahce_greybox.json"
const KAMPUS_PROPS_DATA: String = "res://data/zones/kampus_props.json"
const KAMPUS_GREYBOX_DATA: String = "res://data/zones/kampus_greybox.json"
const PROPS_META: String = "res://../art/props.json"

const MAX_TOTAL_CAMPUS_TRIS: int = 1600000
const MAX_LOCAL_VIEW_TRIS: int = 300000
const LOCAL_VIEW_DISTANCE: float = 220.0


func test_ortabahce_props_data_loads() -> String:
	var d: Dictionary = PropPlacer.load_data(ORTABAHCE_PROPS_DATA)
	if d.is_empty():
		return "ortabahce_props.json yüklenemedi"
	var props: Array = d.get("props", [])
	if props.is_empty():
		return "Ortabahçe props dizisi boş"
	if props.size() < 100:
		return "Ortabahçe prop sayısı beklenenden az: %d" % props.size()
	return ""


func test_kampus_props_data_loads() -> String:
	var d: Dictionary = PropPlacer.load_data(KAMPUS_PROPS_DATA)
	if d.is_empty():
		return "kampus_props.json yüklenemedi"
	var props: Array = d.get("props", [])
	if props.is_empty():
		return "Kampüs props dizisi boş"
	if props.size() < 1000:
		return "Kampüs prop sayısı beklenenden az: %d" % props.size()

	var trees: int = 0
	var bushes: int = 0
	var benches: int = 0
	var lamps: int = 0
	var trashcans: int = 0

	for item_var: Variant in props:
		var item: Dictionary = item_var
		var t: String = str(item.get("type", ""))
		if t.begins_with("tree_"):
			trees += 1
		elif t.begins_with("bush_"):
			bushes += 1
		elif t == "bench":
			benches += 1
		elif t == "lamp":
			lamps += 1
		elif t == "trashcan":
			trashcans += 1

	if trees > 700:
		return "Kampüs ağaç sayısı sınırını aşıyor (<= 700): %d" % trees
	if bushes > 300:
		return "Kampüs çalı sayısı sınırını aşıyor (<= 300): %d" % bushes
	if benches > 250:
		return "Kampüs bank sayısı sınırını aşıyor (<= 250): %d" % benches
	if lamps > 200:
		return "Kampüs lamba sayısı sınırını aşıyor (<= 200): %d" % lamps

	return ""


func test_all_prop_types_have_glb() -> String:
	var seen_types: Dictionary = {}
	for path in [ORTABAHCE_PROPS_DATA, KAMPUS_PROPS_DATA]:
		var d: Dictionary = PropPlacer.load_data(path)
		for item_var: Variant in d.get("props", []):
			var item: Dictionary = item_var
			seen_types[str(item.get("type", ""))] = true

	for type: String in seen_types.keys():
		var glb_path: String = "res://assets/props/%s.glb" % type
		if not ResourceLoader.exists(glb_path):
			return "prop glb dosyası eksik: %s" % glb_path
		var scene: PackedScene = load(glb_path)
		if scene == null:
			return "prop glb yüklenemedi: %s" % glb_path
	return ""


func test_no_props_inside_buildings() -> String:
	for data_pair: Array in [
		[ORTABAHCE_PROPS_DATA, ORTABAHCE_GREYBOX_DATA, "ortabahce"],
		[KAMPUS_PROPS_DATA, KAMPUS_GREYBOX_DATA, "kampus"],
	]:
		var props_file: String = data_pair[0]
		var greybox_file: String = data_pair[1]
		var zone_label: String = data_pair[2]

		var props_dict: Dictionary = PropPlacer.load_data(props_file)
		var greybox_dict: Dictionary = Greybox.load_data(greybox_file)

		var buildings: Array = greybox_dict.get("buildings", [])
		var building_polys: Array[PackedVector2Array] = []
		var building_boxes: Array[Rect2] = []
		var building_names: Array[String] = []

		for b_var: Variant in buildings:
			var b: Dictionary = b_var
			var poly: PackedVector2Array = Greybox.to_polygon(b.get("points", []))
			building_polys.append(poly)
			building_boxes.append(_poly_bounds(poly))
			building_names.append(str(b.get("name", "")))

		for item_var: Variant in props_dict.get("props", []):
			var item: Dictionary = item_var
			var pos_arr: Array = item.get("pos", [0.0, 0.0])
			var pt := Vector2(float(pos_arr[0]), float(pos_arr[1]))

			for i: int in range(building_polys.size()):
				if not building_boxes[i].has_point(pt):
					continue
				if Geometry2D.is_point_in_polygon(pt, building_polys[i]):
					var bname: String = building_names[i]
					return "%s: prop bina içinde: %s (bina: '%s', pos: %s)" % [zone_label, item.get("type", "?"), bname, pt]
	return ""


func test_origin_clearance() -> String:
	for props_file in [ORTABAHCE_PROPS_DATA, KAMPUS_PROPS_DATA]:
		var props_dict: Dictionary = PropPlacer.load_data(props_file)
		for item_var: Variant in props_dict.get("props", []):
			var item: Dictionary = item_var
			var pos_arr: Array = item.get("pos", [0.0, 0.0])
			var pt := Vector2(float(pos_arr[0]), float(pos_arr[1]))
			if pt.length() < 6.0 - 0.01:
				return "%s: prop orijine 6 m'den yakın: %s pos=%s (mesafe=%.2f)" % [props_file, item.get("type", "?"), pt, pt.length()]
	return ""


func test_grid_cell_function() -> String:
	var test_cases: Array = [
		[Vector2(0.0, 0.0), Vector2i(0, 0)],
		[Vector2(50.0, 50.0), Vector2i(0, 0)],
		[Vector2(99.9, 99.9), Vector2i(0, 0)],
		[Vector2(100.0, 100.0), Vector2i(1, 1)],
		[Vector2(150.0, -50.0), Vector2i(1, -1)],
		[Vector2(-0.1, -0.1), Vector2i(-1, -1)],
		[Vector2(-100.0, 0.0), Vector2i(-1, 0)],
		[Vector2(-100.1, -100.1), Vector2i(-2, -2)],
		[Vector2(320.5, -450.2), Vector2i(3, -5)],
	]
	for tc: Array in test_cases:
		var input_pos: Vector2 = tc[0]
		var expected: Vector2i = tc[1]
		var actual: Vector2i = PropPlacer.get_cell(input_pos)
		if actual != expected:
			return "get_cell(%s) beklenen %s, dönen %s" % [input_pos, expected, actual]
	return ""


func test_kampus_triangle_budget() -> String:
	var props_dict: Dictionary = PropPlacer.load_data(KAMPUS_PROPS_DATA)
	var tris_map: Dictionary = _load_tris_map()
	if tris_map.is_empty():
		return "art/props.json üçgen tablosu yüklenemedi"

	var props: Array = props_dict.get("props", [])
	var total_tris: int = 0
	for item_var: Variant in props:
		var item: Dictionary = item_var
		var t: String = str(item.get("type", ""))
		if not tris_map.has(t):
			return "art/props.json'da üçgen sayısı bulunamadı: %s" % t
		total_tris += int(tris_map[t])

	if total_tris >= MAX_TOTAL_CAMPUS_TRIS:
		return "toplam üçgen sayısı %d sınırını aşıyor: %d" % [MAX_TOTAL_CAMPUS_TRIS, total_tris]

	# Tek bir oyuncu noktasından 220 m içindeki üçgen < 300.000 (Ortabahçe merkezi ve 3 rastgele nokta)
	var test_points: Array[Dictionary] = [
		{"name": "Ortabahçe merkezi", "pos": Vector2(0.0, 0.0)},
		{"name": "Rastgele 1 (200, 75)", "pos": Vector2(200.0, 75.0)},
		{"name": "Rastgele 2 (-150, 200)", "pos": Vector2(-150.0, 200.0)},
		{"name": "Rastgele 3 (400, -200)", "pos": Vector2(400.0, -200.0)},
	]

	for tp: Dictionary in test_points:
		var pt_name: String = str(tp["name"])
		var origin: Vector2 = tp["pos"]
		var local_tris: int = 0

		for item_var: Variant in props:
			var item: Dictionary = item_var
			var pos_arr: Array = item.get("pos", [0.0, 0.0])
			var prop_pt := Vector2(float(pos_arr[0]), float(pos_arr[1]))
			if prop_pt.distance_to(origin) <= LOCAL_VIEW_DISTANCE:
				var t: String = str(item.get("type", ""))
				local_tris += int(tris_map[t])

		if local_tris >= MAX_LOCAL_VIEW_TRIS:
			return "%s noktasından 220 m içindeki üçgen sayısı (%d) sınırı (%d) aşıyor" % [
				pt_name, local_tris, MAX_LOCAL_VIEW_TRIS
			]

	return ""


func test_prop_placer_builds_in_scene() -> String:
	var placer := PropPlacer.new()
	placer.data_path = KAMPUS_PROPS_DATA
	placer._ready()

	var static_body: StaticBody3D = placer.get_node_or_null("PropsStaticBody") as StaticBody3D
	if static_body == null:
		placer.free()
		return "PropsStaticBody oluşturulamadı"

	var col_count: int = static_body.get_child_count()
	if col_count == 0:
		placer.free()
		return "StaticBody altında çarpışma şekli yok"

	var multi_mesh_count: int = 0
	for child: Node in placer.get_children():
		if child is MultiMeshInstance3D:
			multi_mesh_count += 1
			var mmi := child as MultiMeshInstance3D
			var is_tree: bool = mmi.name.begins_with("tree_")
			var expected_end: float = PropPlacer.TREE_VISIBILITY_END if is_tree else PropPlacer.PROP_VISIBILITY_END

			if absf(mmi.visibility_range_end - expected_end) > 0.1:
				placer.free()
				return "%s visibility_range_end yanlış: beklenen %.1f, bulunan %.1f" % [mmi.name, expected_end, mmi.visibility_range_end]
			if absf(mmi.visibility_range_end_margin - PropPlacer.VISIBILITY_RANGE_MARGIN) > 0.1:
				placer.free()
				return "%s visibility_range_end_margin yanlış: beklenen %.1f, bulunan %.1f" % [mmi.name, PropPlacer.VISIBILITY_RANGE_MARGIN, mmi.visibility_range_end_margin]
			if mmi.visibility_range_fade_mode != GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF:
				placer.free()
				return "%s visibility_range_fade_mode FADE_SELF olmalı" % mmi.name

	if multi_mesh_count == 0:
		placer.free()
		return "MultiMeshInstance3D oluşturulamadı"

	placer.free()
	return ""


static func _load_tris_map() -> Dictionary:
	var meta_path: String = ProjectSettings.globalize_path(PROPS_META)
	var meta_file := FileAccess.open(meta_path, FileAccess.READ)
	if meta_file == null:
		return {}

	var meta_json: Variant = JSON.parse_string(meta_file.get_as_text())
	if not meta_json is Dictionary:
		return {}

	var tris_map: Dictionary = {}
	for p_var: Variant in (meta_json as Dictionary).get("props", []):
		var p: Dictionary = p_var
		tris_map[str(p.get("id", ""))] = int(p.get("tris", 0))
	return tris_map


static func _poly_bounds(poly: PackedVector2Array) -> Rect2:
	if poly.is_empty():
		return Rect2()
	var r := Rect2(poly[0], Vector2.ZERO)
	for pt: Vector2 in poly:
		r = r.expand(pt)
	return r
