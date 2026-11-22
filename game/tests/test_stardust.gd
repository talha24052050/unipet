extends RefCounted
## Yıldız tozu kuralları: sunucuyla aynı günlük noktalar, toplama, satın alma, fiyat tutarlılığı.

const R := preload("res://src/collect/stardust_rules.gd")


func test_daily_indices_match_server() -> String:
	# node ile index.js dailyIndices(20000, 568, 40) ve (7, 10, 4) çıktısı
	var a: PackedInt32Array = R.daily_indices(20000, 568, 40)
	if a.size() != 40 or a.slice(0, 8) != PackedInt32Array([3, 21, 25, 35, 52, 73, 83, 85]):
		return "sunucuyla farklı: %s" % a.slice(0, 8)
	if R.daily_indices(7, 10, 4) != PackedInt32Array([1, 4, 6, 8]):
		return "küçük örnek farklı: %s" % R.daily_indices(7, 10, 4)
	return ""


func test_points_data() -> String:
	var pts: Array = R.load_points()
	return "" if pts.size() > 300 else "nokta havuzu küçük: %d" % pts.size()


func test_collect_and_buy() -> String:
	var pts: Array = R.load_points()
	var w: Dictionary = R.normalize({}, 20000)
	var i: int = R.daily_indices(20000, pts.size(), R.DAILY)[0]
	var p: Vector3 = Vector3(float(pts[i][0]), 0, float(pts[i][1]))
	if R.collect(w, i, p + Vector3(20, 0, 0), pts):
		return "uzaktan toplanmamalı"
	if not R.collect(w, i, p, pts) or R.collect(w, i, p, pts):
		return "bir kez toplanmalı"
	if R.view(w, pts.size())["points"].has(i) or int(w["dust"]) != 1:
		return "toplanan listeden düşmeli"
	if R.buy(w, "cape", 40) != "yıldız tozu yetmiyor":
		return "parasız alınmamalı"
	w["dust"] = 45
	if R.buy(w, "cape", 40) != "" or int(w["dust"]) != 5 or R.buy(w, "cape", 40) != "zaten sende":
		return "satın alma yanlış"
	if R.normalize(w, 20001)["taken"].size() != 0:
		return "yeni gün alınanları sıfırlamalı"
	return ""


func test_shop_prices_match_server() -> String:
	var js: String = FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join("../server/nakama/modules/index.js"))
	var re: RegEx = RegEx.create_from_string("var SHOP = [{]([^}]*)[}]")
	var m: RegExMatch = re.search(js)
	if m == null:
		return "index.js SHOP bulunamadı"
	var server: Dictionary = {}
	for part: String in m.get_string(1).split(",", false):
		var kv: PackedStringArray = part.split(":")
		server[kv[0].strip_edges()] = int(kv[1].strip_edges())
	var reg: RefCounted = (load("res://src/characters/accessory_registry.gd") as GDScript).new()
	reg.call("load_from_dir", "res://data/accessories")
	var client: Dictionary = {}
	for d: AccessoryDef in reg.call("all"):
		if d.price > 0:
			client[str(d.id)] = d.price
	return "" if client == server else "fiyatlar farklı: istemci %s, sunucu %s" % [client, server]
