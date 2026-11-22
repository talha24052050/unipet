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
const SUN_AZIMUTH_DEG: float = -30.0

const DAY_LIGHT: Color = Color(1.0, 0.97, 0.9)
const GOLDEN_LIGHT: Color = Color(1.0, 0.68, 0.42)
const MOON_LIGHT: Color = Color(0.55, 0.65, 0.95)
const SKY_TOP_DAY: Color = Color(0.38, 0.6, 0.92)
const SKY_HORIZON_DAY: Color = Color(0.75, 0.86, 0.96)
const SKY_TOP_NIGHT: Color = Color(0.03, 0.05, 0.14)
const SKY_HORIZON_NIGHT: Color = Color(0.1, 0.12, 0.25)
const SKY_HORIZON_GOLDEN: Color = Color(0.98, 0.62, 0.42)
## Ortam ışığı: gökyüzü rengi tek başına krem/beyaz binaları mavi-griye boyuyordu (Kışla krem değil mavi görünüyordu).
## Gökyüzünün payını azaltıp nötr-sıcak bir ortam rengiyle karıştırıyoruz.
const AMBIENT_DAY: Color = Color(0.86, 0.85, 0.82)
const AMBIENT_NIGHT: Color = Color(0.32, 0.36, 0.5)
const AMBIENT_SKY_CONTRIBUTION: float = 0.3
const GROUND_FAR_DAY: Color = Color(0.33, 0.42, 0.27)
const GROUND_FAR_NIGHT: Color = Color(0.05, 0.06, 0.08)

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


## Saate göre görünüm: {"elevation_deg", "light_color", "light_energy", "sky_top", "sky_horizon", "ambient"}.
static func sample(hour: float) -> Dictionary:
	var day_len: float = SUNSET_H - SUNRISE_H
	var t: float = (hour - SUNRISE_H) / day_len  # 0 gündoğumu, 1 günbatımı
	var is_day: bool = t >= 0.0 and t <= 1.0
	var elevation: float = sin(clampf(t, 0.0, 1.0) * PI) * SUN_MAX_ELEVATION_DEG if is_day else 25.0  # gece: ay
	# Altın saat: güneş alçakken (gündoğumu/batımı yakını) sıcak renk.
	var golden: float = clampf(1.0 - elevation / 20.0, 0.0, 1.0) if is_day else 0.0
	var day_amount: float = clampf(elevation / 8.0, 0.0, 1.0) if is_day else 0.0
	var light_color: Color = MOON_LIGHT.lerp(DAY_LIGHT.lerp(GOLDEN_LIGHT, golden), day_amount if is_day else 0.0)
	return {
		"elevation_deg": elevation,
		"light_color": light_color,
		"light_energy": lerpf(0.45, 1.0, day_amount),
		"sky_top": SKY_TOP_NIGHT.lerp(SKY_TOP_DAY, day_amount),
		"sky_horizon": SKY_HORIZON_NIGHT.lerp(SKY_HORIZON_DAY.lerp(SKY_HORIZON_GOLDEN, golden), day_amount if is_day else 0.0),
		"ambient": lerpf(0.6, 1.0, day_amount),
		"is_day": is_day,
	}


func apply(hour: float) -> void:
	var s: Dictionary = sample(hour)
	if sun != null:
		sun.rotation_degrees = Vector3(-float(s["elevation_deg"]), SUN_AZIMUTH_DEG, 0.0)
		sun.light_color = s["light_color"]
		sun.light_energy = s["light_energy"]
	if environment != null and environment.environment != null:
		var env: Environment = environment.environment
		env.ambient_light_energy = s["ambient"]
		env.ambient_light_sky_contribution = AMBIENT_SKY_CONTRIBUTION
		env.ambient_light_color = AMBIENT_NIGHT.lerp(AMBIENT_DAY, float(s["ambient"] - 0.6) / 0.4)
		if env.sky != null and env.sky.sky_material is ProceduralSkyMaterial:
			var sky: ProceduralSkyMaterial = env.sky.sky_material
			sky.sky_top_color = s["sky_top"]
			sky.sky_horizon_color = s["sky_horizon"]
			sky.ground_horizon_color = s["sky_horizon"]
			# Zemin bitiminde ufuk altı siyah şerit görünmesin: çim tonuna yakın, gece kararır
			sky.ground_bottom_color = GROUND_FAR_NIGHT.lerp(GROUND_FAR_DAY, float(s["ambient"] - 0.6) / 0.4)
