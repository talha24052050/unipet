class_name AppLifecycle
extends Node
## Mobil uygulama yaşam döngüsü (iOS/Android arka plana alma ve geri dönüş).
## Diğer modüller doğrudan Godot bildirimlerine bağlanmak yerine bu sinyalleri dinler.

signal app_paused
signal app_resumed(away_seconds: float)

var is_paused: bool = false
var pause_count: int = 0
var resume_count: int = 0

var _paused_at_msec: int = 0


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			handle_pause()
		NOTIFICATION_APPLICATION_RESUMED:
			handle_resume()


func handle_pause() -> void:
	if is_paused:
		return
	is_paused = true
	pause_count += 1
	_paused_at_msec = Time.get_ticks_msec()
	app_paused.emit()


func handle_resume() -> void:
	if not is_paused:
		return
	is_paused = false
	resume_count += 1
	var away_s: float = maxf(0.0, float(Time.get_ticks_msec() - _paused_at_msec) / 1000.0)
	app_resumed.emit(away_s)
