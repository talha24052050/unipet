extends RefCounted
## Kampüs kedileri: veri, kurulum, dokununca miyav.

const Cats := preload("res://src/world/campus_cats.gd")
const Cat := preload("res://src/world/campus_cat.gd")


func test_spots() -> String:
	var spots: Array = Cats.load_spots()
	var n: int = 0
	for s: Dictionary in spots:
		n += int(s["count"])
	return "" if spots.size() >= 6 and n >= 10 and n <= 20 else "kedi yerleri/sayısı beklenmedik: %d yer %d kedi" % [spots.size(), n]


func test_cat_builds_and_meows() -> String:
	var c: Node3D = Cat.new()
	c.setup(42, Vector3(1, 0, 2), 8.0)
	var meshes: int = c.find_children("*", "MeshInstance3D", true, false).size()
	var before: int = Sfx.play_count
	c.pet()
	c.pet()  # bekleme süresinde ikinci miyav yok
	var err: String = ""
	if meshes != 3:
		err = "kedi 3 birleşik ağ olmalı (gövde, baş, kuyruk): %d" % meshes
	elif Sfx.play_count - before != 1 or Sfx.last_played != &"meow":
		err = "dokununca bir kez miyavlamalı"
	elif c.state != &"sit":
		err = "dokununca oturmalı"
	c.free()
	return err


func test_love_sign_builds() -> String:
	var LS: GDScript = load("res://src/world/love_signs.gd")
	var n: Node3D = LS.call("build_sign")
	var meshes: int = n.find_children("*", "MeshInstance3D", true, false).size()
	var bodies: int = n.find_children("*", "StaticBody3D", true, false).size()
	n.free()
	return "" if meshes == 4 and bodies == 1 else "I ❤ YTÜ: %d parça, %d çarpışma" % [meshes, bodies]
