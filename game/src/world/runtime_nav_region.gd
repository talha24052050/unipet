extends NavigationRegion3D
## Çocuk geometriden navigation mesh'i açılışta üretir (greybox için yeterli).
## Kalıcı haritada (Parça 5) editörde pişirilmiş mesh kullanılacak.


func _ready() -> void:
	# Çocuklar (ör. GreyboxBuilder) _ready'de kurulur; bir kare bekleyip arka planda pişir.
	await get_tree().process_frame
	var started: int = Time.get_ticks_msec()
	bake_finished.connect(func() -> void:
		print_verbose("navmesh pişti: %d ms" % (Time.get_ticks_msec() - started)), CONNECT_ONE_SHOT)
	bake_navigation_mesh(true)
