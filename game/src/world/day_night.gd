extends Node
## Gece-gündüz: cihazın yerel saatine göre güneş açısı, ışık rengi/şiddeti ve gökyüzü renkleri.
## Hesap saf fonksiyonda (`sample(hour)`), düğüm sadece uygular. Dakikada bir güncellenir.

@export var sun: DirectionalLight3D
@export var environment: WorldEnvironment
## Test/önizleme için saat sabitlenebilir (-1 = gerçek saat).
@export_range(-1.0, 24.0) var fixed_hour: float = -1.0

const UPDATE_INTERVAL_S: float = 60.0
## İstanbul için yıl ortalaması (sadelik: mevsim yok).
const SUNRISE_H: float = 6.5
const SUNSET_H: float = 18.5
const SUN_MAX_ELEVATION_DEG: float = 62.0
## Gerçek İstanbul / Davutpaşa güneş yayı: doğudan (+X, +95°) doğar, öğlen güneye (+Z, 0°) çıkar,
## akşamüstü Yıldız Store'dan Stadyum yönüne (-X/+Z, -68°) batar.
const SUN_AZIMUTH_SUNRISE_DEG: float = 95.0
const SUN_AZIMUTH_SUNSET_DEG: float = -68.0
const MOON_AZIMUTH_DEG: float = -35.0

const DAY_LIGHT: Color = Color(1.0, 0.97, 0.9)
const GOLDEN_LIGHT: Color = Color(1.0, 0.58, 0.30)
const MOON_LIGHT: Color = Color(0.55, 0.65, 0.95)
const SKY_TOP_DAY: Color = Color(0.38, 0.6, 0.92)
const SKY_TOP_GOLDEN: Color = Color(0.20, 0.28, 0.54)
const SKY_HORIZON_DAY: Color = Color(0.75, 0.86, 0.96)
const SKY_TOP_NIGHT: Color = Color(0.03, 0.05, 0.14)
const SKY_HORIZON_NIGHT: Color = Color(0.1, 0.12, 0.25)
const SKY_HORIZON_GOLDEN: Color = Color(1.0, 0.46, 0.20)
## Ortam ışığı: gökyüzü rengi tek başına krem/beyaz binaları mavi-griye boyuyordu (Kışla krem değil mavi görünüyordu).
## Gökyüzünün payını azaltıp nötr-sıcak bir ortam rengiyle karıştırıyoruz.
const AMBIENT_DAY: Color = Color(0.86, 0.85, 0.82)
const AMBIENT_NIGHT: Color = Color(0.32, 0.36, 0.5)
const AMBIENT_SKY_CONTRIBUTION: float = 0.3
const GROUND_FAR_DAY: Color = Color(0.33, 0.42, 0.27)
const GROUND_FAR_NIGHT: Color = Color(0.05, 0.06, 0.08)
## Atmosferik derinlik sisi: uzaktaki binaları ufuk rengine yumuşakça harmanlar (mobil dostu depth fog).
const FOG_DEPTH_BEGIN: float = 95.0
const FOG_DEPTH_END: float = 420.0
const FOG_DENSITY_DAY: float = 0.62
const FOG_DENSITY_NIGHT: float = 0.78

var _timer: float = 0.0


func _ready() -> void:
	apply(current_hour())


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= UPDATE_INTERVAL_S:
		_timer = 0.0
		apply(current_hour())


func current_hour() -> float:
	if fixed_hour >= 0.0:
		return fixed_hour
	var t: Dictionary = Time.get_time_dict_from_system()
	return float(t["hour"]) + float(t["minute"]) / 60.0


