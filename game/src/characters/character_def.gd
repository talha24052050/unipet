class_name CharacterDef
extends Resource
## Bir pet karakterinin tanımı. Oyun kodu model dosyasını değil BUNU bilir.
## Quaternius -> kendi yıldız karakterimize geçiş = yeni .tres dosyaları.

@export var id: StringName
@export var display_name: String
@export_file("*.glb", "*.gltf", "*.tscn") var model_path: String
@export var model_scale: float = 1.0
## Oyun içi mantıksal animasyon adı -> modeldeki gerçek animasyon adı.
## Zorunlu anahtarlar: idle, walk, run, emote_wave, emote_jump
@export var animation_map: Dictionary = {}
## İsteğe bağlı: mantıksal animasyon -> oynatma hızı çarpanı (ör. ayrı koşu animasyonu
## olmayan petlerde run = hızlandırılmış walk). Yoksa 1.0.
@export var animation_speed: Dictionary = {}
## Aksesuar slotu -> modeldeki kemik (bone) adı. Slotlar: head, face, neck, back
@export var accessory_bones: Dictionary = {}
## Slot bazında aksesuar yerleşim düzeltmesi (offset/rotation/scale).
@export var accessory_offsets: Dictionary = {}
@export var selectable: bool = true

const REQUIRED_ANIMS: PackedStringArray = ["idle", "walk", "run", "emote_wave", "emote_jump"]
const ACCESSORY_SLOTS: PackedStringArray = ["head", "face", "neck", "back"]


## Mantıksal ad -> modeldeki animasyon adı ("" = yok).
func anim_name(logical: StringName) -> String:
	return str(animation_map.get(logical, ""))


func anim_speed(logical: StringName) -> float:
	return float(animation_speed.get(logical, 1.0))


func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	if String(id).is_empty():
		errors.append("id boş")
	if model_path.is_empty():
		errors.append("%s: model_path boş" % id)
	for a in REQUIRED_ANIMS:
		if not animation_map.has(a):
			errors.append("%s: animasyon eksik: %s" % [id, a])
	for slot in accessory_bones.keys():
		if not slot in ACCESSORY_SLOTS:
			errors.append("%s: bilinmeyen aksesuar slotu: %s" % [id, slot])
	return errors
