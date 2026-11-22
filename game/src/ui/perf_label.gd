extends Label
## Geliştirme sürümünde: FPS + çizim çağrısı; açılış süresini loga yazar (adb logcat -s godot).
## Yayın sürümünde kendini gizler.

const UPDATE_S: float = 0.5

var _t: float = 0.0
var _reported_ready: bool = false


func _ready() -> void:
	if Config.IS_RELEASE:
		queue_free()
		return
	add_theme_font_size_override("font_size", 22)
	var region: NavigationRegion3D = get_node_or_null("../../World") as NavigationRegion3D
	if region != null:
		region.bake_finished.connect(_on_world_ready, CONNECT_ONE_SHOT)


func _on_world_ready() -> void:
	if not _reported_ready:
		_reported_ready = true
		print("[UniPet] dünya hazır: uygulama başlangıcından %d ms" % Time.get_ticks_msec())


func _process(delta: float) -> void:
	_t += delta
	if _t < UPDATE_S:
		return
	_t = 0.0
	var fps: float = Performance.get_monitor(Performance.TIME_FPS)
	var draws: float = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	text = "%d FPS · %d çizim" % [int(fps), int(draws)]
