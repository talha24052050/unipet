extends RefCounted
## Parke yollar, kırmızı tuğla kenar ve klasik fener testleri (020).

const Greybox := preload("res://src/world/greybox_builder.gd")
const PropPlacer := preload("res://src/world/prop_placer.gd")
const LampMeshScript := preload("res://src/world/lamp_mesh.gd")
const PATH_COBBLE_SHADER_PATH: String = "res://assets/shaders/path_cobble.gdshader"


func test_path_cobble_shader_compiles() -> String:
	if not ResourceLoader.exists(PATH_COBBLE_SHADER_PATH):
		return "path_cobble.gdshader dosyası bulunamadı"
	var shader: Shader = load(PATH_COBBLE_SHADER_PATH) as Shader
	if shader == null:
		return "path_cobble.gdshader yüklenemedi veya derlenemedi"
	return ""


func test_pedestrian_path_uv_range_and_material() -> String:
	var pedestrian_kinds: Array[String] = ["footway", "path", "pedestrian"]
	for kind: String in pedestrian_kinds:
		var builder: Node3D = Greybox.new()
		var path_data: Dictionary = {
			"kind": kind,
			"points": [[0.0, 0.0], [10.0, 0.0], [20.0, 5.0]]
		}
		builder._build_path(path_data)

		var mi: MeshInstance3D = null
		for child: Node in builder.get_children():
			if child is MeshInstance3D:
				mi = child as MeshInstance3D
				break

		if mi == null or mi.mesh == null:
			builder.free()
			return "%s yolu için MeshInstance3D oluşturulamadı" % kind

		var mat: Material = mi.mesh.surface_get_material(0)
		if not mat is ShaderMaterial:
			builder.free()
			return "%s yolu ShaderMaterial kullanmalı, bulunan: %s" % [kind, mat]

		var sm: ShaderMaterial = mat as ShaderMaterial
		if sm.shader == null or sm.shader.resource_path != PATH_COBBLE_SHADER_PATH:
			builder.free()
			return "%s yolu path_cobble.gdshader kullanmalı" % kind

		var arr: Array = mi.mesh.surface_get_arrays(0)
		var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
		if uvs.is_empty():
			builder.free()
			return "%s yolu mesh'inde UV verisi eksik" % kind

		var min_u: float = INF
		var max_u: float = -INF
		for uv: Vector2 in uvs:
			min_u = minf(min_u, uv.x)
			max_u = maxf(max_u, uv.x)
			if uv.x < -0.001 or uv.x > 1.001:
				builder.free()
				return "%s yolu UV.x 0..1 sınırları dışında: %.4f" % [kind, uv.x]

		if absf(min_u - 0.0) > 0.01:
			builder.free()
			return "%s yolu min UV.x 0.0 olmalı, bulunan: %.4f" % [kind, min_u]
		if absf(max_u - 1.0) > 0.01:
			builder.free()
			return "%s yolu max UV.x 1.0 olmalı, bulunan: %.4f" % [kind, max_u]

		builder.free()
	return ""


func test_service_path_does_not_use_cobble_material() -> String:
	var builder: Node3D = Greybox.new()
	var path_data: Dictionary = {
		"kind": "service",
		"points": [[0.0, 0.0], [15.0, 0.0]]
	}
	builder._build_path(path_data)

	var mi: MeshInstance3D = null
	for child: Node in builder.get_children():
		if child is MeshInstance3D:
			mi = child as MeshInstance3D
			break

	if mi == null or mi.mesh == null:
		builder.free()
		return "service yolu için MeshInstance3D oluşturulamadı"

	var mat: Material = mi.mesh.surface_get_material(0)
	if mat is ShaderMaterial:
		var sm: ShaderMaterial = mat as ShaderMaterial
		if sm.shader != null and sm.shader.resource_path == PATH_COBBLE_SHADER_PATH:
			builder.free()
			return "service yolu cobble materyali KULLANMAMALI (asfalt kalmalı)"

	if not mat is StandardMaterial3D:
		builder.free()
		return "service yolu StandardMaterial3D kullanmalı"

	var std_mat: StandardMaterial3D = mat as StandardMaterial3D
	if std_mat.albedo_color != Greybox.SERVICE_PATH_COLOR:
		builder.free()
		return "service yolu SERVICE_PATH_COLOR kullanmalı"

	builder.free()
	return ""


func test_lamp_mesh_triangle_budget_and_height() -> String:
	var mesh: ArrayMesh = LampMeshScript.create_mesh()
	if mesh == null:
		return "LampMesh.create_mesh() null döndü"

	var total_tris: int = 0
	for s: int in range(mesh.get_surface_count()):
		var arr: Array = mesh.surface_get_arrays(s)
		if arr[Mesh.ARRAY_INDEX] != null and arr[Mesh.ARRAY_INDEX].size() > 0:
			total_tris += arr[Mesh.ARRAY_INDEX].size() / 3
		elif arr[Mesh.ARRAY_VERTEX] != null:
			total_tris += arr[Mesh.ARRAY_VERTEX].size() / 3

	if total_tris == 0:
		return "Fener mesh'inde hiç üçgen yok"
	if total_tris >= 300:
		return "Fener mesh'i < 300 üçgen bütçesini aştı: %d üçgen" % total_tris

	var aabb: AABB = mesh.get_aabb()
	var height: float = aabb.size.y
	if height < 3.0 or height > 4.5:
		return "Fener yüksekliği 3–4.5 m arasında olmalı, bulunan: %.2f m" % height

	# Yüzeyler ve materyal kontrolü: en az 2 yüzey (direk ve parlak küre)
	if mesh.get_surface_count() < 2:
		return "Fener mesh'inde direk ve küre için ayrı yüzeyler olmalı (surface_count >= 2)"

	var globe_mat: Material = mesh.surface_get_material(1)
	if not globe_mat is StandardMaterial3D:
		return "Küre materyali StandardMaterial3D olmalı"
	var sm: StandardMaterial3D = globe_mat as StandardMaterial3D
	if not sm.emission_enabled:
		return "Küre materyalinde gece için emission_enabled = true olmalı"

	return ""


func test_prop_placer_produces_mesh_for_lamp() -> String:
	var placer: Node3D = PropPlacer.new()
	var dummy_data: Dictionary = {
		"props": [
			{"type": "lamp", "pos": [15.0, 25.0], "yaw": 0.0, "scale": 1.0}
		]
	}
	placer.build_props(dummy_data)

	var lamp_mmi: MultiMeshInstance3D = null
	for child: Node in placer.get_children():
		if child is MultiMeshInstance3D and (child as MultiMeshInstance3D).name.begins_with("lamp_"):
			lamp_mmi = child as MultiMeshInstance3D
			break

	if lamp_mmi == null:
		placer.free()
		return "PropPlacer lamp için MultiMeshInstance3D üretmedi"

	if lamp_mmi.multimesh == null or lamp_mmi.multimesh.mesh == null:
		placer.free()
		return "PropPlacer lamp MultiMesh içinde mesh yok"

	var m: Mesh = lamp_mmi.multimesh.mesh
	var aabb: AABB = m.get_aabb()
	if aabb.size.y < 3.0 or aabb.size.y > 4.5:
		placer.free()
		return "PropPlacer lamp mesh yüksekliği 3–4.5 m arasında olmalı: %.2f m" % aabb.size.y

	placer.free()
	return ""
