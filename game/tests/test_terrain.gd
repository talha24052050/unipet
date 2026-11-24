extends RefCounted
## Gerçek Davutpaşa arazi yüksekliği (TerrainHeight) ve kampus_terrain.json veri testleri.

const TERRAIN_PATH: String = "res://data/zones/kampus_terrain.json"


func test_bilinear_interpolation_and_clamping() -> String:
	var th: TerrainHeight = TerrainHeight.from_dict({
		"min_x": 0.0,
		"min_z": 0.0,
		"step": 10.0,
		"cols": 2,
		"rows": 2,
		"heights": [0.0, 10.0, 20.0, 30.0],
	})
	if not th.is_valid():
		return "2x2 arazi geçerli olmalı"
	if not is_equal_approx(th.height_at(0.0, 0.0), 0.0):
		return "köşe (0,0) 0 olmalı"
	if not is_equal_approx(th.height_at(10.0, 0.0), 10.0):
		return "köşe (10,0) 10 olmalı"
	if not is_equal_approx(th.height_at(5.0, 5.0), 15.0):
		return "orta nokta 15 olmalı: %f" % th.height_at(5.0, 5.0)
	if not is_equal_approx(th.height_at(-50.0, -50.0), 0.0):
		return "sınır dışı sol-üst 0'a sabitlenmeli"
	if not is_equal_approx(th.height_at(500.0, 500.0), 30.0):
		return "sınır dışı sağ-alt 30'a sabitlenmeli"
	return ""


func test_normal_on_slope_and_flat() -> String:
	var flat: TerrainHeight = TerrainHeight.from_dict({
		"min_x": 0.0, "min_z": 0.0, "step": 10.0, "cols": 2, "rows": 2,
		"heights": [5.0, 5.0, 5.0, 5.0],
	})
	if not flat.normal_at(5.0, 5.0).is_equal_approx(Vector3.UP):
		return "düz zeminde normal UP olmalı"

	var sloped: TerrainHeight = TerrainHeight.from_dict({
		"min_x": 0.0, "min_z": 0.0, "step": 10.0, "cols": 2, "rows": 2,
		"heights": [0.0, 10.0, 0.0, 10.0],
	})
	var n: Vector3 = sloped.normal_at(5.0, 5.0)
	if n.x >= -0.5 or n.y <= 0.5:
		return "+X yönünde yükselen eğimde normal -X'e eğilmeli: %s" % str(n)
	return ""


func test_active_height_respects_config_flag() -> String:
	var prev_active: TerrainHeight = TerrainHeight.active
	var prev_enabled: bool = TerrainHeight.enabled
	TerrainHeight.active = TerrainHeight.from_dict({
		"min_x": 0.0, "min_z": 0.0, "step": 10.0, "cols": 2, "rows": 2,
		"heights": [12.0, 12.0, 12.0, 12.0],
	})

	TerrainHeight.enabled = true
	var h_on: float = TerrainHeight.active_height(5.0, 5.0)
	TerrainHeight.enabled = false
	var h_off: float = TerrainHeight.active_height(5.0, 5.0)

	TerrainHeight.active = prev_active
	TerrainHeight.enabled = prev_enabled

	if not is_equal_approx(h_on, 12.0):
		return "TerrainHeight.enabled=true iken 12.0 dönmeli: %f" % h_on
	if not is_equal_approx(h_off, 0.0):
		return "TerrainHeight.enabled=false iken 0.0 dönmeli: %f" % h_off
	return ""


func test_kampus_terrain_data_valid_and_realistic() -> String:
	var th: TerrainHeight = TerrainHeight.load_from_file(TERRAIN_PATH)
	if th == null or not th.is_valid():
		return "kampus_terrain.json yüklenemedi veya geçersiz"
	var origin_h: float = th.height_at(0.0, 0.0)
	if absf(origin_h) > 0.2:
		return "Ortabahçe orijin yüksekliği ~0 m olmalı: %f" % origin_h
	var span: float = th.max_height() - th.min_height()
	if span < 5.0 or span > 120.0:
		return "Davutpaşa kot farkı gerçekçi aralıkta (5..120 m) olmalı: %f" % span
	return ""


