extends RefCounted

const PetSelectScene := preload("res://scenes/ui/pet_select.tscn")
const LocalProfile := preload("res://src/core/local_profile.gd")


func _ensure_services() -> void:
	if Services.characters == null or Services.accessories == null:
		Services._ready()


func _make_scene() -> PetSelect:
	_ensure_services()
	var inst: PetSelect = PetSelectScene.instantiate() as PetSelect
	(Engine.get_main_loop() as SceneTree).root.add_child(inst)
	if not inst.is_node_ready():
		inst._ready()
	return inst


func test_scene_loads() -> String:
	var scene: PetSelect = _make_scene()
	if scene == null:
		return "pet_select.tscn yüklenemedi"
	if not scene.has_node("%PetPivot") or not scene.has_node("%PetVisual"):
		scene.queue_free()
		return "PetPivot veya PetVisual bulunamadı"
	if not scene.has_node("%PetNameLabel") or not scene.has_node("%StartButton"):
		scene.queue_free()
		return "PetNameLabel veya StartButton bulunamadı"
	if scene.profile == null:
		scene.queue_free()
		return "Sahne açılışında profile yüklenmedi"
	scene.queue_free()
	return ""


func test_pet_navigation_updates_profile() -> String:
	var scene: PetSelect = _make_scene()
	var pets: Array[CharacterDef] = Services.characters.selectable()
	if pets.size() < 2:
		scene.queue_free()
		return "En az 2 seçilebilir pet bekleniyor, %d bulundu" % pets.size()

	scene.set_pet_index(0, false)
	if scene.profile.pet_id != pets[0].id:
		scene.queue_free()
		return "set_pet_index(0) profile.pet_id'yi güncellemedi: %s" % scene.profile.pet_id

	scene.next_pet()
	if scene.profile.pet_id != pets[1].id:
		scene.queue_free()
		return "next_pet() profile.pet_id'yi güncellemedi: %s" % scene.profile.pet_id

	scene.prev_pet()
	if scene.profile.pet_id != pets[0].id:
		scene.queue_free()
		return "prev_pet() profile.pet_id'yi geri döndürmedi: %s" % scene.profile.pet_id

	# Baştan geriye sarma testi (wrap-around)
	scene.prev_pet()
	var last_pet: CharacterDef = pets[pets.size() - 1]
	if scene.profile.pet_id != last_pet.id:
		scene.queue_free()
		return "prev_pet() liste sonuna sarmadı: %s" % scene.profile.pet_id

	scene.queue_free()
	return ""


func test_accessory_cycling_updates_profile() -> String:
	var scene: PetSelect = _make_scene()

	for slot: StringName in CharacterDef.ACCESSORY_SLOTS:
		var available: Array[AccessoryDef] = Services.accessories.for_slot(slot)
		if available.is_empty():
			continue
		var expected_acc: AccessoryDef = available[0]

		# Önce slottaki aksesuarı çıkaralım (yok durumuna getirelim)
		while scene.profile.accessories.has(slot):
			scene.cycle_accessory(slot)

		if scene.profile.accessories.has(slot):
			scene.queue_free()
			return "%s slotu temizlenemedi" % slot

		# Döndür: Yok -> ilk aksesuar
		scene.cycle_accessory(slot)
		if scene.profile.accessories.get(slot) != expected_acc.id:
			scene.queue_free()
			return "%s slotu %s yerine %s oldu" % [slot, expected_acc.id, scene.profile.accessories.get(slot)]

		# Tekrar döndür: Aksesuar -> Yok (veya sonraki aksesuar)
		var next_step: int = 1
		while next_step <= available.size():
			scene.cycle_accessory(slot)
			next_step += 1
		# Tüm aksesuarlar dolaşılınca tekrar Yok olmalı
		if scene.profile.accessories.has(slot):
			scene.queue_free()
			return "%s slotu tam döngüden sonra Yok olmadı" % slot

	scene.queue_free()
	return ""


func test_profile_persistence() -> String:
	var scene: PetSelect = _make_scene()
	var test_path: String = "user://test_pet_select_save.cfg"

	scene.set_pet_index(0, false)
	var expected_pet: StringName = scene.profile.pet_id

	# Kafa ve sırt aksesuarlarını tak
	while scene.profile.accessories.has(&"head"):
		scene.cycle_accessory(&"head")
	scene.cycle_accessory(&"head")
	var expected_head: StringName = scene.profile.accessories.get(&"head", &"")

	while scene.profile.accessories.has(&"back"):
		scene.cycle_accessory(&"back")
	scene.cycle_accessory(&"back")
	var expected_back: StringName = scene.profile.accessories.get(&"back", &"")

	var save_err: Error = scene.save_selection(test_path)
	if save_err != OK:
		scene.queue_free()
		return "save_selection başarısız oldu: %d" % save_err

	var loaded: RefCounted = LocalProfile.load_or_default(test_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))

	if loaded.pet_id != expected_pet:
		scene.queue_free()
		return "Kaydedilen pet_id eşleşmedi: %s vs %s" % [loaded.pet_id, expected_pet]
	if loaded.accessories.get(&"head") != expected_head:
		scene.queue_free()
		return "Kaydedilen kafa aksesuarı eşleşmedi: %s vs %s" % [loaded.accessories.get(&"head"), expected_head]
	if loaded.accessories.get(&"back") != expected_back:
		scene.queue_free()
		return "Kaydedilen sırt aksesuarı eşleşmedi: %s vs %s" % [loaded.accessories.get(&"back"), expected_back]

	scene.queue_free()
	return ""


func test_button_heights_and_font_sizes() -> String:
	var scene: PetSelect = _make_scene()

	var buttons: Array[Node] = scene.find_children("*", "Button", true, false)
	for b: Node in buttons:
		var btn: Button = b as Button
		if btn.custom_minimum_size.y < 96.0:
			scene.queue_free()
			return "Buton %s yüksekliği 96'dan küçük: %f" % [btn.name, btn.custom_minimum_size.y]
		var font_size: int = btn.get_theme_font_size("font_size")
		if font_size < 28:
			scene.queue_free()
			return "Buton %s font_size 28'den küçük: %d" % [btn.name, font_size]

	var labels: Array[Node] = scene.find_children("*", "Label", true, false)
	for l: Node in labels:
		var lbl: Label = l as Label
		var font_size: int = lbl.get_theme_font_size("font_size")
		if font_size < 28:
			scene.queue_free()
			return "Label %s font_size 28'den küçük: %d" % [lbl.name, font_size]

	scene.queue_free()
	return ""
