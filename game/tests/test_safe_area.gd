extends RefCounted
## Safe Area (iOS Dynamic Island / çentik / Home Indicator & Android) hesap ve adaptör testleri.

const SafeAreaMarginScript := preload("res://src/ui/safe_area_margin.gd")


func test_compute_insets_iphone_portrait() -> String:
	# iPhone 15 Pro (1179x2556) -> Dynamic Island top=177px, Home Indicator bottom=102px
	# canvas_items + expand viewport ~ 720x1560
	var win: Vector2i = Vector2i(1179, 2556)
	var safe: Rect2i = Rect2i(0, 177, 1179, 2556 - 177 - 102)
	var vp: Vector2 = Vector2(720.0, 1560.0)
	var insets: Dictionary = SafeArea.compute_insets(win, safe, vp)

	var expected_top: float = 177.0 * (1560.0 / 2556.0)
	var expected_bottom: float = 102.0 * (1560.0 / 2556.0)
	if not is_equal_approx(float(insets["top"]), expected_top):
		return "top inset yanlış: %f != %f" % [float(insets["top"]), expected_top]
	if not is_equal_approx(float(insets["bottom"]), expected_bottom):
		return "bottom inset yanlış: %f != %f" % [float(insets["bottom"]), expected_bottom]
	if not is_equal_approx(float(insets["left"]), 0.0) or not is_equal_approx(float(insets["right"]), 0.0):
		return "left/right inset 0 olmalı: %s" % str(insets)
	return ""


func test_compute_insets_invalid_window_returns_zero() -> String:
	var insets: Dictionary = SafeArea.compute_insets(Vector2i.ZERO, Rect2i(0, 0, 100, 100), Vector2(720, 1280))
	if float(insets["top"]) != 0.0 or float(insets["bottom"]) != 0.0:
		return "sıfır pencerede inset 0 dönmeli"
	return ""


func test_mobile_platform_detection() -> String:
	if not SafeArea.is_mobile_platform("iOS") or not SafeArea.is_mobile_platform("Android"):
		return "iOS ve Android mobil sayılmalı"
	if SafeArea.is_mobile_platform("Windows") or SafeArea.is_mobile_platform("Linux") or SafeArea.is_mobile_platform("macOS"):
		return "masaüstü platformları mobil sayılmamalı"
	return ""


func test_safe_area_margin_adds_to_base_margins() -> String:
	var m: MarginContainer = MarginContainer.new()
	m.add_theme_constant_override("margin_left", 24)
	m.add_theme_constant_override("margin_top", 40)
	m.add_theme_constant_override("margin_right", 24)
	m.add_theme_constant_override("margin_bottom", 30)
	m.set_script(SafeAreaMarginScript)
	m.call("apply_insets", {"left": 10.0, "top": 60.0, "right": 10.0, "bottom": 34.0})

	var ok: bool = (
		m.get_theme_constant("margin_left") == 34
		and m.get_theme_constant("margin_top") == 100
		and m.get_theme_constant("margin_right") == 34
		and m.get_theme_constant("margin_bottom") == 64
	)
	if not ok:
		m.free()
		return "SafeAreaMargin taban boşluklara inset ekleyemedi"

	# Sıfırlanınca taban değerlere dönmeli
	m.call("apply_insets", SafeArea.zero_insets())
	var reset_ok: bool = m.get_theme_constant("margin_top") == 40 and m.get_theme_constant("margin_bottom") == 30
	m.free()
	return "" if reset_ok else "SafeAreaMargin sıfırlanınca taban boşluğa dönmedi"


func test_main_scene_safe_area_hud_shifts_elements() -> String:
	var scene: PackedScene = load("res://scenes/main.tscn") as PackedScene
	if scene == null:
		return "main.tscn yüklenemedi"
	var inst: Node = scene.instantiate()
	var sa: Node = inst.get_node_or_null("UI/SafeAreaHud")
	if sa == null:
		inst.free()
		return "UI/SafeAreaHud bulunamadı"

	var pet_btn: Control = inst.get_node("UI/PetButton") as Control
	var conn_lbl: Control = inst.get_node("UI/ConnectionLabel") as Control
	var care_hud: Control = inst.get_node("UI/CareHud") as Control

	var base_pet_top: float = pet_btn.offset_top
	var base_conn_top: float = conn_lbl.offset_top

	sa.call("apply_insets", {"left": 0.0, "top": 50.0, "right": 0.0, "bottom": 34.0})

	var err: String = ""
	if not is_equal_approx(pet_btn.offset_top, base_pet_top + 50.0):
		err = "PetButton aşağı kaymadı: %f" % pet_btn.offset_top
	elif not is_equal_approx(conn_lbl.offset_top, base_conn_top - 34.0):
		err = "ConnectionLabel yukarı kaymadı: %f" % conn_lbl.offset_top
	elif not is_equal_approx(care_hud.offset_top, 50.0) or not is_equal_approx(care_hud.offset_bottom, -34.0):
		err = "CareHud safe area inset almadı (%f, %f)" % [care_hud.offset_top, care_hud.offset_bottom]

	inst.free()
	return err
