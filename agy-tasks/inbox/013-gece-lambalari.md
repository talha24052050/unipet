# 013 — Gece lambaları (Ortabahçe sokak lambaları geceleri yansın)

## Amaç
Gece-gündüz döngüsü var (`game/src/world/day_night.gd`, `sample(hour)["is_day"]`). Geceleri Ortabahçe'deki sokak lambaları
(`game/src/world/prop_placer.gd`, tür `lamp`) yansın. Mobil bütçe: dinamik ışık sayısı ÇOK sınırlı.

## Dokunabileceğin dosyalar
- `game/src/world/street_lights.gd` (yeni)
- `game/tests/test_street_lights.gd` (yeni)
- `game/scenes/main.tscn` — SADECE `World` altına StreetLights düğümü eklemek için
- `agy-tasks/done/013-gece-lambalari.report.md`
Başka dosyaya dokunma (`day_night.gd`, `prop_placer.gd` DEĞİŞMEZ; ihtiyacın olanı okuyarak al: prop JSON'u ve `Services.current_zone`).

## Yapılacaklar
1. `street_lights.gd` (Node3D): bölgenin prop JSON'undaki `lamp` konumlarını oku (yoksa hiçbir şey yapma).
   Her lambanın tepesine (yükseklik prop_placer'daki lamba ölçeğine göre ~3.5 m; sabit `const`) küçük, sarı, emisyonlu bir küre/kart
   (unshaded `StandardMaterial3D`, ucuz) koy — bunlar gece "yanan ampul" görüntüsü verir.
2. Gerçek `OmniLight3D` sadece oyuncuya en yakın **en çok 4** lambada olsun (her 0.5 sn'de en yakınları seç, ışıkları taşı); menzil ~8 m,
   gölge KAPALI. Gündüz hepsi kapalı/gizli.
3. Gece/gündüz bilgisi: `DayNight` düğümünü bul (`../../DayNight` ya da `get_tree().get_first_node_in_group(...)` — grup eklemek için
   day_night.gd'ye dokunamazsın; sahnedeki yolu `@export var day_night: Node` ile ver) ve `sample(current_hour())["is_day"]`'ı dakikada bir kontrol et.
4. Test: prop JSON'unda lamba varsa ampul sayısı = lamba sayısı; gece modunda aktif OmniLight ≤ 4; gündüz 0; prop'suz bölgede (`fef`) hata yok.

## Kabul kriterleri
- [ ] `C:/Tools/Godot/godot --headless --path game -s res://tests/run_tests.gd` exit 0, çıktıda `SCRIPT ERROR` yok
- [ ] `C:/Tools/Godot/godot --headless --path game --quit-after 60` çıktısında `ERROR`/`SCRIPT ERROR` yok
- [ ] Ekran görüntüsü (gece, kod repo DIŞINDA): `agy-tasks/done/013-gece.png`. Zor gelirse atla.

## Kurallar
- CLAUDE.md'ye uy. GDScript tipler açık, sihirli sayılar `const`. `Services._ready()` çağırma.
- git commit/push YAPMA. Raporu iş bitmese de MUTLAKA yaz: `agy-tasks/done/013-gece-lambalari.report.md`.
