extends RefCounted
## Yemekhane önü, Yıldız Store amfi-oturma merdivenleri ve A101 cephesi testleri.

const PlazaScript := preload("res://src/world/yemekhane_plaza.gd")


func test_yemekhane_plaza_builds_with_low_draw_calls() -> String:
	var p: Node3D = PlazaScript.new()
	p.call("build")

	var solid: MeshInstance3D = p.get_node_or_null("PlazaStructures") as MeshInstance3D
	var glass: MeshInstance3D = p.get_node_or_null("PlazaGlass") as MeshInstance3D
	var store_sign: Node3D = p.get_node_or_null("YildizStoreSign") as Node3D
	var love_panel: Node3D = p.get_node_or_null("StoreLovePanel") as Node3D
	var a101_sign: Label3D = p.get_node_or_null("A101Sign") as Label3D
	var col_body: Node = p.get_node_or_null("PlazaCollisions")

	var mesh_count: int = 0
	for ch: Node in p.get_children():
		if ch is MeshInstance3D:
			mesh_count += 1

	var ok: bool = (
		solid != null and solid.mesh != null
		and glass != null and glass.mesh != null
		and store_sign != null and store_sign.get_child_count() == 3
		and love_panel != null and love_panel.get_node_or_null("TurkiyeninYildiziTag") != null
		and a101_sign != null and a101_sign.text.contains("A•101")
		and col_body != null
		and col_body.get_node_or_null("YildizStoreStairs") != null
		and col_body.get_node_or_null("YildizStoreStairRamp") != null
		and col_body.get_node_or_null("StorePlanter1") != null
		and col_body.get_node_or_null("YemekhaneEntrance") != null
		and col_body.get_node_or_null("YemekhaneStairRamp") != null
	)
	p.free()
	if not ok:
		return "YemekhanePlaza düğümleri (Store/A101/Yemekhane) eksik"
	if mesh_count > 2:
		return "YemekhanePlaza en fazla 2 birleşik mesh üretmeli, %d bulundu" % mesh_count
	return ""


func test_yemekhane_and_store_terrain_is_flat() -> String:
	var th: TerrainHeight = TerrainHeight.load_from_file("res://data/zones/kampus_terrain.json")
	var gb: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/zones/kampus_greybox.json"))
	if th == null or not (gb is Dictionary):
		return "terrain veya greybox yüklenemedi"
	var found_store: bool = false
	for b: Dictionary in (gb as Dictionary).get("buildings", []):
		var bn: String = str(b.get("name", ""))
		if bn == "Yıldız Store":
			found_store = true
			if float(b.get("height", 0.0)) > 6.5:
				return "Yıldız Store tek katlı (~5 m) olmalı: %f" % float(b.get("height", 0.0))
		if bn in ["Yemekhane", "Yıldız Store"]:
			var lo: float = INF
			var hi: float = -INF
			for pt: Array in b.get("points", []):
				var h: float = th.height_at(float(pt[0]), float(pt[1]))
				lo = minf(lo, h)
				hi = maxf(hi, h)
			if (hi - lo) > 0.35:
				return "%s tabanı düz olmalı, kot farkı %.2f m" % [bn, hi - lo]
	return "" if found_store else "kampus_greybox.json içinde Yıldız Store adı bulunamadı"