func test_greybox_terrain_ground_building_and_path() -> String:
	var Greybox := preload("res://src/world/greybox_builder.gd")
	var prev_active: TerrainHeight = TerrainHeight.active
	var prev_enabled: bool = TerrainHeight.enabled
	TerrainHeight.enabled = true
	TerrainHeight.active = TerrainHeight.from_dict({
		"min_x": 0.0, "min_z": 0.0, "step": 20.0, "cols": 3, "rows": 3,
		"heights": [0.0, 5.0, 10.0, 0.0, 5.0, 10.0, 0.0, 5.0, 10.0],
	})

	var builder: Node3D = Greybox.new()
	builder.call("_build_ground_rect", Rect2(0.0, 0.0, 40.0, 40.0))
	var ground: Node = builder.get_node_or_null("Ground")
	if ground == null:
		builder.free()
		TerrainHeight.active = prev_active
		TerrainHeight.enabled = prev_enabled
		return "Terrain Ground düğümü oluşmadı"

	# Zemin mesh köşeleri eğime göre yükselmiş olmalı (0..10 m)
	var gmi: MeshInstance3D = null
	for ch: Node in ground.get_children():
		if ch is MeshInstance3D:
			gmi = ch as MeshInstance3D
	var gverts: PackedVector3Array = gmi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var max_gy: float = -1e9
	for v: Vector3 in gverts:
		max_gy = maxf(max_gy, v.y)
	if not is_equal_approx(max_gy, 10.0):
		builder.free()
		TerrainHeight.active = prev_active
		TerrainHeight.enabled = prev_enabled
		return "Zemin yüksekliği 10.0 m olmalı, %f bulundu" % max_gy

	# Eğimli yolda segment alt-bölünmeli, tüm üçgenler yukarı bakmalı ve UV.y gerçek metreyi taşımalı
	builder.call("_build_path", {"kind": "footway", "points": [[0.0, 10.0], [20.0, 10.0], [40.0, 20.0]]})
	var pmi: MeshInstance3D = null
	for ch: Node in builder.get_children():
		if ch is MeshInstance3D:
			pmi = ch as MeshInstance3D
	var parrays: Array = pmi.mesh.surface_get_arrays(0)
	var pverts: PackedVector3Array = parrays[Mesh.ARRAY_VERTEX]
	var puvs: PackedVector2Array = parrays[Mesh.ARRAY_TEX_UV]
	if pverts.size() <= 6:
		builder.free()
		TerrainHeight.active = prev_active
		TerrainHeight.enabled = prev_enabled
		return "40 m eğimli yol alt-bölünmeli (köşe sayısı: %d)" % pverts.size()
	var max_py: float = -1e9
	var max_uv_y: float = -1e9
	for ti: int in range(0, pverts.size(), 3):
		var fn: Vector3 = (pverts[ti + 2] - pverts[ti]).cross(pverts[ti + 1] - pverts[ti])
		if fn.y <= 0.0:
			builder.free()
			TerrainHeight.active = prev_active
			TerrainHeight.enabled = prev_enabled
			return "Yol üçgeni aşağı bakıyor (ters sarma yönü): %s" % str(fn)
	for vi: int in pverts.size():
		max_py = maxf(max_py, pverts[vi].y)
		max_uv_y = maxf(max_uv_y, puvs[vi].y)
	if max_py < 9.5 or max_uv_y < 35.0:
		builder.free()
		TerrainHeight.active = prev_active
		TerrainHeight.enabled = prev_enabled
		return "Yol yüksekliği (%.2f) veya UV.y uzunluğu (%.2f) hatalı" % [max_py, max_uv_y]

	# Eğimli çim alanı silinmemeli, alt-bölünerek araziye oturmalı
	var children_before: int = builder.get_child_count()
	builder.call("_build_area", {"kind": "park", "points": [[0.0, 0.0], [40.0, 0.0], [40.0, 40.0], [0.0, 40.0]]})
	if builder.get_child_count() <= children_before:
		builder.free()
		TerrainHeight.active = prev_active
		TerrainHeight.enabled = prev_enabled
		return "Eğimli park alanı silinmemeli, araziye oturtulmalı"

	# Eğimli binada temel aşağı uzamalı ve body.position.y > 0 olmalı
	builder.call("_build_building", {
		"name": "TestBina",
		"height": 8.0,
		"points": [[10.0, 10.0], [30.0, 10.0], [30.0, 30.0], [10.0, 30.0]],
	})
	var bnode: Node3D = builder.get_node_or_null("Building0") as Node3D
	var b_ok: bool = bnode != null and is_equal_approx(bnode.position.y, 5.0)
	builder.free()
	TerrainHeight.active = prev_active
	TerrainHeight.enabled = prev_enabled
	return "" if b_ok else "Eğimli bina doğru kotta yerleşmedi"


