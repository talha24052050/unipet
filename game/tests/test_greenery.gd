extends RefCounted

const Decor := preload("res://src/world/greenery_decor.gd")
const PATH: String = "res://data/zones/kampus_greenery.json"


func test_greenery_data_and_build() -> String:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not data is Dictionary:
		return "kampus_greenery.json okunamadı"
	var trees: Array = data["trees"]
	if trees.size() < 500:
		return "ağaç az: %d" % trees.size()
	for t: Variant in trees:
		if not Decor.TREE_MODELS.has(str(t[0])):
			return "bilinmeyen ağaç türü: %s" % t[0]
	var tracks: Array = data["tracks"]
	if tracks.size() != 1 or (tracks[0]["inner"] as Array).size() != (tracks[0]["outer"] as Array).size():
		return "pist verisi bozuk"
	var d: Node3D = Decor.new()
	d.build(data)
	var bushes: Array = data.get("bushes", [])
	var no_monument: bool = d.get_node_or_null("OrtabahceMonument") == null
	var ok: bool = no_monument and d.tree_count == trees.size() and d.bush_count == bushes.size() and d.bush_count > 100 and d.track_count == 1 and d.bed_count > 0 and d.kiosk_count == 1
	d.free()
	return "" if ok else "kurulum sayıları tutmuyor"


func test_tree_models_single_surface() -> String:
	for kind: String in ["tree_plane", "tree_stonepine", "tree_cypress"]:
		var n: Node = (load(Decor.TREE_MODELS[kind]) as PackedScene).instantiate()
		var mis: Array[Node] = n.find_children("*", "MeshInstance3D", true, false)
		var surfaces: int = (mis[0] as MeshInstance3D).mesh.get_surface_count() if mis.size() == 1 else -1
		n.free()
		if surfaces != 1:
			return "%s tek yüzey olmalı (tek çizim çağrısı): %d" % [kind, surfaces]
	return ""
