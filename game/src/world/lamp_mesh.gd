class_name LampMesh
extends RefCounted
## Klasik Davutpaşa sokak feneri mesh'i üretir.
## Siyah ince direk (~3.6 m, alt kaide kalın), üstte beyaz/krem küre (r≈0.25 m, emission).
## Toplam üçgen sayısı < 300, mobile renderer uyumlu.

const TOTAL_HEIGHT: float = 3.60
const GLOBE_RADIUS: float = 0.25
const GLOBE_CENTER_Y: float = 3.35

const POLE_COLOR: Color = Color(0.12, 0.12, 0.14)
const GLOBE_COLOR: Color = Color(0.98, 0.96, 0.90)
const GLOBE_EMISSION: Color = Color(1.0, 0.95, 0.85)

const POLE_RADIAL_SEGMENTS: int = 8
const GLOBE_RADIAL_SEGMENTS: int = 12
const GLOBE_RINGS: int = 6


static func create_mesh() -> ArrayMesh:
	var mesh: ArrayMesh = ArrayMesh.new()

	# 1. Yüzey: Siyah metal kaide, ince direk ve küre çanağı
	var st_pole := SurfaceTool.new()
	st_pole.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Kaide ve direk yükseklik halkaları: [y, radius]
	var rings: Array[Vector2] = [
		Vector2(0.0, 0.16),    # Zemin kaide tabanı
		Vector2(0.40, 0.13),   # Kaide üstü
		Vector2(0.52, 0.06),   # Kaide bileziği
		Vector2(3.20, 0.045),  # İnce direk gövde üstü
		Vector2(3.30, 0.09),   # Küre taşıyıcı çanak
	]

	var n_rings: int = rings.size()
	for r_idx: int in range(n_rings - 1):
		var y0: float = rings[r_idx].x
		var rad0: float = rings[r_idx].y
		var y1: float = rings[r_idx + 1].x
		var rad1: float = rings[r_idx + 1].y

		for s: int in range(POLE_RADIAL_SEGMENTS):
			var a0: float = float(s) * TAU / float(POLE_RADIAL_SEGMENTS)
			var a1: float = float(s + 1) * TAU / float(POLE_RADIAL_SEGMENTS)

			var c0: float = cos(a0)
			var s0: float = sin(a0)
			var c1: float = cos(a1)
			var s1: float = sin(a1)

			var v00 := Vector3(c0 * rad0, y0, s0 * rad0)
			var v10 := Vector3(c1 * rad0, y0, s1 * rad0)
			var v01 := Vector3(c0 * rad1, y1, s0 * rad1)
			var v11 := Vector3(c1 * rad1, y1, s1 * rad1)

			var n0 := Vector3(c0, 0.0, s0)
			var n1 := Vector3(c1, 0.0, s1)

			# İki üçgen (dışa bakan CCW sarım)
			st_pole.set_normal(n0)
			st_pole.add_vertex(v00)
			st_pole.set_normal(n1)
			st_pole.add_vertex(v10)
			st_pole.set_normal(n1)
			st_pole.add_vertex(v11)

			st_pole.set_normal(n0)
			st_pole.add_vertex(v00)
			st_pole.set_normal(n1)
			st_pole.add_vertex(v11)
			st_pole.set_normal(n0)
			st_pole.add_vertex(v01)

	# Kaide alt kapak (y = 0.0, aşağı bakan)
	var bottom_y: float = rings[0].x
	var bottom_rad: float = rings[0].y
	var center_bottom := Vector3(0.0, bottom_y, 0.0)
	st_pole.set_normal(Vector3.DOWN)
	for s: int in range(POLE_RADIAL_SEGMENTS):
		var a0: float = float(s) * TAU / float(POLE_RADIAL_SEGMENTS)
		var a1: float = float(s + 1) * TAU / float(POLE_RADIAL_SEGMENTS)
		var v0 := Vector3(cos(a0) * bottom_rad, bottom_y, sin(a0) * bottom_rad)
		var v1 := Vector3(cos(a1) * bottom_rad, bottom_y, sin(a1) * bottom_rad)
		st_pole.add_vertex(center_bottom)
		st_pole.add_vertex(v0)
		st_pole.add_vertex(v1)

	mesh = st_pole.commit()

	var pole_mat := StandardMaterial3D.new()
	pole_mat.albedo_color = POLE_COLOR
	pole_mat.metallic = 0.6
	pole_mat.roughness = 0.4
	mesh.surface_set_material(0, pole_mat)

	# 2. Yüzey: Beyaz/krem küre başlık (r ≈ 0.25 m)
	var st_globe := SurfaceTool.new()
	st_globe.begin(Mesh.PRIMITIVE_TRIANGLES)

	var center := Vector3(0.0, GLOBE_CENTER_Y, 0.0)

	for lat_idx: int in range(GLOBE_RINGS):
		var phi0: float = -PI * 0.5 + float(lat_idx) * PI / float(GLOBE_RINGS)
		var phi1: float = -PI * 0.5 + float(lat_idx + 1) * PI / float(GLOBE_RINGS)

		var y0: float = sin(phi0) * GLOBE_RADIUS
		var r0: float = cos(phi0) * GLOBE_RADIUS
		var y1: float = sin(phi1) * GLOBE_RADIUS
		var r1: float = cos(phi1) * GLOBE_RADIUS

		for lon_idx: int in range(GLOBE_RADIAL_SEGMENTS):
			var theta0: float = float(lon_idx) * TAU / float(GLOBE_RADIAL_SEGMENTS)
			var theta1: float = float(lon_idx + 1) * TAU / float(GLOBE_RADIAL_SEGMENTS)

			var p00 := center + Vector3(cos(theta0) * r0, y0, sin(theta0) * r0)
			var p10 := center + Vector3(cos(theta1) * r0, y0, sin(theta1) * r0)
			var p01 := center + Vector3(cos(theta0) * r1, y1, sin(theta0) * r1)
			var p11 := center + Vector3(cos(theta1) * r1, y1, sin(theta1) * r1)

			var n00 := (p00 - center).normalized()
			var n10 := (p10 - center).normalized()
			var n01 := (p01 - center).normalized()
			var n11 := (p11 - center).normalized()

			if lat_idx == 0:
				# Güney kutbu kapağı
				st_globe.set_normal(n00)
				st_globe.add_vertex(p00)
				st_globe.set_normal(n01)
				st_globe.add_vertex(p01)
				st_globe.set_normal(n11)
				st_globe.add_vertex(p11)
			elif lat_idx == GLOBE_RINGS - 1:
				# Kuzey kutbu kapağı
				st_globe.set_normal(n00)
				st_globe.add_vertex(p00)
				st_globe.set_normal(n10)
				st_globe.add_vertex(p10)
				st_globe.set_normal(n01)
				st_globe.add_vertex(p01)
			else:
				# Dörtgen (iki üçgen)
				st_globe.set_normal(n00)
				st_globe.add_vertex(p00)
				st_globe.set_normal(n10)
				st_globe.add_vertex(p10)
				st_globe.set_normal(n11)
				st_globe.add_vertex(p11)

				st_globe.set_normal(n00)
				st_globe.add_vertex(p00)
				st_globe.set_normal(n11)
				st_globe.add_vertex(p11)
				st_globe.set_normal(n01)
				st_globe.add_vertex(p01)

	st_globe.commit(mesh)

	var globe_mat := StandardMaterial3D.new()
	globe_mat.albedo_color = GLOBE_COLOR
	globe_mat.emission_enabled = true
	globe_mat.emission = GLOBE_EMISSION
	globe_mat.emission_energy_multiplier = 0.8
	globe_mat.roughness = 0.2
	globe_mat.metallic = 0.0
	mesh.surface_set_material(1, globe_mat)

	return mesh


static func build_mesh() -> ArrayMesh:
	return create_mesh()
