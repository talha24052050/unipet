extends RefCounted
## iOS ön hazırlık doğrulamaları: şeffaflıksız ikon seti ve export preset şablonu.

const REQUIRED_SIZES: Array[int] = [1024, 180, 167, 152, 120, 80, 76, 40]


func test_ios_icons_exist_and_opaque() -> String:
	for sz: int in REQUIRED_SIZES:
		var path: String = "res://assets/icons/ios/icon_%d.png" % sz
		if not FileAccess.file_exists(path):
			return "iOS ikonu eksik: %s" % path
		var img: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
		if img == null or img.is_empty():
			return "iOS ikonu okunamadı: %s" % path
		if img.get_width() != sz or img.get_height() != sz:
			return "iOS ikonu boyutu yanlış (%s): %dx%d" % [path, img.get_width(), img.get_height()]
		if img.detect_alpha() != Image.ALPHA_NONE:
			return "iOS ikonu şeffaflık (alpha) içermemeli: %s" % path
	return ""


func test_ci_export_presets_has_ios() -> String:
	var cfg_path: String = ProjectSettings.globalize_path("res://").path_join("../tools/ci/export_presets.cfg")
	if not FileAccess.file_exists(cfg_path):
		return "tools/ci/export_presets.cfg bulunamadı"
	var text: String = FileAccess.get_file_as_string(cfg_path)
	if not text.contains('platform="iOS"'):
		return "export_presets.cfg içinde iOS preset yok"
	if not text.contains('application/bundle_identifier="io.github.talha24052050.unipet"'):
		return "iOS bundle_identifier eksik veya farklı"
	if not text.contains('icons/app_store_1024x1024="res://assets/icons/ios/icon_1024.png"'):
		return "iOS 1024x1024 ikon yolu eksik"
	return ""
