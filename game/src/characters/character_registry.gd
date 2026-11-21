extends RefCounted
## data/characters altındaki tüm CharacterDef (.tres) dosyalarını yükler.

var _defs: Dictionary = {}  # StringName -> CharacterDef


func load_from_dir(dir_path: String) -> void:
	_defs.clear()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for file in dir.get_files():
		# Export edilmiş buildlerde .tres dosyaları .remap olarak görünebilir.
		var name := file.trim_suffix(".remap")
		if not name.ends_with(".tres"):
			continue
		var res := load(dir_path.path_join(name))
		if res is CharacterDef:
			register(res)


func register(def: CharacterDef) -> bool:
	var errors := def.validate()
	if not errors.is_empty():
		for e in errors:
			push_warning("CharacterDef geçersiz: " + e)
		return false
	_defs[def.id] = def
	return true


func get_def(id: StringName) -> CharacterDef:
	return _defs.get(id)


func selectable() -> Array[CharacterDef]:
	var out: Array[CharacterDef] = []
	for d in _defs.values():
		if d.selectable:
			out.append(d)
	return out


func count() -> int:
	return _defs.size()
