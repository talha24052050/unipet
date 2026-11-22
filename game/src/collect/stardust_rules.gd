extends RefCounted
## Yıldız tozu + dükkan kuralları. Sunucu (server/nakama/modules/index.js) ile AYNI:
## gün numarası, günün noktaları (mulberry32 karıştırma), toplama yarıçapı, satın alma.
## Sunucusuz modda (OfflineNetworkService) cihazda bu kurallar çalışır.

const POINTS_DATA: String = "res://data/stardust_points.json"
const DAILY: int = 40
## Sunucunun kabul ettiği uzaklık (gecikme payıyla); istemci 1.8 m'de toplar.
const RADIUS: float = 6.0
const MASK: int = 0xFFFFFFFF


static func load_points(path: String = POINTS_DATA) -> Array:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return (d as Dictionary).get("points", []) if d is Dictionary else []


## Türkiye saatiyle (UTC+3) gün numarası.
static func day_number(unix_s: float) -> int:
	return floori((unix_s + 3 * 3600) / 86400.0)


static func _imul(a: int, b: int) -> int:
	return (a * b) & MASK


## Günün nokta indeksleri (sıralı). JS dailyIndices ile birebir aynı sonuç.
static func daily_indices(day: int, n: int, count: int) -> PackedInt32Array:
	var s: int = (day * 2654435761) & MASK
	var idx: Array[int] = []
	for i: int in n:
		idx.append(i)
	count = mini(count, n)
	for k: int in count:
		s = (s + 0x6D2B79F5) & MASK
		var t: int = s
		t = _imul(t ^ (t >> 15), t | 1)
		t = (t ^ ((t + _imul(t ^ (t >> 7), t | 61)) & MASK)) & MASK
		var r: float = float((t ^ (t >> 14)) & MASK) / 4294967296.0
		var j: int = k + floori(r * (n - k))
		var tmp: int = idx[k]
		idx[k] = idx[j]
		idx[j] = tmp
	var out: Array[int] = idx.slice(0, count)
	out.sort()
	return PackedInt32Array(out)


## Cüzdanı bugüne göre düzeltir (gün değiştiyse alınanlar sıfırlanır).
static func normalize(w: Dictionary, day: int) -> Dictionary:
	return {"dust": int(w.get("dust", 0)), "owned": PackedStringArray(w.get("owned", [])), "day": day,
		"taken": PackedInt32Array(w.get("taken", [])) if int(w.get("day", -1)) == day else PackedInt32Array()}


static func view(w: Dictionary, n_points: int, got: bool = false) -> Dictionary:
	var pts: Array[int] = []
	for i: int in daily_indices(int(w["day"]), n_points, DAILY):
		if not (w["taken"] as PackedInt32Array).has(i):
			pts.append(i)
	return {"dust": w["dust"], "owned": w["owned"], "points": pts, "got": got}


static func collect(w: Dictionary, i: int, pos: Vector3, points: Array) -> bool:
	if i < 0 or i >= points.size() or (w["taken"] as PackedInt32Array).has(i):
		return false
	if not daily_indices(int(w["day"]), points.size(), DAILY).has(i):
		return false
	var pt: Array = points[i]
	if Vector2(pos.x - float(pt[0]), pos.z - float(pt[1])).length() > RADIUS:
		return false
	var taken: PackedInt32Array = w["taken"]
	taken.append(i)
	w["taken"] = taken  # Packed diziler değer tipi: geri yaz
	w["dust"] = int(w["dust"]) + 1
	return true


## "" = başarılı; aksi halde neden.
static func buy(w: Dictionary, item: String, price: int) -> String:
	if price <= 0:
		return "böyle bir ürün yok"
	if (w["owned"] as PackedStringArray).has(item):
		return "zaten sende"
	if int(w["dust"]) < price:
		return "yıldız tozu yetmiyor"
	w["dust"] = int(w["dust"]) - price
	var owned: PackedStringArray = w["owned"]
	owned.append(item)
	w["owned"] = owned
	return ""
