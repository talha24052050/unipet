extends RefCounted
## Oyuncunun pet + aksesuar seçimi. Şimdilik cihazda (user://profile.cfg) saklanır;
## Parça 3'te Supabase profil tablosuna taşınacak (aynı alanlar).

const PATH: String = "user://profile.cfg"

var pet_id: StringName = &""
## Oyunda diğerlerinin gördüğü takma ad (1-16 karakter).
var display_name: String = ""
const NAME_MAX: int = 16
## slot (StringName) -> aksesuar id (StringName)
var accessories: Dictionary = {}
## Sunucunun bildirdiği açık efsanevi petler (OP_UNLOCKS); seçim ekranı bunlara bakar.
var unlocked: PackedStringArray = PackedStringArray()
## Keşfedilen yerler (data/places.json id'leri).
var discovered: PackedStringArray = PackedStringArray()


static func load_or_default(path: String = PATH) -> RefCounted:
	var p: RefCounted = new()
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(path) == OK:
		p.pet_id = StringName(str(cfg.get_value("pet", "id", "")))
		p.display_name = str(cfg.get_value("player", "name", ""))
		for slot: String in CharacterDef.ACCESSORY_SLOTS:
			var acc: String = str(cfg.get_value("accessories", slot, ""))
			if not acc.is_empty():
				p.accessories[StringName(slot)] = StringName(acc)
		p.unlocked = PackedStringArray(str(cfg.get_value("unlocks", "pets", "")).split(",", false))
		p.discovered = PackedStringArray(str(cfg.get_value("discovery", "places", "")).split(",", false))
	if p.pet_id == &"":
		p.pet_id = Config.DEFAULT_PET_ID
	return p


func save(path: String = PATH) -> Error:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("pet", "id", str(pet_id))
	cfg.set_value("player", "name", display_name)
	cfg.set_value("unlocks", "pets", ",".join(unlocked))
	cfg.set_value("discovery", "places", ",".join(discovered))
	for slot: StringName in accessories:
		cfg.set_value("accessories", str(slot), str(accessories[slot]))
	return cfg.save(path)


## Takma adı temizler: baştaki/sondaki boşluk, çoklu boşluk, izinsiz karakter; en çok NAME_MAX. Boş olabilir.
static func clean_name(raw: String) -> String:
	var out: String = ""
	for ch: String in raw.strip_edges():
		if ch == " " and out.ends_with(" "):
			continue
		if ch == " " or ch == "_" or ch == "-" or ch.is_valid_identifier() or ch.is_valid_int() or "çğıöşüÇĞİÖŞÜ".contains(ch):
			out += ch
	return out.strip_edges().substr(0, NAME_MAX)


## Mailden varsayılan takma ad (@ öncesi, noktalar boşluk).
static func name_from_email(email: String) -> String:
	return clean_name(email.get_slice("@", 0).replace(".", " "))


func has_saved(path: String = PATH) -> bool:
	return FileAccess.file_exists(path)
