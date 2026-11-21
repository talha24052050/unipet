extends SceneTree
## Her bölgenin yürüme haritasını önceden pişirir → game/data/zones/<id>_navmesh.res
## Kullanım: godot --headless --path game -s <repo>/tools/nav/bake_zone_navmeshes.gd [-- bölge_id ...]
## Bölge verisi (greybox / prop JSON) değişince yeniden çalıştır; çalıştırılmazsa oyun açılışta pişirir (daha yavaş).

## Çalışma zamanında yüklenir: -s scriptleri derlenirken autoload'lar (Services) henüz yok.
var NavRegion: GDScript


func _initialize() -> void:
	await process_frame
	NavRegion = load("res://src/world/runtime_nav_region.gd")
	var services: Node = root.get_node("Services")
	var zones: RefCounted = services.get("zones")
	var only: PackedStringArray = OS.get_cmdline_user_args()
	NavRegion.force_bake = true
	var failed: int = 0
	for id: String in zones.ids():
		if not only.is_empty() and not id in only:
			continue
		services.set("current_zone", id)
		var scene: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
		root.add_child(scene)
		var region: NavigationRegion3D = scene.get_node("World")
		var started: int = Time.get_ticks_msec()
		await region.bake_finished
		var nm: NavigationMesh = region.navigation_mesh.duplicate() as NavigationMesh
		nm.set_meta("source_hash", NavRegion.call("source_hash", zones.get_zone(id)))
		var path: String = "res://data/zones/%s_navmesh.res" % id
		var err: Error = ResourceSaver.save(nm, path, ResourceSaver.FLAG_COMPRESS)
		print("%s: %d poligon, %d ms → %s (%s)" % [id, nm.get_polygon_count(), Time.get_ticks_msec() - started, path, "ok" if err == OK else "HATA %d" % err])
		if err != OK or nm.get_polygon_count() == 0:
			failed += 1
		scene.queue_free()
		await process_frame
		await process_frame
	NavRegion.force_bake = false
	quit(1 if failed > 0 else 0)
