extends SceneTree
## Bağımlılıksız mini test runner.
## Çalıştırma: godot --headless --path game -s res://tests/run_tests.gd
## tests/ altındaki test_*.gd dosyalarındaki test_* fonksiyonlarını çalıştırır.
## Her test fonksiyonu "" (geçti) ya da hata mesajı döndürür.
## Test sırasında SCRIPT ERROR / ERROR oluşursa test dönüş değerinden bağımsız BAŞARISIZ sayılır
## (Godot hata veren fonksiyondan tipinin varsayılanını, yani "" döndürür; dönüş değeri yetmez).


class ErrorCounter extends Logger:
	var count: int = 0
	var last: String = ""

	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		count += 1
		last = rationale if not rationale.is_empty() else code

	func _log_message(_message: String, _error: bool) -> void:
		pass


## Bu durumlar bilinen ve testlerde zararsız motor hatalarıdır (ör. test düğümü erken free edilince).
const IGNORED_ERRORS: PackedStringArray = []


func _initialize() -> void:
	var counter: ErrorCounter = ErrorCounter.new()
	OS.add_logger(counter)
	var failed := 0
	var passed := 0
	var dir := DirAccess.open("res://tests")
	for file in dir.get_files():
		if not (file.begins_with("test_") and file.ends_with(".gd")):
			continue
		var before_load: int = counter.count
		var script: GDScript = load("res://tests/" + file)
		if script == null or not script.can_instantiate() or counter.count > before_load:
			failed += 1
			print("  FAIL %s -> script derlenemedi (%s)" % [file, counter.last])
			continue
		var inst = script.new()
		for m in script.get_script_method_list():
			var name: String = m["name"]
			if not name.begins_with("test_"):
				continue
			var before: int = counter.count
			var result = inst.call(name)
			var errors: int = counter.count - before
			if errors == 0 and result is String and (result as String).is_empty():
				passed += 1
				print("  ok   %s::%s" % [file, name])
			else:
				failed += 1
				var why: String = "%d hata: %s" % [errors, counter.last] if errors > 0 else str(result)
				print("  FAIL %s::%s -> %s" % [file, name, why])
	print("\n%d geçti, %d başarısız" % [passed, failed])
	OS.remove_logger(counter)
	quit(1 if failed > 0 else 0)