## Saate göre görünüm: {"elevation_deg", "azimuth_deg", "light_color", "light_energy", "sky_top", "sky_horizon", "ambient", "golden"}.
static func sample(hour: float) -> Dictionary:
	var day_len: float = SUNSET_H - SUNRISE_H
	var t: float = (hour - SUNRISE_H) / day_len  # 0 gündoğumu, 0.5 öğlen, 1 günbatımı
	var is_day: bool = t >= 0.0 and t <= 1.0
	var tc: float = clampf(t, 0.0, 1.0)
	var elevation: float = sin(tc * PI) * SUN_MAX_ELEVATION_DEG if is_day else 25.0  # gece: ay
	var azimuth: float = lerpf(SUN_AZIMUTH_SUNRISE_DEG, SUN_AZIMUTH_SUNSET_DEG, tc) if is_day else MOON_AZIMUTH_DEG
	# Altın saat: güneş alçakken (gündoğumu/batımı yakını) sıcak turuncu-kızıl ışık ve gökyüzü.
	var golden: float = clampf(1.0 - elevation / 22.0, 0.0, 1.0) if is_day else 0.0
	var day_amount: float = clampf(elevation / 7.0, 0.0, 1.0) if is_day else 0.0
	var light_color: Color = MOON_LIGHT.lerp(DAY_LIGHT.lerp(GOLDEN_LIGHT, golden), day_amount if is_day else 0.0)
	var sky_top_day: Color = SKY_TOP_DAY.lerp(SKY_TOP_GOLDEN, golden * 0.75)
	return {
		"elevation_deg": elevation,
		"azimuth_deg": azimuth,
		"light_color": light_color,
		"light_energy": lerpf(0.45, 1.0, day_amount),
		"sky_top": SKY_TOP_NIGHT.lerp(sky_top_day, day_amount),
		"sky_horizon": SKY_HORIZON_NIGHT.lerp(SKY_HORIZON_DAY.lerp(SKY_HORIZON_GOLDEN, golden), day_amount if is_day else 0.0),
		"ambient": lerpf(0.6, 1.0, day_amount),
		"golden": golden,
		"is_day": is_day,
	}


func apply(hour: float) -> void:
	var s: Dictionary = sample(hour)
	var golden: float = float(s.get("golden", 0.0))
	if sun != null:
		sun.rotation_degrees = Vector3(-float(s["elevation_deg"]), float(s["azimuth_deg"]), 0.0)
		sun.light_color = s["light_color"]
		sun.light_energy = s["light_energy"]
		# Günbatımında güneş diski daha belirgin ve sıcak görünür.
		sun.light_angular_distance = lerpf(1.0, 2.5, golden)
	if environment != null and environment.environment != null:
		var env: Environment = environment.environment
		var day_factor: float = clampf((float(s["ambient"]) - 0.6) / 0.4, 0.0, 1.0)
		env.ambient_light_energy = s["ambient"]
		env.ambient_light_sky_contribution = AMBIENT_SKY_CONTRIBUTION
		env.ambient_light_color = AMBIENT_NIGHT.lerp(AMBIENT_DAY.lerp(GOLDEN_LIGHT, golden * 0.35), day_factor)
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.fog_enabled = true
		env.fog_mode = Environment.FOG_MODE_DEPTH
		env.fog_sky_affect = 0.0
		env.fog_light_color = s["sky_horizon"]
		env.fog_sun_scatter = lerpf(0.08, 0.55, golden)
		env.fog_depth_begin = FOG_DEPTH_BEGIN
		env.fog_depth_end = FOG_DEPTH_END
		env.fog_density = lerpf(FOG_DENSITY_NIGHT, FOG_DENSITY_DAY, day_factor)
		if env.sky != null and env.sky.sky_material is ProceduralSkyMaterial:
			var sky: ProceduralSkyMaterial = env.sky.sky_material
			sky.sky_top_color = s["sky_top"]
			sky.sky_horizon_color = s["sky_horizon"]
			sky.sky_curve = lerpf(0.18, 0.14, golden)
			sky.sun_angle_max = lerpf(15.0, 34.0, golden)
			sky.sun_curve = lerpf(0.08, 0.16, golden)
			sky.ground_horizon_color = s["sky_horizon"]
			sky.ground_curve = 0.06
			# Zemin bitiminde ufuk altı siyah şerit görünmesin: çim tonuna yakın, günbatımında sıcaklaşır
			var ground_day: Color = GROUND_FAR_DAY.lerp(SKY_HORIZON_GOLDEN * 0.55, golden * 0.45)
			sky.ground_bottom_color = GROUND_FAR_NIGHT.lerp(ground_day, day_factor)
