extends RefCounted
## Oyuncunun pet + aksesuar seçimi. Şimdilik cihazda (user://profile.cfg) saklanır;
## Parça 3'te Supabase profil tablosuna taşınacak (aynı alanlar).

const PATH: String = "user://profile.cfg"

var pet_id: StringName = &""
## slot (StringName) -> aksesuar id (StringName)
var accessories: Dictionary = {}


static func load_or_default(path: String = PATH) -> RefCounted:
	var p: RefCounted = new()
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(path) == OK:
		p.pet_id = StringName(str(cfg.get_value("pet", "id", "")))
		for slot: String in CharacterDef.ACCESSORY_SLOTS:
			var acc: String = str(cfg.get_value("accessories", slot, ""))
			if not acc.is_empty():
				p.accessories[StringName(slot)] = StringName(acc)
	if p.pet_id == &"":
		p.pet_id = Config.DEFAULT_PET_ID
	return p


func save(path: String = PATH) -> Error:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("pet", "id", str(pet_id))
	for slot: StringName in accessories:
		cfg.set_value("accessories", str(slot), str(accessories[slot]))
	return cfg.save(path)


func has_saved(path: String = PATH) -> bool:
	return FileAccess.file_exists(path)
