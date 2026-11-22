extends NavigationRegion3D
## Bölgenin yürüme haritası (navmesh).
## Önce önceden pişirilmiş dosyaya bakar: res://data/zones/<bölge>_navmesh.res
## (tools/nav/bake_zone_navmeshes.gd üretir). Dosyanın kaydettiği kaynak özeti, bölge verisinin
## (greybox + prop JSON) şimdiki özetiyle aynıysa onu kullanır; değilse (veri değişmiş / dosya yok)
## açılışta arka planda pişirir. Her iki durumda da `bake_finished` yayınlanır.

const BAKED_PATH: String = "res://data/zones/%s_navmesh.res"
const META_HASH: String = "source_hash"

## Araç scripti önceden pişirirken true yapar (kayıtlı dosyayı yok saymak için).
static var force_bake: bool = false

## Son yüklemede hazır dosya mı kullanıldı (test/teşhis için).
var used_prebaked: bool = false


func _ready() -> void:
	# Çocuklar (ör. GreyboxBuilder, PropPlacer) _ready'de kurulur; bir kare sonra karar ver.
	await get_tree().process_frame
	var zone: Dictionary = _zone_def()
	if not force_bake and not zone.is_empty() and _try_prebaked(zone):
		return
	var started: int = Time.get_ticks_msec()
	bake_finished.connect(func() -> void:
		print_verbose("navmesh pişti: %d ms" % (Time.get_ticks_msec() - started)), CONNECT_ONE_SHOT)
	bake_navigation_mesh(true)


func _try_prebaked(zone: Dictionary) -> bool:
	var path: String = BAKED_PATH % zone["id"]
	if not ResourceLoader.exists(path):
		return false
	var nm: NavigationMesh = load(path) as NavigationMesh
	if nm == null or str(nm.get_meta(META_HASH, "")) != source_hash(zone):
		return false
	navigation_mesh = nm
	used_prebaked = true
	bake_finished.emit.call_deferred()
	return true


func _zone_def() -> Dictionary:
	if Services.zones == null or not Services.zones.has(Services.current_zone):
		return {}
	return Services.zones.get_zone(Services.current_zone)


## Bölgenin yürünebilirliğini belirleyen verilerin özeti (greybox + prop yerleşimi).
static func source_hash(zone: Dictionary) -> String:
	var text: String = ""
	var files: Array[String] = [str(zone.get("greybox", "")), str(zone.get("props", ""))]
	# Yeşil doku (ağaç çarpışmaları navmesh'e girer): greybox ile aynı klasörde <ad>_greenery.json
	files.append(files[0].replace("_greybox.json", "_greenery.json"))
	for p: String in files:
		if not p.is_empty() and FileAccess.file_exists(p):
			text += FileAccess.get_file_as_string(p)
	# Satır sonu farkı (Windows CRLF / CI LF) özeti değiştirmesin.
	return text.replace("\r\n", "\n").sha256_text().substr(0, 16)
