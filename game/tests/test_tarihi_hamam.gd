extends RefCounted

const TarihiHamam := preload("res://src/world/tarihi_hamam.gd")
const Greybox := preload("res://src/world/greybox_builder.gd")


func test_hamam_sunk_pit_bounds() -> String:
	# Ana kapı önü (s=13.5, d=2.5) çökük avlu içinde olmalı
	var door_front: Vector2 = Greybox.HAMAM_ORIGIN + Greybox.HAMAM_U * 13.5 + Greybox.HAMAM_N * 2.5
	if not Greybox._in_hamam_sunk_pit(door_front.x, door_front.y):
		return "Tarihi Hamam giriş önü çökük avlu içinde değil"
	# Yol ortası (d=26.0) çökük avlu dışında olmalı
	var road_pt: Vector2 = Greybox.HAMAM_ORIGIN + Greybox.HAMAM_U * 25.0 + Greybox.HAMAM_N * 26.0
	if Greybox._in_hamam_sunk_pit(road_pt.x, road_pt.y):
		return "Araç yolu yanlışlıkla çökük avlu içine alındı"
	return ""


func test_tarihi_hamam_builds_architecture_banner_and_eslab_van() -> String:
	var hamam: Node3D = TarihiHamam.new()
	hamam.build()
	var walls: MeshInstance3D = hamam.get_node_or_null("HamamAlmasikWalls") as MeshInstance3D
	var details: MeshInstance3D = hamam.get_node_or_null("HamamArchitecturalDetails") as MeshInstance3D
	var banner: MeshInstance3D = hamam.get_node_or_null("ArtlabMainBanner") as MeshInstance3D
	var eslab_logo: Label3D = hamam.get_node_or_null("EslabSideLogo") as Label3D
	var portal_sign: Label3D = hamam.get_node_or_null("TarihiHamamPortalSign") as Label3D
	var cols: StaticBody3D = hamam.get_node_or_null("TarihiHamamCollisions") as StaticBody3D
	if walls == null or walls.mesh == null or walls.mesh.get_surface_count() == 0:
		hamam.free()
		return "Almaşık duvar mesh'i oluşmadı"
	if details == null or details.mesh == null or details.mesh.get_surface_count() == 0:
		hamam.free()
		return "Mimari detay / kubbe / ESLAB mesh'i oluşmadı"
	if banner == null or banner.mesh == null:
		hamam.free()
		return "ARTLAB ana cephe afişi oluşmadı"
	if eslab_logo == null or not eslab_logo.text.contains("ESPRESSOLAB"):
		hamam.free()
		return "ESPRESSOLAB minibüs logosu eksik"
	if portal_sign == null or not portal_sign.text.contains("TARİHİ HAMAM"):
		hamam.free()
		return "Tarihi Hamam giriş tabelası eksik"
	if cols == null or cols.get_child_count() < 4:
		hamam.free()
		return "Tarihi Hamam + ESLAB çarpıştırıcıları eksik"
	# ESLAB minibüsü (EslabSideLogo) kapının (TarihiHamamPortalSign) sol tarafında (daha küçük s koordinatında) olmalı!
	var p_door: Vector2 = Vector2(portal_sign.position.x, portal_sign.position.z) - Greybox.HAMAM_ORIGIN
	var p_van: Vector2 = Vector2(eslab_logo.position.x, eslab_logo.position.z) - Greybox.HAMAM_ORIGIN
	var s_door: float = p_door.dot(Greybox.HAMAM_U)
	var s_van: float = p_van.dot(Greybox.HAMAM_U)
	if not (s_van < s_door - 3.0):
		hamam.free()
		return "ESLAB minibüsü kapının solunda değil: s_van=%.2f s_door=%.2f" % [s_van, s_door]
	hamam.free()
	return ""
