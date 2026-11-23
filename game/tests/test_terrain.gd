extends RefCounted
## Gerçek Davutpaşa arazi yüksekliği (TerrainHeight) ve kampus_terrain.json veri testleri.

const TERRAIN_PATH: String = "res://data/zones/kampus_terrain.json"


func test_bilinear_interpolation_and_clamping() -> String:
	var th: TerrainHeight = TerrainHeight.from_dict({
		"min_x": 0.0,
		"min_z": 0.0,
		"step": 10.0,
		"cols": 2,
		"rows": 2,
		"heights": [0.0, 10.0, 20.0, 30.0],
	})
	if not th.is_valid():
		return "2x2 arazi geçerli olmalı"
	if not is_equal_approx(th.height_at(0.0, 0.0), 0.0):
		return "köşe (0,0) 0 olmalı"
	if not is_equal_approx(th.height_at(10.0, 0.0), 10.0):
		return "köşe (10,0) 10 olmalı"
	if not is_equal_approx(th.height_at(5.0, 5.0), 15.0):
		return "orta nokta 15 olmalı: %f" % th.height_at(5.0, 5.0)
	if not is_equal_approx(th.height_at(-50.0, -50.0), 0.0):
		return "sınır dışı sol-üst 0'a sabitlenmeli"
	if not is_equal_approx(th.height_at(500.0, 500.0), 30.0):
		return "sınır dışı sağ-alt 30'a sabitlenmeli"
	return ""


func test_normal_on_slope_and_flat() -> String:
	var flat: TerrainHeight = TerrainHeight.from_dict({
		"min_x": 0.0, "min_z": 0.0, "step": 10.0, "cols": 2, "rows": 2,
		"heights": [5.0, 5.0, 5.0, 5.0],
	})
	if not flat.normal_at(5.0, 5.0).is_equal_approx(Vector3.UP):
		return "düz zeminde normal UP olmalı"

	var sloped: TerrainHeight = TerrainHeight.from_dict({
		"min_x": 0.0, "min_z": 0.0, "step": 10.0, "cols": 2, "rows": 2,
		"heights": [0.0, 10.0, 0.0, 10.0],
	})
	var n: Vector3 = sloped.normal_at(5.0, 5.0)
	if n.x >= -0.5 or n.y <= 0.5:
		return "+X yönünde yükselen eğimde normal -X'e eğilmeli: %s" % str(n)
	return ""


func test_active_height_respects_config_flag() -> String:
	var prev_active: TerrainHeight = TerrainHeight.active
	var prev_enabled: bool = Config.TERRAIN_ENABLED
	TerrainHeight.active = TerrainHeight.from_dict({
		"min_x": 0.0, "min_z": 0.0, "step": 10.0, "cols": 2, "rows": 2,
		"heights": [12.0, 12.0, 12.0, 12.0],
	})

	Config.TERRAIN_ENABLED = true
	var h_on: float = TerrainHeight.active_height(5.0, 5.0)
	Config.TERRAIN_ENABLED = false
	var h_off: float = TerrainHeight.active_height(5.0, 5.0)

	TerrainHeight.active = prev_active
	Config.TERRAIN_ENABLED = prev_enabled

	if not is_equal_approx(h_on, 12.0):
		return "TERRAIN_ENABLED=true iken 12.0 dönmeli: %f" % h_on
	if not is_equal_approx(h_off, 0.0):
		return "TERRAIN_ENABLED=false iken 0.0 dönmeli: %f" % h_off
	return ""


func test_kampus_terrain_data_valid_and_realistic() -> String:
	var th: TerrainHeight = TerrainHeight.load_from_file(TERRAIN_PATH)
	if th == null or not th.is_valid():
		return "kampus_terrain.json yüklenemedi veya geçersiz"
	var origin_h: float = th.height_at(0.0, 0.0)
	if absf(origin_h) > 0.2:
		return "Ortabahçe orijin yüksekliği ~0 m olmalı: %f" % origin_h
	var span: float = th.max_height() - th.min_height()
	if span < 5.0 or span > 120.0:
		return "Davutpaşa kot farkı gerçekçi aralıkta (5..120 m) olmalı: %f" % span
	return ""