func test_props_and_lights_follow_terrain_height() -> String:
	var StreetLights := preload("res://src/world/street_lights.gd")
	var Greenery := preload("res://src/world/greenery_decor.gd")
	var prev_active: TerrainHeight = TerrainHeight.active
	var prev_enabled: bool = TerrainHeight.enabled
	TerrainHeight.enabled = true
	TerrainHeight.active = TerrainHeight.from_dict({
		"min_x": 0.0, "min_z": 0.0, "step": 20.0, "cols": 2, "rows": 2,
		"heights": [7.5, 7.5, 7.5, 7.5],
	})

	var sl: Node3D = StreetLights.new()
	sl.call("setup_lamps", {"props": [{"type": "lamp", "pos": [10.0, 10.0]}]})
	var lamp_pos: Array = sl.get("_lamp_positions")
	var lamp_y: float = (lamp_pos[0] as Vector3).y if not lamp_pos.is_empty() else -1.0
	sl.free()

	var gr: Node3D = Greenery.new()
	gr.call("build", {"kiosks": [[10.0, 10.0, 0.0]]})
	var kiosk: Node3D = gr.get_node_or_null("Kiosk") as Node3D
	var kiosk_y: float = kiosk.position.y if kiosk != null else -1.0
	gr.free()

	TerrainHeight.active = prev_active
	TerrainHeight.enabled = prev_enabled

	if not is_equal_approx(lamp_y, 7.5 + StreetLights.LAMP_HEIGHT):
		return "Sokak lambası arazi yüksekliğini takip etmiyor: %f" % lamp_y
	if not is_equal_approx(kiosk_y, 7.5):
		return "Büfe arazi yüksekliğini takip etmiyor: %f" % kiosk_y

	# Gerçek dönük (~15°) stadyum pisti: çizgiler pistin içinde kalmalı, yapılar tek birleşik mesh olmalı
	var gdata: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/zones/kampus_greenery.json"))
	var tr: Dictionary = ((gdata as Dictionary)["tracks"] as Array)[0]
	var gr_st: Node3D = Greenery.new()
	gr_st.call("build", {"tracks": [tr]})
	var details: Node3D = gr_st.get_node_or_null("StadiumDetails") as Node3D
	if details == null:
		gr_st.free()
		return "StadiumDetails oluşmadı"
	var has_bleachers: bool = details.get_node_or_null("StadiumBleachers") != null
	var lines_mi: MeshInstance3D = details.get_node_or_null("PitchLines") as MeshInstance3D
	var struct_mi: MeshInstance3D = details.get_node_or_null("StadiumStructures") as MeshInstance3D
	var has_lines: bool = lines_mi != null and lines_mi.mesh != null
	var has_struct: bool = struct_mi != null and struct_mi.mesh != null
	var mesh_count: int = 0
	for ch: Node in details.get_children():
		if ch is MeshInstance3D:
			mesh_count += 1
	# Tüm saha çizgi köşeleri gerçek inner pist çokgeninin içinde olmalı
	var inner_poly: PackedVector2Array = PackedVector2Array()
	for pt: Array in tr["inner"]:
		inner_poly.append(Vector2(float(pt[0]), float(pt[1])))
	var outside_cnt: int = 0
	if has_lines:
		var lv: PackedVector3Array = lines_mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for v: Vector3 in lv:
			var w: Vector3 = details.transform * v
			if not Geometry2D.is_point_in_polygon(Vector2(w.x, w.z), inner_poly):
				outside_cnt += 1
	gr_st.free()
	if not has_bleachers or not has_lines or not has_struct:
		return "Stadyum tribün/çizgi/yapı düğümleri eksik"
	if mesh_count != 2:
		return "Stadyum detayları 2 çizim çağrısı (PitchLines + StadiumStructures) olmalı, %d bulundu" % mesh_count
	if outside_cnt > 0:
		return "Stadyum saha çizgileri pistin dışına taşıyor (%d köşe dışarıda)" % outside_cnt
	return ""


