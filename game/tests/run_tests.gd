extends SceneTree
## Bağımlılıksız mini test runner.
## Çalıştırma: godot --headless --path game -s res://tests/run_tests.gd
## tests/ altındaki test_*.gd dosyalarındaki test_* fonksiyonlarını çalıştırır.
## Her test fonksiyonu "" (geçti) ya da hata mesajı döndürür.

func _initialize() -> void:
	var failed := 0
	var passed := 0
	var dir := DirAccess.open("res://tests")
	for file in dir.get_files():
		if not (file.begins_with("test_") and file.ends_with(".gd")):
			continue
		var script: GDScript = load("res://tests/" + file)
		var inst = script.new()
		for m in script.get_script_method_list():
			var name: String = m["name"]
			if not name.begins_with("test_"):
				continue
			var result = inst.call(name)
			if result == null or str(result).is_empty():
				passed += 1
				print("  ok   %s::%s" % [file, name])
			else:
				failed += 1
				print("  FAIL %s::%s -> %s" % [file, name, result])
	print("\n%d geçti, %d başarısız" % [passed, failed])
	quit(1 if failed > 0 else 0)
