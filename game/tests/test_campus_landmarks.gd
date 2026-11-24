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
		and col.get_node_or_null("MerkezKutuphaneSunkFloorCollider") != null
	)
	var sunk_col: CollisionShape3D = col.get_node_or_null("MerkezKutuphaneSunkFloorCollider") as CollisionShape3D if col != null else null
	var mono_col: CollisionShape3D = col.get_node_or_null("MerkezKutuphaneMonolithCollider") as CollisionShape3D if col != null else null
	var sunk_drop: float = (mono_col.transform.origin.y - 1.25) - (sunk_col.transform.origin.y + 0.25) if (sunk_col != null and mono_col != null) else 0.0
	n.free()
	if not ok:
		return "CampusLandmarks düğümleri eksik"
	if absf(sunk_drop - 3.50) > 0.15:
		return "Merkez Kütüphanesi çökük avlusu üst meydanın ~3.5 m (1 kat) altında olmalı, bulunan fark: %.2f m" % sunk_drop
	if mesh_count > 1:
		return "CampusLandmarks en fazla 1 birleşik mesh üretmeli, %d bulundu" % mesh_count
	return ""
