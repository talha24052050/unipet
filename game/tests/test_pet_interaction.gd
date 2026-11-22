extends RefCounted
## Pete dokunma: ekran uzayında seçim, kendi petini sevme, uzak dokunuş yürümeye kalır.

const PetInteraction := preload("res://src/player/pet_interaction.gd")


func test_heart_texture() -> String:
	var t: Texture2D = PetInteraction.heart_texture()
	if t == null or t.get_width() != 64:
		return "kalp dokusu yok"
	var img: Image = t.get_image()
	if img.get_pixel(32, 30).a < 0.9 or img.get_pixel(1, 1).a > 0.01:
		return "kalp şekli yanlış (orta dolu, köşe boş olmalı)"
	return ""


func test_nearest_pick() -> String:
	var pts: Array[Vector2] = [Vector2(100, 100), Vector2.INF, Vector2(130, 100)]
	if PetInteraction.nearest(Vector2(125, 102), pts, 90.0) != 2:
		return "en yakın seçilmeli"
	if PetInteraction.nearest(Vector2(600, 600), pts, 90.0) != -1:
		return "uzak dokunuş pet seçmemeli (yürüme)"
	return ""


func test_pet_own_cooldown() -> String:
	var pet: Node3D = Node3D.new()
	var pi: Node = PetInteraction.new()
	pi.player = pet
	var petted: Array = []
	pi.pet_petted.connect(func() -> void: petted.append(1))
	pi.pet_own()
	pi.pet_own()  # bekleme süresinde: sayılmaz
	pi._process(1.0)
	pi.pet_own()
	pi.free()
	pet.free()
	return "" if petted.size() == 2 else "sevme bekleme süresi yanlış: %d" % petted.size()
