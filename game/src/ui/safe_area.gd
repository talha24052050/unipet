class_name SafeArea
extends RefCounted
## iOS (Dynamic Island / çentik / Home Indicator) ve Android ekran güvenli alan hesabı.
## Fiziksel piksel cinsinden DisplayServer.get_display_safe_area() değerini
## canvas_items / expand viewport koordinatlarına ölçekler.


static func zero_insets() -> Dictionary:
	return {"left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0}


static func is_mobile_platform(os_name: String = "") -> bool:
	var name_to_check: String = OS.get_name() if os_name.is_empty() else os_name
	return name_to_check == "iOS" or name_to_check == "Android"


## Saf hesap (testler doğrudan çağırır): fiziksel pencere + safe_rect -> viewport inset'leri.
static func compute_insets(window_size: Vector2i, safe_rect: Rect2i, viewport_size: Vector2) -> Dictionary:
	if window_size.x <= 0 or window_size.y <= 0:
		return zero_insets()
	if safe_rect.size.x <= 0 or safe_rect.size.y <= 0:
		return zero_insets()
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return zero_insets()

	var sx: float = viewport_size.x / float(window_size.x)
	var sy: float = viewport_size.y / float(window_size.y)

	return {
		"left": maxf(0.0, float(safe_rect.position.x) * sx),
		"top": maxf(0.0, float(safe_rect.position.y) * sy),
		"right": maxf(0.0, float(window_size.x - safe_rect.end.x) * sx),
		"bottom": maxf(0.0, float(window_size.y - safe_rect.end.y) * sy),
	}


## Çalışan cihazın viewport koordinatlarındaki güvenli alan boşlukları.
## Masaüstünde (Windows/macOS/Linux) get_display_safe_area() ekran görev çubuğunu döndürdüğü
## için pencere içi kayma yapmaz, 0 döner.
static func get_viewport_insets(viewport: Viewport) -> Dictionary:
	if viewport == null or not is_mobile_platform():
		return zero_insets()
	var win_size: Vector2i = DisplayServer.window_get_size()
	var safe_rect: Rect2i = DisplayServer.get_display_safe_area()
	var vp_size: Vector2 = viewport.get_visible_rect().size
	return compute_insets(win_size, safe_rect, vp_size)
