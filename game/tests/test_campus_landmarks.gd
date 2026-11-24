extends RefCounted
## Kampüs ikonik yapıları (Otağ-ı Hümayun, İlhan Varank Kütüphanesi, Merkez Kütüphanesi, Fen-Edebiyat) testleri.

const LandmarksScript := preload("res://src/world/campus_landmarks.gd")


func test_campus_landmarks_build_single_merged_mesh() -> String:
	var n: Node3D = LandmarksScript.new()
	n.call("build")

	var solid: MeshInstance3D = n.get_node_or_null("LandmarkStructures") as MeshInstance3D
	var col: Node = n.get_node_or_null("LandmarkCollisions")
	var mesh_count: int = 0
	for ch: Node in n.get_children():
		if ch is MeshInstance3D:
			mesh_count += 1

	var ok: bool = (
		solid != null and solid.mesh != null
		and col != null and col.get_node_or_null("OtagPoolCollider") != null
		and n.get_node_or_null("OtagPlaque") != null
		and n.get_node_or_null("IlhanVarankSign") != null
		and n.get_node_or_null("MerkezKutuphaneSign") != null
		and n.get_node_or_null("FenEdebiyatSign") != null
		and n.get_node_or_null("EgitimFakSign") != null
		and n.get_node_or_null("YabanciDillerSign") != null
		and n.get_node_or_null("RingStopSign") != null
		and n.get_node_or_null("MetroGateBSignTitle") != null
		and n.get_node_or_null("KongreMerkeziSign") != null
		and n.get_node_or_null("InsaatFakSign") != null
		and n.get_node_or_null("KimyaMetalurjiSign") != null
		and n.get_node_or_null("MerkezLabSign") != null
		and n.get_node_or_null("TeknoparkSign") != null
		and n.get_node_or_null("SporKompleksiSign") != null
		and n.get_node_or_null("BuyukEvSign") != null
		and n.get_node_or_null("LojmanlarTotemTitle") != null
		and col.get_node_or_null("MerkezKutuphaneMonolithCollider") != null
	)
	n.free()
	if not ok:
		return "CampusLandmarks düğümleri eksik"
	if mesh_count > 1:
		return "CampusLandmarks en fazla 1 birleşik mesh üretmeli, %d bulundu" % mesh_count
	return ""
