extends RefCounted

const StreetLights := preload("res://src/world/street_lights.gd")
const DayNight := preload("res://src/world/day_night.gd")
const ORTABAHCE_PROPS: String = "res://data/zones/ortabahce_props.json"


func test_bulb_count_matches_lamp_count() -> String:
	var data: Dictionary = StreetLights.load_data(ORTABAHCE_PROPS)
	if data.is_empty():
		return "ortabahce_props.json verisi okunamadı"

	var expected_lamps: int = 0
	for item_var: Variant in data.get("props", []):
		var item: Dictionary = item_var
		if str(item.get("type", "")) == "lamp":
			expected_lamps += 1

	if expected_lamps == 0:
		return "ortabahce_props.json içinde hiç lamba bulunamadı"

	var sl: Node3D = StreetLights.new()
	sl.follow_current_zone = false
	sl.data_path = ORTABAHCE_PROPS
	sl.setup_lamps(data)

	if sl.get_bulb_count() != expected_lamps:
		var actual: int = sl.get_bulb_count()
		sl.free()
		return "ampul sayısı lamba sayısına eşit olmalı: beklenen %d, bulunan %d" % [expected_lamps, actual]

	if sl.bulb_count != expected_lamps:
		var actual_prop: int = sl.bulb_count
		sl.free()
		return "bulb_count özelliği beklenen %d olmalı, bulunan %d" % [expected_lamps, actual_prop]

	sl.free()
	return ""


func test_night_mode_active_lights() -> String:
	var data: Dictionary = StreetLights.load_data(ORTABAHCE_PROPS)
	var sl: Node3D = StreetLights.new()
	sl.follow_current_zone = false
	sl.data_path = ORTABAHCE_PROPS
	sl.setup_lamps(data)

	sl.set_day_mode(false)
	var active_count: int = sl.get_active_light_count()
	if active_count > 4:
		sl.free()
		return "gece modunda aktif OmniLight sayısı <= 4 olmalı, bulunan: %d" % active_count
	if active_count == 0:
		sl.free()
		return "gece modunda lamba varsa aktif OmniLight > 0 olmalı"

	# Işıkların özellikleri: menzil ~8m, gölge kapalı
	var lights: Array[OmniLight3D] = sl.get_lights()
	if lights.size() != 4:
		sl.free()
		return "ışık havuzu 4 adet OmniLight3D içermeli"

	for light: OmniLight3D in lights:
		if absf(light.omni_range - 8.0) > 0.1:
			sl.free()
			return "omni_range 8.0 olmalı, bulunan: %.1f" % light.omni_range
		if light.shadow_enabled:
			sl.free()
			return "gölge KAPALI olmalı (shadow_enabled = false)"

	# Oyuncu hareket ettiğinde en yakın lambaların seçilmesi
	var dummy_player := Node3D.new()
	var lamp_positions: Array[Vector3] = sl.get_lamp_positions()
	dummy_player.position = lamp_positions[0]
	sl.player = dummy_player
	sl.update_lights()

	var first_light_pos: Vector3 = lights[0].position
	var found_close: bool = false
	for light: OmniLight3D in lights:
		if light.visible and light.position.distance_to(lamp_positions[0]) < 0.1:
			found_close = true
			break
	if not found_close:
		dummy_player.free()
		sl.free()
		return "oyuncunun bulunduğu lambada aktif bir ışık olmalı"

	# Oyuncuyu uzak bir lambaya taşı
	var far_lamp: Vector3 = lamp_positions[lamp_positions.size() - 1]
	dummy_player.position = far_lamp
	sl.update_lights()

	var found_far_close: bool = false
	for light: OmniLight3D in lights:
		if light.visible and light.position.distance_to(far_lamp) < 0.1:
			found_far_close = true
			break
	if not found_far_close:
		dummy_player.free()
		sl.free()
		return "oyuncu taşındığında yeni en yakın lambaya ışık taşınmalı"

	dummy_player.free()
	sl.free()
	return ""


