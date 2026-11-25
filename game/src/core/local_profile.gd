extends RefCounted
## Oyuncunun pet + aksesuar + kampüs kimliği (Doğrulanmış YTÜ Öğrencisi / YKS Adayı & Misafir) kaydı.

const PATH: String = "user://profile.cfg"

const NAME_MAX: int = 16
const BIO_MAX: int = 40

const YTU_ROLES: PackedStringArray = [
	"Bilgisayar Müh.",
	"Elektrik-Elektronik Fak.",
	"Makine Fak.",
	"İnşaat Fak.",
	"İİBF",
	"Fen-Edebiyat Fak.",
	"Eğitim Fak.",
	"Kimya-Metalurji Fak.",
	"Sanat ve Tasarım Fak.",
	"YDYO Hazırlık",
]

const VISITOR_ROLES: PackedStringArray = [
	"🎯 YKS Adayı (Hedef YTÜ)",
	"👀 Kampüs Misafiri",
	"🎓 Misafir Öğrenci",
	"🏛 YTÜ Mezunu",
]

var pet_id: StringName = &""
var display_name: String = ""
var is_ytu_verified: bool = false
var role_tag: String = ""
var bio: String = ""
var onboarding_seen: bool = false
var accessories: Dictionary = {}
var unlocked: PackedStringArray = PackedStringArray()
var discovered: PackedStringArray = PackedStringArray()


static func load_or_default(path: String = PATH) -> RefCounted:
	var p: RefCounted = new()
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(path) == OK:
		p.pet_id = StringName(str(cfg.get_value("pet", "id", "")))
		p.display_name = str(cfg.get_value("player", "name", ""))
		p.is_ytu_verified = bool(cfg.get_value("player", "ytu_verified", false))
		p.role_tag = str(cfg.get_value("player", "role_tag", ""))
		p.bio = str(cfg.get_value("player", "bio", "")).substr(0, BIO_MAX)
		p.onboarding_seen = bool(cfg.get_value("player", "onboarding_seen", false))
		for slot: String in CharacterDef.ACCESSORY_SLOTS:
			var acc: String = str(cfg.get_value("accessories", slot, ""))
			if not acc.is_empty():
				p.accessories[StringName(slot)] = StringName(acc)
		p.unlocked = PackedStringArray(str(cfg.get_value("unlocks", "pets", "")).split(",", false))
		p.discovered = PackedStringArray(str(cfg.get_value("discovery", "places", "")).split(",", false))
	if p.pet_id == &"":
		p.pet_id = Config.DEFAULT_PET_ID
	if p.role_tag.is_empty():
		p.role_tag = YTU_ROLES[0] if p.is_ytu_verified else VISITOR_ROLES[0]
	return p


func save(path: String = PATH) -> Error:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("pet", "id", str(pet_id))
	cfg.set_value("player", "name", display_name)
	cfg.set_value("player", "ytu_verified", is_ytu_verified)
	cfg.set_value("player", "role_tag", role_tag.substr(0, 32))
	cfg.set_value("player", "bio", bio.substr(0, BIO_MAX))
	cfg.set_value("player", "onboarding_seen", onboarding_seen)
	cfg.set_value("unlocks", "pets", ",".join(unlocked))
	cfg.set_value("discovery", "places", ",".join(discovered))
	for slot: StringName in accessories:
		cfg.set_value("accessories", str(slot), str(accessories[slot]))
	return cfg.save(path)


static func clean_name(raw: String) -> String:
	var out: String = ""
	for ch: String in raw.strip_edges():
		if ch == " " and out.ends_with(" "):
			continue
		if ch == " " or ch == "_" or ch == "-" or ch.is_valid_identifier() or ch.is_valid_int() or "çğıöşüÇĞİÖŞÜ".contains(ch):
			out += ch
	return out.strip_edges().substr(0, NAME_MAX)


static func name_from_email(email: String) -> String:
	return clean_name(email.get_slice("@", 0).replace(".", " "))


func has_saved(path: String = PATH) -> bool:
	return FileAccess.file_exists(path)
