extends RefCounted

const PetVisual := preload("res://src/characters/pet_visual.gd")
const AccessoryRegistry := preload("res://src/characters/accessory_registry.gd")

const NEW_ACCESSORY_IDS: Array[StringName] = [&"beanie", &"sunglasses", &"bowtie", &"wings"]
const OLD_ACCESSORY_IDS: Array[StringName] = [&"hat_cap", &"glasses", &"scarf", &"backpack"]
const ALL_PET_IDS: Array[StringName] = [&"shark", &"birb", &"mushnub", &"yeti", &"ninja", &"chicken"]


func _make_visual(pet_id: StringName) -> Node3D:
	var v: Node3D = PetVisual.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(v)
	v.call("set_character", load("res://data/characters/%s.tres" % pet_id))
	return v


func _count_node_triangles(node: Node) -> int:
	var total: int = 0
	for child: Node in node.get_children():
		if child is MeshInstance3D and child.mesh is PrimitiveMesh:
			var m: PrimitiveMesh = child.mesh
			var arr: Array = m.get_mesh_arrays()
			if arr[Mesh.ARRAY_INDEX] != null and arr[Mesh.ARRAY_INDEX].size() > 0:
				total += arr[Mesh.ARRAY_INDEX].size() / 3
			else:
				total += arr[Mesh.ARRAY_VERTEX].size() / 3
		total += _count_node_triangles(child)
	return total


func test_total_eight_accessories_loaded() -> String:
	var reg: AccessoryRegistry = AccessoryRegistry.new()
	reg.load_from_dir("res://data/accessories")
	if reg.count() != 8:
		return "Toplam 8 aksesuar bekleniyordu, %d yüklendi" % reg.count()
	for id: StringName in NEW_ACCESSORY_IDS:
		var def: AccessoryDef = reg.get_def(id)
		if def == null:
			return "Yeni aksesuar bulunamadı: %s" % id
		var errs: PackedStringArray = def.validate()
		if not errs.is_empty():
			return "Aksesuar %s geçersiz: %s" % [id, errs]
	for id: StringName in OLD_ACCESSORY_IDS:
		if reg.get_def(id) == null:
			return "Mevcut aksesuar bulunamadı: %s" % id
	return ""


func test_two_accessories_per_slot() -> String:
	var reg: AccessoryRegistry = AccessoryRegistry.new()
	reg.load_from_dir("res://data/accessories")
	for slot: StringName in CharacterDef.ACCESSORY_SLOTS:
		var accs: Array[AccessoryDef] = reg.for_slot(slot)
		if accs.size() != 2:
			return "Slot '%s' için 2 seçenek bekleniyordu, %d bulundu" % [slot, accs.size()]
	return ""


func test_new_accessories_triangle_budget() -> String:
	var scenes: Dictionary = {
		&"beanie": "res://assets/accessories/beanie.tscn",
		&"sunglasses": "res://assets/accessories/sunglasses.tscn",
		&"bowtie": "res://assets/accessories/bowtie.tscn",
		&"wings": "res://assets/accessories/wings.tscn"
	}
	for id: StringName in scenes:
		var path: String = scenes[id]
		var packed: PackedScene = load(path)
		if packed == null:
			return "%s sahnesi yüklenemedi: %s" % [id, path]
		var inst: Node = packed.instantiate()
		var tris: int = _count_node_triangles(inst)
		inst.free()
		if tris >= 300:
			return "%s bütçeyi aştı (%d >= 300 üçgen)" % [id, tris]
	return ""


func test_new_accessories_equip_on_all_six_pets() -> String:
	var reg: AccessoryRegistry = AccessoryRegistry.new()
	reg.load_from_dir("res://data/accessories")
	for pet_id: StringName in ALL_PET_IDS:
		var v: Node3D = _make_visual(pet_id)
		for acc_id: StringName in NEW_ACCESSORY_IDS:
			var def: AccessoryDef = reg.get_def(acc_id)
			var success: bool = v.call("equip", def)
			if not success:
				v.free()
				return "%s petine %s takılamadı" % [pet_id, acc_id]
		var equipped: Dictionary = v.call("equipped_ids")
		v.free()
		if equipped.size() != 4:
			return "%s üzerinde 4 yeni aksesuar takılı olmalıydı, %d takılı: %s" % [pet_id, equipped.size(), equipped]
		for acc_id: StringName in NEW_ACCESSORY_IDS:
			var def: AccessoryDef = reg.get_def(acc_id)
			if equipped.get(def.slot) != acc_id:
				return "%s üzerinde %s slotunda %s yerine %s takılı" % [pet_id, def.slot, acc_id, equipped.get(def.slot)]
	return ""
