extends RefCounted

const BuildingStyle := preload("res://src/world/building_style.gd")
const Greybox := preload("res://src/world/greybox_builder.gd")
const SHADER_PATH: String = "res://assets/shaders/building_wall.gdshader"


func test_style_for_historic() -> String:
	# Kışla
	if BuildingStyle.style_for("Yıldız Teknik Üniversitesi Davutpaşa Kışlası", 7.0, 14000.0) != BuildingStyle.STYLE_HISTORIC:
		return "Kışla historic olmalı"
	if BuildingStyle.style_for("Kışla", 7.0, 5000.0) != BuildingStyle.STYLE_HISTORIC:
		return "Kışla historic olmalı"
	if BuildingStyle.style_for("Davutpaşa Kışlası Mesciti", 7.0, 200.0) != BuildingStyle.STYLE_HISTORIC:
		return "Mescit historic olmalı"
	if BuildingStyle.style_for("Tarihi Hamam", 3.5, 1200.0) != BuildingStyle.STYLE_HISTORIC:
		return "Tarihi Hamam historic olmalı"
	if BuildingStyle.style_for("Otağ-ı Hümayun", 7.0, 450.0) != BuildingStyle.STYLE_HISTORIC:
		return "Otağ-ı Hümayun historic olmalı"
	if BuildingStyle.style_for("Taşbina", 7.0, 1000.0) != BuildingStyle.STYLE_HISTORIC:
		return "Taşbina historic olmalı"
	if BuildingStyle.style_for("Sanat ve Tasarım Fakültesi", 10.5, 2000.0) != BuildingStyle.STYLE_HISTORIC:
		return "Sanat ve Tasarım historic olmalı"
	if BuildingStyle.style_for("Sancak Köşkü", 7.0, 300.0) != BuildingStyle.STYLE_HISTORIC:
		return "Sancak Köşkü historic olmalı"
	if BuildingStyle.style_for("Davutpaşa Camii", 10.5, 500.0) != BuildingStyle.STYLE_HISTORIC:
		return "Cami historic olmalı"
	return ""


func test_style_for_dorm() -> String:
	# "C1 Blok" 5 kat -> dorm
	var h_5_floors: float = 5.0 * BuildingStyle.FLOOR_HEIGHT # 17.5m
	if BuildingStyle.style_for("C1 Blok", h_5_floors, 500.0) != BuildingStyle.STYLE_DORM:
		return "\"C1 Blok\" 5 kat dorm olmalı"
	if BuildingStyle.style_for("J3 Blok", 17.5, 700.0) != BuildingStyle.STYLE_DORM:
		return "\"J3 Blok\" 5 kat dorm olmalı"
	if BuildingStyle.style_for("Öğrenci Yurdu", 14.0, 600.0) != BuildingStyle.STYLE_DORM:
		return "Öğrenci Yurdu 4 kat dorm olmalı"
	if BuildingStyle.style_for("Lojman", 7.0, 400.0) != BuildingStyle.STYLE_DORM:
		return "Lojman dorm olmalı"
	# 3 kat Blok dorm olmamalı (fakülte binaları gibi)
	if BuildingStyle.style_for("C1 Blok", 3.0 * BuildingStyle.FLOOR_HEIGHT, 500.0) == BuildingStyle.STYLE_DORM:
		return "\"C1 Blok\" 3 kat dorm olmamalı"
	return ""


func test_style_for_modern() -> String:
	if BuildingStyle.style_for("Elektrik Elektronik Fakültesi", 10.5, 1947.0) != BuildingStyle.STYLE_MODERN:
		return "Elektrik Elektronik Fakültesi modern olmalı"
	if BuildingStyle.style_for("Eğitim Fakültesi", 14.0, 4400.0) != BuildingStyle.STYLE_MODERN:
		return "Eğitim Fakültesi modern olmalı"
	# Street View (2025-11-22): Yemekhane kırmızı tuğla + beyaz bant → kendi stili
	if BuildingStyle.style_for("Yemekhane", 14.0, 2300.0) != BuildingStyle.STYLE_BRICK:
		return "Yemekhane tuğla stili olmalı"
	if BuildingStyle.style_for("Elektrik Elektronik Fakültesi", 10.5, 3000.0) != BuildingStyle.STYLE_MODERN:
		return "EEF modern olmalı"
	return ""


func test_style_for_small() -> String:
	# adsız 3 kat küçük -> small
	var h_3_floors: float = 3.0 * BuildingStyle.FLOOR_HEIGHT # 10.5m
	if BuildingStyle.style_for("", h_3_floors, 100.0) != BuildingStyle.STYLE_SMALL:
		return "adsız 3 kat küçük small olmalı"
	if BuildingStyle.style_for("   ", 3.5, 50.0) != BuildingStyle.STYLE_SMALL:
		return "adsız 1 kat küçük small olmalı"
	# Adsız ama büyük bina (ör. 1500m2) modern olmalı
	if BuildingStyle.style_for("", 10.5, 1500.0) != BuildingStyle.STYLE_MODERN:
		return "adsız 3 kat büyük modern olmalı"
	return ""


