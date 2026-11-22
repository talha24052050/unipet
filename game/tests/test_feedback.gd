extends RefCounted

const Feedback := preload("res://src/net/feedback.gd")


func test_validation() -> String:
	if Feedback.is_valid("ab") or not Feedback.is_valid("  güzel oyun  "):
		return "uzunluk kontrolü yanlış"
	if Feedback.clean("x".repeat(1500)).length() != Feedback.MAX_LEN:
		return "uzun metin kırpılmadı"
	return ""


func test_dev_build_saves_locally() -> String:
	if Config.AUTH_BACKEND == "supabase":
		return ""
	# Testler Services._ready'den önce çalışabiliyor: kendi örneğimizi kur.
	var fb: Node = Feedback.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(fb)
	var before: int = FileAccess.get_file_as_string(Feedback.LOCAL_LOG).length() if FileAccess.file_exists(Feedback.LOCAL_LOG) else 0
	var got: Array = []
	var cb: Callable = func(ok: bool, _m: String) -> void: got.append(ok)
	fb.sent.connect(cb)
	fb.send("test geri bildirimi")
	fb.sent.disconnect(cb)
	fb.free()
	if got != [true]:
		return "yerel kayıt başarısız: %s" % [got]
	var text: String = FileAccess.get_file_as_string(Feedback.LOCAL_LOG)
	if text.length() <= before or not text.contains("test geri bildirimi"):
		return "log'a yazılmadı"
	# temizlik: testin eklediği satırı geri al
	var f: FileAccess = FileAccess.open(Feedback.LOCAL_LOG, FileAccess.WRITE)
	f.store_string(text.left(before))
	f.close()
	return ""


func test_settings_panel_has_feedback() -> String:
	var P: GDScript = load("res://src/ui/settings_panel.gd")
	var p: Control = P.new()
	var ok: bool = p.find_child("FeedbackInput", true, false) != null and p.find_child("FeedbackButton", true, false) != null
	p.free()
	return "" if ok else "panelde geri bildirim alanı yok"