func test_day_mode_zero_active_lights() -> String:
	var data: Dictionary = StreetLights.load_data(ORTABAHCE_PROPS)
	var sl: Node3D = StreetLights.new()
	sl.follow_current_zone = false
	sl.data_path = ORTABAHCE_PROPS
	sl.setup_lamps(data)

	sl.set_day_mode(true)
	var active_count: int = sl.get_active_light_count()
	if active_count != 0:
		sl.free()
		return "gündüz modunda aktif OmniLight sayısı 0 olmalı, bulunan: %d" % active_count

	for light: OmniLight3D in sl.get_lights():
		if light.visible:
			sl.free()
			return "gündüz modunda tüm OmniLight3D'ler gizli/kapalı olmalı"

	sl.free()
	return ""


func test_zone_without_props_no_error() -> String:
	var sl: Node3D = StreetLights.new()
	sl.follow_current_zone = false
	sl.data_path = ""
	sl._ready()

	if sl.get_bulb_count() != 0:
		sl.free()
		return "prop'suz bölgede ampul sayısı 0 olmalı"

	sl.set_day_mode(false)
	if sl.get_active_light_count() != 0:
		sl.free()
		return "prop'suz bölgede gece modunda da aktif ışık olmamalı"

	# fef bölgesi prop verisi boş ("")
	if Services.zones != null and Services.zones.has("fef"):
		var old_zone: String = Services.current_zone
		Services.current_zone = "fef"
		var sl_fef: Node3D = StreetLights.new()
		sl_fef.follow_current_zone = true
		sl_fef._ready()
		var count: int = sl_fef.get_bulb_count()
		sl_fef.free()
		Services.current_zone = old_zone
		if count != 0:
			sl.free()
			return "fef bölgesinde prop bulunmamalı ve 0 ampul olmalı"

	sl.free()
	return ""


func test_day_night_node_integration() -> String:
	var sl: Node3D = StreetLights.new()
	sl.follow_current_zone = false
	sl.data_path = ORTABAHCE_PROPS
	var data: Dictionary = StreetLights.load_data(ORTABAHCE_PROPS)
	sl.setup_lamps(data)

	var dn: Node = DayNight.new()
	sl.day_night = dn

	# Öğlen (12:00) -> gündüz
	dn.set("fixed_hour", 12.0)
	sl.check_day_night()
	sl.update_lights()
	if not sl.is_day():
		dn.free()
		sl.free()
		return "saat 12:00'de is_day true olmalı"
	if sl.get_active_light_count() != 0:
		dn.free()
		sl.free()
		return "saat 12:00'de aktif ışık 0 olmalı"

	# Gece (02:00) -> gece
	dn.set("fixed_hour", 2.0)
	sl.check_day_night()
	sl.update_lights()
	if sl.is_day():
		dn.free()
		sl.free()
		return "saat 02:00'de is_day false olmalı"
	if sl.get_active_light_count() == 0 or sl.get_active_light_count() > 4:
		var act: int = sl.get_active_light_count()
		dn.free()
		sl.free()
		return "saat 02:00'de aktif ışık 1..4 arasında olmalı, bulunan: %d" % act

	dn.free()
	sl.free()
	return ""


func test_main_scene_integration() -> String:
	var scene: PackedScene = load("res://scenes/main.tscn")
	if scene == null:
		return "main.tscn yüklenemedi"

	var main: Node = scene.instantiate()
	var sl = main.get_node_or_null("World/StreetLights")
	if sl == null:
		main.free()
		return "main.tscn içinde World/StreetLights düğümü bulunamadı"

	var script_obj = sl.get_script()
	if script_obj == null or not (script_obj.resource_path as String).ends_with("street_lights.gd"):
		main.free()
		return "World/StreetLights düğümünün scripti street_lights.gd olmalı"

	if sl.get("day_night") == null:
		main.free()
		return "World/StreetLights day_night düğümüne bağlı olmalı"

	main.free()
	return ""
