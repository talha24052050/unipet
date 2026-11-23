extends RefCounted
## Elektrik-Elektronik Fakültesi (EEF) önü meydan ve totem testleri.

const EefPlazaScript := preload("res://src/world/eef_plaza.gd")


func test_eef_plaza_builds_with_low_draw_calls() -> String:
	var p: Node3D = EefPlazaScript.new()
	p.call("build")

	var solid: MeshInstance3D = p.get_node_or_null("EefStructures") as MeshInstance3D
	var facade_sign: Node3D = p.get_node_or_null("EefFacadeSign") as Node3D
	var totem_title: Label3D = p.get_node_or_null("EefTotemTitle") as Label3D
	var totem_body: Label3D = p.get_node_or_null("EefTotemBody") as Label3D
	var col_body: Node = p.get_node_or_null("EefCollisions")

	var mesh_count: int = 0
	for ch: Node in p.get_children():
		if ch is MeshInstance3D:
			mesh_count += 1

	var ok: bool = (
		solid != null and solid.mesh != null
		and facade_sign != null and facade_sign.get_child_count() == 1
		and totem_title != null and totem_title.text.contains("YILDIZ")
		and totem_body != null and totem_body.text.contains("ELEKTRİK")
		and col_body != null
		and col_body.get_node_or_null("EefTotemCollider") != null
	)
	p.free()
	if not ok:
		return "EefPlaza düğümleri (cephesi/totem/çarpışma) eksik"
	if mesh_count > 1:
		return "EefPlaza en fazla 1 birleşik solid mesh üretmeli, %d bulundu" % mesh_count
	return ""
