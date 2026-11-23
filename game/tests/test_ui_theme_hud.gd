extends RefCounted
## Ortak UI teması ve ana ekran HUD yerleşim/çakışma testleri.


func test_unipet_theme_loads_with_variations() -> String:
	var theme: Theme = load("res://assets/ui/unipet_theme.tres") as Theme
	if theme == null:
		return "unipet_theme.tres yüklenemedi"

	for state: StringName in [&"normal", &"hover", &"pressed", &"disabled"]:
		for tname: StringName in [&"Button", &"HudButton", &"ActionButton", &"RoundActionButton", &"PrimaryButton"]:
			if not theme.has_stylebox(state, tname):
				return "%s için %s stylebox eksik" % [tname, state]

	for pname: StringName in [&"PanelContainer", &"HudStatusPanel", &"HudPill", &"ToastPanel"]:
		if not theme.has_stylebox(&"panel", pname):
			return "%s için panel stylebox eksik" % pname

	return ""


func test_main_hud_anchors_and_uniform_buttons() -> String:
	var scene: PackedScene = load("res://scenes/main.tscn") as PackedScene
	if scene == null:
		return "main.tscn yüklenemedi"
	var inst: Node = scene.instantiate()
	if inst == null:
		return "main.tscn instantiate edilemedi"

	# Alt-sol etiketler alt kenara sabitlenmeli (uzun ekranlarda havada kalmamalı)
	for lname: String in ["UI/ConnectionLabel", "UI/PerfLabel"]:
		var lbl: Control = inst.get_node_or_null(lname) as Control
		if lbl == null:
			inst.free()
			return "%s bulunamadı" % lname
		if not is_equal_approx(lbl.anchor_top, 1.0) or not is_equal_approx(lbl.anchor_bottom, 1.0):
			inst.free()
			return "%s alt kenara anchor'lanmamış (anchor_top=%f)" % [lname, lbl.anchor_top]

	# Sağ üst butonlar eşit boyutlu (≥96 px) ve HudButton varyasyonlu olmalı
	var expected_h: float = -1.0
	for bname: String in ["UI/PetButton", "UI/MapButton", "UI/SettingsButton"]:
		var btn: Button = inst.get_node_or_null(bname) as Button
		if btn == null:
			inst.free()
			return "%s bulunamadı" % bname
		var h: float = btn.offset_bottom - btn.offset_top
		if h < 96.0:
			inst.free()
			return "%s yüksekliği ≥96 px olmalı (%f)" % [bname, h]
		if expected_h < 0.0:
			expected_h = h
		elif not is_equal_approx(h, expected_h):
			inst.free()
			return "%s yüksekliği diğerleriyle eşit değil (%f != %f)" % [bname, h, expected_h]
		if btn.theme_type_variation != &"HudButton":
			inst.free()
			return "%s HudButton varyasyonuna sahip olmalı" % bname

	inst.free()
	return ""


func test_stardust_pill_follows_bars_panel_without_overlap() -> String:
	var follower_script: GDScript = load("res://src/ui/hud_follow_below.gd") as GDScript
	if follower_script == null:
		return "hud_follow_below.gd yüklenemedi"

	var root: Control = Control.new()
	var target: Control = Control.new()
	target.name = "Target"
	target.position = Vector2(24.0, 60.0)
	target.size = Vector2(352.0, 140.0)
	root.add_child(target)

	var pill: Control = Control.new()
	pill.set_script(follower_script)
	pill.set("target_path", NodePath("../Target"))
	pill.set("gap", 10.0)
	pill.set("fallback_top", 60.0)
	root.add_child(pill)

	(Engine.get_main_loop() as SceneTree).root.add_child(root)
	pill.call("sync_position")
	var y1: float = pill.position.y
	if not is_equal_approx(y1, 210.0):
		root.free()
		return "İlk konum 210.0 olmalı, %f bulundu" % y1

	# Hedef büyüyünce (ör. MoodWarningLabel açılınca) pill aşağı kaymalı
	target.size = Vector2(352.0, 200.0)
	pill.call("sync_position")
	var y2: float = pill.position.y
	if not is_equal_approx(y2, 270.0):
		root.free()
		return "Büyüyen hedef sonrası konum 270.0 olmalı, %f bulundu" % y2

	# Hedef gizlenince fallback_top'a dönmeli
	target.visible = false
	pill.call("sync_position")
	var y3: float = pill.position.y
	root.free()
	if not is_equal_approx(y3, 60.0):
		return "Hedef gizlenince konum 60.0 olmalı, %f bulundu" % y3

	return ""
