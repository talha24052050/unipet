class_name BuildingStyle
extends RefCounted
## Bina adı, kat sayısı ve taban alanından görsel stil seçimi (saf fonksiyonlar ve renk sabitleri).

const STYLE_HISTORIC: StringName = &"historic"
const STYLE_DORM: StringName = &"dorm"
const STYLE_MODERN: StringName = &"modern"
const STYLE_SMALL: StringName = &"small"

const FLOOR_HEIGHT: float = 3.5
const SMALL_AREA_THRESHOLD: float = 300.0

## Tarihi binaları belirleyen anahtar kelimeler (Türkçe karakter ve büyük/küçük harf duyarsız).
const HISTORIC_KEYWORDS: PackedStringArray = [
	"kisla",
	"tasbina",
	"tas bina",
	"sanat ve tasarim",
	"otag",
	"sancak",
	"hamam",
	"mescit",
	"cami",
]

## Renk paleti (YTÜ Davutpaşa harita stili)
const HISTORIC_WALL: Color = Color(0.937, 0.890, 0.784)  # krem #EFE3C8
const HISTORIC_ROOF: Color = Color(0.725, 0.278, 0.227)  # kiremit #B9473A
const HISTORIC_WINDOW: Color = Color(0.18, 0.22, 0.28)
const HISTORIC_FRAME: Color = Color(1.0, 1.0, 1.0)       # beyaz pencere çerçevesi

const MODERN_WALL: Color = Color(0.91, 0.93, 0.94)       # açık gri / beyaz
const MODERN_ROOF: Color = Color(0.68, 0.71, 0.74)       # açık gri düz çatı
const MODERN_WINDOW: Color = Color(0.18, 0.24, 0.32)     # koyu mavi-gri yatay şerit
const MODERN_FRAME: Color = Color(0.78, 0.82, 0.85)

const DORM_WALL: Color = Color(0.95, 0.93, 0.89)         # beyaz-krem
const DORM_ROOF: Color = Color(0.55, 0.58, 0.60)
const DORM_WINDOW: Color = Color(0.18, 0.22, 0.27)
const DORM_FRAME: Color = Color(0.66, 0.32, 0.26)        # tuğla rengi vurgu

const SMALL_WALL: Color = Color(0.60, 0.62, 0.64)        # sade gri
const SMALL_ROOF: Color = Color(0.50, 0.52, 0.54)
const SMALL_WINDOW: Color = Color(0.28, 0.30, 0.32)
const SMALL_FRAME: Color = Color(0.60, 0.62, 0.64)

## Zemin ve yol renkleri
const GRASS_COLOR: Color = Color(0.490, 0.729, 0.310)     # canlı yeşil #7DBA4F
const SERVICE_ROAD_COLOR: Color = Color(0.290, 0.310, 0.333) # koyu gri #4A4F55
const PEDESTRIAN_PATH_COLOR: Color = Color(0.91, 0.89, 0.85) # krem/açık gri

## Shader stil indeksleri (building_wall.gdshader ile eşleşir)
const SHADER_STYLE_STRIP: int = 0
const SHADER_STYLE_GRID: int = 1
const SHADER_STYLE_HISTORIC: int = 2

const STYLES: Dictionary = {
	STYLE_HISTORIC: {
		"wall_color": HISTORIC_WALL,
		"roof_color": HISTORIC_ROOF,
		"window_color": HISTORIC_WINDOW,
		"frame_color": HISTORIC_FRAME,
		"shader_style": SHADER_STYLE_HISTORIC,
	},
	STYLE_MODERN: {
		"wall_color": MODERN_WALL,
		"roof_color": MODERN_ROOF,
		"window_color": MODERN_WINDOW,
		"frame_color": MODERN_FRAME,
		"shader_style": SHADER_STYLE_STRIP,
	},
	STYLE_DORM: {
		"wall_color": DORM_WALL,
		"roof_color": DORM_ROOF,
		"window_color": DORM_WINDOW,
		"frame_color": DORM_FRAME,
		"shader_style": SHADER_STYLE_GRID,
	},
	STYLE_SMALL: {
		"wall_color": SMALL_WALL,
		"roof_color": SMALL_ROOF,
		"window_color": SMALL_WINDOW,
		"frame_color": SMALL_FRAME,
		"shader_style": SHADER_STYLE_STRIP,
	},
}


## Türkçe karakterleri ve büyük/küçük harfleri sadeleştirir.
static func normalize_name(text: String) -> String:
	var s: String = text.strip_edges()
	s = s.replace("İ", "i").replace("I", "ı")
	s = s.to_lower()
	s = s.replace("ı", "i")
	s = s.replace("ğ", "g")
	s = s.replace("ü", "u")
	s = s.replace("ş", "s")
	s = s.replace("ö", "o")
	s = s.replace("ç", "c")
	return s


## Çokgenin taban alanını (m2) hesaplar (Shoelace formülü).
static func polygon_area(poly: PackedVector2Array) -> float:
	var n: int = poly.size()
	if n < 3:
		return 0.0
	var sum: float = 0.0
	for i: int in n:
		var p1: Vector2 = poly[i]
		var p2: Vector2 = poly[(i + 1) % n]
		sum += (p1.x * p2.y) - (p2.x * p1.y)
	return absf(sum) * 0.5


## Verilen bina adı, yüksekliği ve taban alanına göre görsel stil seçer.
static func style_for(name: String, height: float, footprint_area: float) -> StringName:
	var norm: String = normalize_name(name)

	# 1. Tarihi binalar
	if not norm.is_empty():
		for kw: String in HISTORIC_KEYWORDS:
			if norm.contains(kw):
				return STYLE_HISTORIC

	# Kat sayısı
	var floor_count: int = int(round(height / FLOOR_HEIGHT))

	# 2. Yurt / lojman (çok katlı)
	if not norm.is_empty():
		if norm.contains("lojman"):
			return STYLE_DORM
		var is_dorm_name: bool = norm.contains("yurt") or norm.contains("yurdu") or _is_block_alphanumeric(norm)
		if floor_count >= 4 and is_dorm_name:
			return STYLE_DORM

	# 3. Adsız binalar
	if norm.is_empty():
		if footprint_area <= SMALL_AREA_THRESHOLD:
			return STYLE_SMALL
		if floor_count >= 2:
			return STYLE_MODERN
		return STYLE_SMALL

	# 4. Modern (diğer adlı binalar)
	return STYLE_MODERN


## "C1 Blok", "Blok C1", "J3 Blok", "B2" gibi harf+rakam kalıplarını yakalar.
static func _is_block_alphanumeric(norm: String) -> bool:
	var has_digit: bool = false
	for c: String in ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]:
		if norm.contains(c):
			has_digit = true
			break
	if not has_digit:
		return false

	if norm.contains("blok"):
		return true

	# "c1", "b2" gibi doğrudan kısa kodlar
	var regex: RegEx = RegEx.new()
	if regex.compile(r"\b[a-z]\d+\b") == OK:
		if regex.search(norm) != null:
			return true

	return false


static func get_style_data(style: StringName) -> Dictionary:
	return STYLES.get(style, STYLES[STYLE_MODERN])
