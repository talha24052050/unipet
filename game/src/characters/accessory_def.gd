class_name AccessoryDef
extends Resource
## Bir aksesuarın tanımı (data/accessories/*.tres).
## Sahne, ~1 m boyunda / ~0.9 m genişliğinde bir pete göre metre cinsinden modellenir;
## PetVisual petin boyutuna göre ölçekler ve slotun bağlantı noktasına yerleştirir.
## Sahne pivotu: head = şapkanın tabanı, face = gözlüğün köprüsü, neck = halkanın merkezi,
## back = sırta değen yüzün ortası. Hepsi +Z (petin önü) yönüne bakar.

@export var id: StringName
@export var display_name: String
## CharacterDef.ACCESSORY_SLOTS'tan biri.
@export var slot: StringName
@export_file("*.tscn", "*.glb") var scene_path: String


func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	if String(id).is_empty():
		errors.append("aksesuar id boş")
	if not String(slot) in CharacterDef.ACCESSORY_SLOTS:
		errors.append("%s: bilinmeyen slot: %s" % [id, slot])
	if scene_path.is_empty():
		errors.append("%s: scene_path boş" % id)
	return errors
