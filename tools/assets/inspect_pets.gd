extends SceneTree
## Pet glb'lerini inceler: boyut (AABB), üçgen sayısı, animasyon adları ve süreleri, kemikler.
## Kullanım: godot --headless --path game -s res://../tools/assets/inspect_pets.gd
##   (ya da mutlak yol) -- [çıktı.json]
## .tres (CharacterDef) yazarken animation_map ve accessory_bones için kaynak.


func _initialize() -> void:
	var report: Dictionary = {}
	var base: String = "res://assets/characters"
	for id: String in DirAccess.get_directories_at(base):
		var path: String = "%s/%s/%s.glb" % [base, id, id]
		if not ResourceLoader.exists(path):
			continue
		var root: Node = (load(path) as PackedScene).instantiate()
		report[id] = _inspect(root)
		root.free()
	var text: String = JSON.stringify(report, "  ", false)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		var f: FileAccess = FileAccess.open(args[0], FileAccess.WRITE)
		f.store_string(text)
	print(text)
	quit()


func _inspect(root: Node) -> Dictionary:
	var aabb: AABB = AABB()
	var first: bool = true
	var tris: int = 0
	var anims: Dictionary = {}
	var bones: PackedStringArray = []
	for n: Node in _all(root):
		if n is MeshInstance3D:
			var mi: MeshInstance3D = n
			var box: AABB = _global_xform(mi) * mi.get_aabb()
			aabb = box if first else aabb.merge(box)
			first = false
			for s: int in mi.mesh.get_surface_count():
				var arrays: Array = mi.mesh.surface_get_arrays(s)
				var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				tris += (idx.size() if idx.size() > 0 else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
		elif n is AnimationPlayer:
			var ap: AnimationPlayer = n
			for a: StringName in ap.get_animation_list():
				anims[str(a)] = snappedf(ap.get_animation(a).length, 0.01)
		elif n is Skeleton3D:
			var sk: Skeleton3D = n
			for b: int in sk.get_bone_count():
				bones.append(sk.get_bone_name(b))
	return {
		"size": [snappedf(aabb.size.x, 0.01), snappedf(aabb.size.y, 0.01), snappedf(aabb.size.z, 0.01)],
		"min_y": snappedf(aabb.position.y, 0.01),
		"center_xz": [snappedf(aabb.get_center().x, 0.01), snappedf(aabb.get_center().z, 0.01)],
		"triangles": tris,
		"animations": anims,
		"bones": bones,
	}


func _global_xform(n: Node3D) -> Transform3D:
	var t: Transform3D = n.transform
	var p: Node = n.get_parent()
	while p is Node3D:
		t = (p as Node3D).transform * t
		p = p.get_parent()
	return t


func _all(n: Node) -> Array[Node]:
	var out: Array[Node] = [n]
	for c: Node in n.get_children():
		out.append_array(_all(c))
	return out