func test_shader_compiles() -> String:
	var shader: Shader = load(SHADER_PATH)
	if shader == null:
		return "Shader yüklenemedi: %s" % SHADER_PATH
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("wall_color", BuildingStyle.HISTORIC_WALL)
	mat.set_shader_parameter("window_color", BuildingStyle.HISTORIC_WINDOW)
	mat.set_shader_parameter("frame_color", BuildingStyle.HISTORIC_FRAME)
	mat.set_shader_parameter("roof_color", BuildingStyle.HISTORIC_ROOF)
	mat.set_shader_parameter("style", BuildingStyle.SHADER_STYLE_HISTORIC)

	# Lojmanlar (style=5) ve Yeni Merkez Kütüphanesi (style=6) modlarını da doğrula
	for extra_style: int in [5, 6]:
		var m_extra: ShaderMaterial = ShaderMaterial.new()
		m_extra.shader = shader
		m_extra.set_shader_parameter("style", extra_style)
		if int(m_extra.get_shader_parameter("style")) != extra_style:
			return "building_wall style=%d atanamadı" % extra_style
	if Greybox.LOJMAN_GROUPS.size() != 11:
		return "LOJMAN_GROUPS 11 blok içermeli, %d bulundu" % Greybox.LOJMAN_GROUPS.size()

	var mi: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.material = mat
	mi.mesh = box

	# Sahne ağacında bir kare çiz / doğrula
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(64, 64)
	vp.add_child(mi)
	var cam: Camera3D = Camera3D.new()
	cam.position = Vector3(0, 0, 3)
	vp.add_child(cam)
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE

	mi.free()
	cam.free()
	vp.free()
	return ""


func test_hip_roof_mesh() -> String:
	var d: Dictionary = Greybox.load_data("res://data/zones/ortabahce_greybox.json")
	for b: Dictionary in d["buildings"]:
		var name: String = str(b.get("name", ""))
		if name.contains("Kışla") and not name.contains("Mescit"):
			var poly: PackedVector2Array = Greybox.to_polygon(b["points"])
			var roof_mesh: ArrayMesh = Greybox.build_hip_roof(poly, float(b["height"]), 2.5, 2.0)
			if roof_mesh == null:
				return "Kışla kırma çatı mesh'i üretilemedi"
			var verts: PackedVector3Array = roof_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			if verts.is_empty():
				return "Kışla çatı vertex boş"
			# En yüksek tepe noktası base_height + roof_height olmalı
			var max_y: float = -INF
			var min_y: float = INF
			for v: Vector3 in verts:
				max_y = maxf(max_y, v.y)
				min_y = minf(min_y, v.y)
			if absf(min_y - 7.0) > 0.01:
				return "Çatı tabanı 7.0m olmalı, bulunan: %f" % min_y
			if absf(max_y - 9.5) > 0.01:
				return "Çatı tepesi 9.5m olmalı, bulunan: %f" % max_y
			# Çatı normallerinin yukarı baktığını doğrula
			var norms: PackedVector3Array = roof_mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
			for norm: Vector3 in norms:
				if norm.y < -0.01:
					return "Çatı yüzeyinde aşağı bakan normal tespit edildi: %s" % norm
	return ""


func test_all_zones_build_greybox_no_errors() -> String:
	var zones_data: Dictionary = Greybox.load_data("res://data/zones/zones.json")
	var root: Node3D = Node3D.new()
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(64, 64)
	vp.add_child(root)

	for z: Dictionary in zones_data.get("zones", []):
		var path: String = str(z.get("greybox", ""))
		if path.is_empty():
			continue
		var gb = Greybox.new()
		gb.follow_current_zone = false
		gb.data_path = path
		root.add_child(gb)
		gb._ready()

		if gb.building_count == 0:
			gb.queue_free()
			root.free()
			vp.free()
			return "Bölgede bina kurulamadı: %s (%s)" % [z.get("id"), path]

		# Tarihi binaların çatı mesh'i olup olmadığını kontrol et
		var data: Dictionary = Greybox.load_data(path)
		for b: Dictionary in data.get("buildings", []):
			var bname: String = str(b.get("name", ""))
			var bh: float = float(b.get("height", 10.0))
			var bpts: PackedVector2Array = Greybox.to_polygon(b.get("points", []))
			var barea: float = BuildingStyle.polygon_area(bpts)
			var bstyle: StringName = BuildingStyle.style_for(bname, bh, barea)
			if bstyle == BuildingStyle.STYLE_HISTORIC:
				var found_roof: bool = false
				for child: Node in gb.get_children():
					if child is StaticBody3D and child.has_node("Roof"):
						var roof_node: MeshInstance3D = child.get_node("Roof") as MeshInstance3D
						if roof_node != null and roof_node.mesh != null:
							found_roof = true
							break
				if not found_roof:
					gb.queue_free()
					root.free()
					vp.free()
					return "Tarihi binada çatı bulunamadı: %s (bölge: %s)" % [bname, z.get("id")]

		root.remove_child(gb)
		gb.free()

	root.free()
	vp.free()
	return ""




