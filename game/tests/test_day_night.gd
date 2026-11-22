extends RefCounted

const DayNight := preload("res://src/world/day_night.gd")


func test_noon_bright_night_dark() -> String:
	var noon: Dictionary = DayNight.sample(12.5)
	var night: Dictionary = DayNight.sample(2.0)
	var dusk: Dictionary = DayNight.sample(18.2)
	if not noon["is_day"] or float(noon["elevation_deg"]) < 55.0 or float(noon["light_energy"]) < 0.95:
		return "öğlen parlak ve güneş yüksek olmalı: %s" % noon
	if night["is_day"] or float(night["light_energy"]) > 0.5:
		return "gece loş olmalı: %s" % night
	if (dusk["light_color"] as Color).g >= (noon["light_color"] as Color).g:
		return "günbatımı ışığı daha sıcak (turuncu) olmalı"
	return ""


func test_day_night_node_applies() -> String:
	var dn: Node = DayNight.new()
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	dn.set("sun", sun)
	dn.call("apply", 12.5)
	var day_energy: float = sun.light_energy
	dn.call("apply", 23.0)
	var night_energy: float = sun.light_energy
	dn.free()
	sun.free()
	if day_energy <= night_energy:
		return "ışık şiddeti saate göre değişmeli"
	return ""