func test_prebaked_kampus_navmesh_has_elevation() -> String:
	var nm: NavigationMesh = load("res://data/zones/kampus_navmesh.res") as NavigationMesh
	if nm == null or nm.get_polygon_count() == 0:
		return "kampus_navmesh.res yüklenemedi veya boş"
	var verts: PackedVector3Array = nm.get_vertices()
	if verts.is_empty():
		return "kampus_navmesh.res köşesiz"
	var min_y: float = INF
	var max_y: float = -INF
	for v: Vector3 in verts:
		min_y = minf(min_y, v.y)
		max_y = maxf(max_y, v.y)
	if (max_y - min_y) < 5.0:
		return "kampus_navmesh.res hâlâ düz görünüyor (Y aralığı: %.2f..%.2f)" % [min_y, max_y]
	return ""


func test_stadium_is_flat_and_asphalt_shader_valid() -> String:
	var th: TerrainHeight = TerrainHeight.load_from_file(TERRAIN_PATH)
	var gr: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/zones/kampus_greenery.json"))
	if th == null or not (gr is Dictionary):
		return "terrain veya greenery yüklenemedi"
	var tracks: Array = (gr as Dictionary).get("tracks", [])
	if tracks.is_empty():
		return "greenery içinde stadyum pisti yok"
	var outer: Array = (tracks[0] as Dictionary).get("outer", [])
	var lo: float = INF
	var hi: float = -INF
	for pt: Array in outer:
		var h: float = th.height_at(float(pt[0]), float(pt[1]))
		lo = minf(lo, h)
		hi = maxf(hi, h)
	if (hi - lo) > 0.25:
		return "Stadyum pisti düz olmalı, kot farkı %.2f m bulundu (%.2f..%.2f)" % [hi - lo, lo, hi]

	var shader: Shader = load("res://assets/shaders/road_asphalt.gdshader") as Shader
	if shader == null:
		return "road_asphalt.gdshader yüklenemedi"
	if load("res://assets/shaders/cycleway.gdshader") == null or load("res://assets/shaders/parking_lot.gdshader") == null:
		return "cycleway veya parking_lot shader yüklenemedi"

	# Kampüs ana araç yolları (residential), bisiklet yolları ve otoparklar eksiksiz olmalı
	var gb: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/zones/kampus_greybox.json"))
	if gb is Dictionary:
		var res_cnt: int = 0
		var cycle_cnt: int = 0
		for p: Dictionary in (gb as Dictionary).get("paths", []):
			var pk: String = str(p.get("kind", ""))
			if pk == "residential" or pk == "residential_oneway":
				res_cnt += 1
			elif pk == "cycleway":
				cycle_cnt += 1
		var park_cnt: int = 0
		for a: Dictionary in (gb as Dictionary).get("areas", []):
			if str(a.get("kind", "")) == "parking":
				park_cnt += 1
		if res_cnt < 50 or cycle_cnt < 8 or park_cnt < 25:
			return "Kampüs yol/otopark verisi eksik: residential=%d cycleway=%d parking=%d" % [res_cnt, cycle_cnt, park_cnt]
		for b: Dictionary in (gb as Dictionary).get("buildings", []):
			if str(b.get("name", "")) == "Yıldız Teknik Üniversitesi Davutpaşa Kışlası":
				var klo: float = INF
				var khi: float = -INF
				for pt: Array in b.get("points", []):
					var kh: float = th.height_at(float(pt[0]), float(pt[1]))
					klo = minf(klo, kh)
					khi = maxf(khi, kh)
				if (khi - klo) > 0.25:
					return "Taşbina (Kışla) tabanı düz olmalı, kot farkı %.2f m" % (khi - klo)
		# A101 karşısındaki otopark (merkez ~(-147, 11)) düz ve Taşbina (0.0 m) ile aynı seviyede olmalı
		var found_a101_park: bool = false
		for a: Dictionary in (gb as Dictionary).get("areas", []):
			if str(a.get("kind", "")) != "parking":
				continue
			var pts: Array = a.get("points", [])
			if pts.is_empty():
				continue
			var cx: float = 0.0
			var cz: float = 0.0
			for pt: Array in pts:
				cx += float(pt[0])
				cz += float(pt[1])
			cx /= float(pts.size())
			cz /= float(pts.size())
			if Vector2(cx, cz).distance_to(Vector2(-147.2, 11.1)) < 20.0:
				found_a101_park = true
				for pt: Array in pts:
					var ph: float = th.height_at(float(pt[0]), float(pt[1]))
					if absf(ph) > 0.10:
						return "A101 karşısı otopark Taşbina (0.0 m) kotunda düz olmalı, %.2f m bulundu" % ph
		if not found_a101_park:
			return "A101 karşısındaki otopark bulunamadı"
	return ""
