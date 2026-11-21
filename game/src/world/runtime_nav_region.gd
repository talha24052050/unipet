extends NavigationRegion3D
## Çocuk geometriden navigation mesh'i açılışta üretir (greybox için yeterli).
## Kalıcı haritada (Parça 5) editörde pişirilmiş mesh kullanılacak.


func _ready() -> void:
	# CSG şekilleri ilk karede oluşur; ondan sonra pişir.
	await get_tree().process_frame
	bake_navigation_mesh(false)
