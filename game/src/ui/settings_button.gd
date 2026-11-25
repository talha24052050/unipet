extends Button
## Oyun ekranındaki "Ayarlar" butonu: ayarlar panelini açar/kapatır.

const SettingsPanel := preload("res://src/ui/settings_panel.gd")

var panel: SettingsPanel = null


func _ready() -> void:
	if text.is_empty():
		text = "Ayarlar"
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	_ensure_panel()


func _exit_tree() -> void:
	# Panel kardeş düğüm: sahne kapanırken ebeveyn meşgul olabilir, remove_child yerine sıraya al.
	if panel != null and is_instance_valid(panel):
		panel.queue_free()
		panel = null


func _on_pressed() -> void:
	Sfx.play(&"ui_click")
	toggle_panel()


func toggle_panel() -> void:
	_ensure_panel()
	if panel.is_open():
		panel.close()
	else:
		panel.open()


func open_panel() -> void:
	_ensure_panel()
	panel.open()


func close_panel() -> void:
	if panel != null and is_instance_valid(panel):
		panel.close()


func _ensure_panel() -> void:
	if panel == null or not is_instance_valid(panel):
		panel = SettingsPanel.new()
		panel.name = "SettingsPanel"  # adı "...Panel" ile bitince Ring biniş butonu panel açıkken gizlenir (campus_transit)
		var p: Node = get_parent()
		if p == null:
			add_child(panel)
		elif p.is_node_ready():
			p.add_child(panel)
		else:
			# Ebeveyn hâlâ kuruluyor (_ready sırasında): doğrudan add_child başarısız olur ve panel hiç ekrana girmez.
			p.add_child.call_deferred(panel)
