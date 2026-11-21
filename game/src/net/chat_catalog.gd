extends RefCounted
## Hazır chat cümleleri ve emote tanımları kataloğu.
## presets.json dosyasından yükler, bilinmeyen id'ler için boş değer döner.
## (DECISION / TASK: class_name YOK)

const DEFAULT_PATH: String = "res://data/chat/presets.json"

var _presets: Array[Dictionary] = []
var _emotes: Array[Dictionary] = []
var _preset_map: Dictionary = {}
var _emote_anim_map: Dictionary = {}
var _emote_label_map: Dictionary = {}


func _init(path: String = DEFAULT_PATH) -> void:
	if not path.is_empty():
		load_from_file(path)


func load_from_file(path: String) -> bool:
	_presets.clear()
	_emotes.clear()
	_preset_map.clear()
	_emote_anim_map.clear()
	_emote_label_map.clear()

	if not FileAccess.file_exists(path):
		push_error("Chat katalog dosyası bulunamadı: %s" % path)
		return false

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Chat katalog dosyası açılamadı: %s" % path)
		return false

	var content: String = file.get_as_text()
	var json: JSON = JSON.new()
	var parse_err: Error = json.parse(content)
	if parse_err != OK:
		push_error("Chat katalog json ayrıştırma hatası (%d): %s" % [parse_err, json.get_error_message()])
		return false

	var data = json.data
	if not data is Dictionary:
		push_error("Chat katalog geçersiz kök yapısı (Dictionary bekleniyordu)")
		return false

	var p_list = data.get("presets", [])
	if p_list is Array:
		for item in p_list:
			if item is Dictionary and item.has("id") and item.has("text"):
				var id: String = str(item["id"])
				var text: String = str(item["text"])
				_presets.append({"id": id, "text": text})
				_preset_map[id] = text

	var e_list = data.get("emotes", [])
	if e_list is Array:
		for item in e_list:
			if item is Dictionary and item.has("id") and item.has("anim"):
				var id: String = str(item["id"])
				var anim: StringName = StringName(str(item["anim"]))
				var label: String = str(item.get("label", id))
				_emotes.append({"id": id, "anim": anim, "label": label})
				_emote_anim_map[id] = anim
				_emote_label_map[id] = label

	return true


func preset_text(id: String) -> String:
	return _preset_map.get(id, "")


func emote_anim(id: String) -> StringName:
	return _emote_anim_map.get(id, &"")


func emote_label(id: String) -> String:
	return _emote_label_map.get(id, "")


func presets() -> Array[Dictionary]:
	return _presets.duplicate()


func emotes() -> Array[Dictionary]:
	return _emotes.duplicate()
