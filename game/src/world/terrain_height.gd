class_name TerrainHeight
extends RefCounted
## Kampüs yükseklik haritası (DEM): (x, z) konumundaki gerçek zemin kotunu verir.
## Zemin mesh'iyle birebir aynı üçgenleme (i00-i10-i11 / i00-i11-i01) üzerinden barisentrik
## enterpolasyon yapar; böylece yollar ve nesneler zemin üçgenleriyle milimetrik örtüşür.
## Config.TERRAIN_ENABLED = false yapılırsa tüm sorgular 0.0 döner.

static var active: TerrainHeight = null
static var enabled: bool = Config.TERRAIN_ENABLED

var min_x: float = 0.0
var min_z: float = 0.0
var step: float = 12.5
var cols: int = 0
var rows: int = 0
var heights: PackedFloat32Array = PackedFloat32Array()


func is_valid() -> bool:
	return cols >= 2 and rows >= 2 and step > 0.0 and heights.size() == cols * rows


## Zemin üçgenleriyle birebir aynı yüzey yüksekliği (yolların gömülmesini / havada kalmasını önler).
func height_at(x: float, z: float) -> float:
	if not is_valid():
		return 0.0
	var fx: float = clampf((x - min_x) / step, 0.0, float(cols - 1))
	var fz: float = clampf((z - min_z) / step, 0.0, float(rows - 1))
	var c0: int = mini(int(fx), cols - 2)
	var r0: int = mini(int(fz), rows - 2)
	var tx: float = fx - float(c0)
	var tz: float = fz - float(r0)

	var idx00: int = r0 * cols + c0
	var h00: float = heights[idx00]
	var h10: float = heights[idx00 + 1]
	var h01: float = heights[idx00 + cols]
	var h11: float = heights[idx00 + cols + 1]

	# Üçgen bölünmesi (i00 -> i11 köşegeni): greybox_builder._build_terrain_ground ile birebir aynı
	if tx >= tz:
		return h00 + (h10 - h00) * tx + (h11 - h10) * tz
	else:
		return h00 + (h11 - h01) * tx + (h01 - h00) * tz


func normal_at(x: float, z: float, eps: float = 1.0) -> Vector3:
	if not is_valid():
		return Vector3.UP
	var hx0: float = height_at(x - eps, z)
	var hx1: float = height_at(x + eps, z)
	var hz0: float = height_at(x, z - eps)
	var hz1: float = height_at(x, z + eps)
	return Vector3(hx0 - hx1, 2.0 * eps, hz0 - hz1).normalized()


func min_height() -> float:
	if heights.is_empty():
		return 0.0
	var m: float = heights[0]
	for h: float in heights:
		if h < m:
			m = h
	return m


func max_height() -> float:
	if heights.is_empty():
		return 0.0
	var m: float = heights[0]
	for h: float in heights:
		if h > m:
			m = h
	return m


static func from_dict(d: Dictionary) -> TerrainHeight:
	var th: TerrainHeight = TerrainHeight.new()
	if d.is_empty():
		return th
	th.min_x = float(d.get("min_x", 0.0))
	th.min_z = float(d.get("min_z", 0.0))
	th.step = float(d.get("step", 12.5))
	th.cols = int(d.get("cols", 0))
	th.rows = int(d.get("rows", 0))
	var raw: Variant = d.get("heights", [])
	if raw is Array:
		var arr: PackedFloat32Array = PackedFloat32Array()
		arr.resize((raw as Array).size())
		for i: int in range((raw as Array).size()):
			arr[i] = float((raw as Array)[i])
		th.heights = arr
	return th


static func load_from_file(path: String) -> TerrainHeight:
	if path.is_empty() or not FileAccess.file_exists(path):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return null
	var th: TerrainHeight = from_dict(parsed as Dictionary)
	return th if th.is_valid() else null


## Aktif araziden yükseklik okur; arazi kapalıysa veya yüklü değilse 0.0 döner.
static func active_height(x: float, z: float) -> float:
	if not enabled or active == null:
		return 0.0
	return active.height_at(x, z)


static func active_normal(x: float, z: float) -> Vector3:
	if not enabled or active == null:
		return Vector3.UP
	return active.normal_at(x, z)
