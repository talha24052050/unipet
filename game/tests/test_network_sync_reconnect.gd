extends RefCounted


func test_reconnect_backoff_covers_long_outage() -> String:
	var NS: GDScript = load("res://src/net/network_sync.gd")
	var total: float = 0.0
	for i: int in NS.MAX_RECONNECT_ATTEMPTS:
		total += NS.reconnect_delay(i)
	if NS.reconnect_delay(0) > 5.0:
		return "ilk deneme çabuk olmalı"
	if NS.reconnect_delay(20) != NS.RECONNECT_DELAY_MAX:
		return "üst sınır uygulanmıyor"
	if total < 600.0:
		return "en az 10 dk denemeli: %d sn" % int(total)
	return ""
