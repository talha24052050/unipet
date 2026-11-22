extends RefCounted
## Kampüs keşfi: yürüyerek yaklaşınca keşif, ışınlanma sayılmaz, kayıt kalıcı.

const Discovery := preload("res://src/world/discovery.gd")
const LocalProfile := preload("res://src/core/local_profile.gd")

const PLACES: Array = [{"id": "a", "name": "A", "pos": [0.0, 0.0]}, {"id": "b", "name": "B", "pos": [100.0, 0.0]}]


func test_newly_found_radius() -> String:
	var f: PackedStringArray = Discovery.newly_found(Vector2(5, 5), PLACES, PackedStringArray(), 22.0)
	if f != PackedStringArray(["a"]):
		return "yarıçap içindeki A bulunmalı: %s" % f
	if not Discovery.newly_found(Vector2(5, 5), PLACES, PackedStringArray(["a"]), 22.0).is_empty():
		return "zaten keşfedilen tekrar sayılmamalı"
	return ""


func test_places_data_ids_unique() -> String:
	var pl: Array = Discovery.load_places()
	if pl.size() < 40:
		return "places.json yüklenemedi: %d" % pl.size()
	var seen: Dictionary = {}
	for p: Dictionary in pl:
		var id: String = str(p.get("id", ""))
		if id.is_empty() or seen.has(id):
			return "boş ya da tekrarlı id: %s" % id
		seen[id] = true
	return ""


func test_teleport_does_not_discover() -> String:
	var before: RefCounted = LocalProfile.load_or_default()
	var saved: PackedStringArray = before.get("discovered")
	var d: Node = Discovery.new()
	d.places = PLACES
	# ışınlanıp tam B'nin üstüne düşmek: yürüme yok → keşif yok
	d.tick(Vector3(60, 0, 0))
	d.tick(Vector3(100, 0, 0))
	var got: Array = []
	d.place_discovered.connect(func(p: Dictionary, _f: int, _t: int) -> void: got.append(p["id"]))
	d.tick(Vector3(101, 0, 0))
	if not got.is_empty():
		d.free()
		return "ışınlanma keşif saymamalı"
	# B'den uzaklaşıp yürüyerek geri gel
	for x: int in range(101, 140, 3):
		d.tick(Vector3(x, 0, 0))
	for x: int in range(140, 98, -3):
		d.tick(Vector3(x, 0, 0))
	d.free()
	var after: RefCounted = LocalProfile.load_or_default()
	var ok: bool = got == ["b"] and after.get("discovered").has("b")
	after.set("discovered", saved)
	after.call("save")
	return "" if ok else "yürüyerek gelince B keşfedilmeli: %s" % [got]
