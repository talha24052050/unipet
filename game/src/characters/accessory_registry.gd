extends RefCounted
## data/accessories altındaki AccessoryDef (.tres) dosyalarını yükler.

var _defs: Dictionary = {}  # StringName -> AccessoryDef


func load_from_dir(dir_path: String) -> void:
	_defs.clear()
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	for file: String in dir.get_files():
		var name: String = file.trim_suffix(".remap")
		if not name.ends_with(".tres"):
			continue
		var res: Resource = load(dir_path.path_join(name))
		if res is AccessoryDef:
			register(res)


func register(def: AccessoryDef) -> bool:
	var errors: PackedStringArray = def.validate()
	if not errors.is_empty():
		for e: String in errors:
			push_warning("AccessoryDef geçersiz: " + e)
		return false
	_defs[def.id] = def
	return true


func get_def(id: StringName) -> AccessoryDef:
	return _defs.get(id)


func all() -> Array[AccessoryDef]:
	var out: Array[AccessoryDef] = []
	for d: AccessoryDef in _defs.values():
		out.append(d)
	return out


func for_slot(slot: StringName) -> Array[AccessoryDef]:
	return all().filter(func(d: AccessoryDef) -> bool: return d.slot == slot)


func count() -> int:
	return _defs.size()
