extends RefCounted

const PropPlacer := preload("res://src/world/prop_placer.gd")
const Greybox := preload("res://src/world/greybox_builder.gd")
const PROPS_DATA: String = "res://data/zones/ortabahce_props.json"
const GREYBOX_DATA: String = "res://data/zones/ortabahce_greybox.json"
const PROPS_META: String = "res://../art/props.json"


func test_props_data_loads() -> String:
	var d: Dictionary = PropPlacer.load_data(PROPS_DATA)
	if d.is_empty():
		return "ortabahce_props.json yüklenemedi"
	var props: Array = d.get("props", [])
	if props.is_empty():
		return "props dizisi boş"
	if props.size() < 100:
		return "prop sayısı beklenenden az: %d" % props.size()
	return ""


func test_all_prop_types_have_glb() -> String:
	var d: Dictionary = PropPlacer.load_data(PROPS_DATA)
	var props: Array = d.get("props", [])
	var seen_types: Dictionary = {}
	for item_var: Variant in props:
		var item: Dictionary = item_var
		var t: String = str(item.get("type", ""))
		seen_types[t] = true

	for type: String in seen_types.keys():
		var path: String = "res://assets/props/%s.glb" % type
		if not ResourceLoader.exists(path):
			return "prop glb dosyası eksik: %s" % path
		var scene: PackedScene = load(path)
		if scene == null:
			return "prop glb yüklenemedi: %s" % path
	return ""


func test_no_props_inside_buildings() -> String:
	var props_dict: Dictionary = PropPlacer.load_data(PROPS_DATA)
	var greybox_dict: Dictionary = Greybox.load_data(GREYBOX_DATA)

	var buildings: Array = greybox_dict.get("buildings", [])
	var building_polys: Array[PackedVector2Array] = []
	var building_names: Array[String] = []
	for b_var: Variant in buildings:
		var b: Dictionary = b_var
		building_polys.append(Greybox.to_polygon(b.get("points", [])))
		building_names.append(str(b.get("name", "")))

	for item_var: Variant in props_dict.get("props", []):
		var item: Dictionary = item_var
		var pos_arr: Array = item.get("pos", [0.0, 0.0])
		var pt := Vector2(float(pos_arr[0]), float(pos_arr[1]))
		for i: int in range(building_polys.size()):
			if Geometry2D.is_point_in_polygon(pt, building_polys[i]):
				var bname: String = building_names[i]
				return "prop bina içinde: %s (bina: '%s', pos: %s)" % [item.get("type", "?"), bname, pt]
	return ""


func test_origin_clearance() -> String:
	var props_dict: Dictionary = PropPlacer.load_data(PROPS_DATA)
	for item_var: Variant in props_dict.get("props", []):
		var item: Dictionary = item_var
		var pos_arr: Array = item.get("pos", [0.0, 0.0])
		var pt := Vector2(float(pos_arr[0]), float(pos_arr[1]))
		if pt.length() < 6.0 - 0.01:
			return "prop orijine 6 m'den yakın: %s pos=%s (mesafe=%.2f)" % [item.get("type", "?"), pt, pt.length()]
	return ""


func test_triangle_budget() -> String:
	var props_dict: Dictionary = PropPlacer.load_data(PROPS_DATA)
	var meta_path: String = ProjectSettings.globalize_path(PROPS_META)
	var meta_file := FileAccess.open(meta_path, FileAccess.READ)
	if meta_file == null:
		return "art/props.json açılamadı: %s" % meta_path

	var meta_json: Variant = JSON.parse_string(meta_file.get_as_text())
	if not meta_json is Dictionary:
		return "art/props.json parse edilemedi"

	var tris_map: Dictionary = {}
	for p_var: Variant in (meta_json as Dictionary).get("props", []):
		var p: Dictionary = p_var
		tris_map[str(p.get("id", ""))] = int(p.get("tris", 0))

	var total_tris: int = 0
	for item_var: Variant in props_dict.get("props", []):
		var item: Dictionary = item_var
		var t: String = str(item.get("type", ""))
		if not tris_map.has(t):
			return "art/props.json'da üçgen sayısı bulunamadı: %s" % t
		total_tris += int(tris_map[t])

	if total_tris >= 250000:
		return "toplam üçgen sayısı 250.000 sınırını aşıyor: %d" % total_tris

	return ""


func test_prop_placer_builds_in_scene() -> String:
	var placer := PropPlacer.new()
	placer.data_path = PROPS_DATA
	# Simulate ready
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

	if multi_mesh_count == 0:
		placer.free()
		return "MultiMeshInstance3D oluşturulamadı"

	placer.free()
	return ""
