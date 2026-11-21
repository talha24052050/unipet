# 008 — Ortabahçe propları: yerleşim + sahneye kurma (ROADMAP 5.3)

## Durum
Modeller HAZIR ve commit'li: `game/assets/props/*.glb` (liste ve üçgen sayıları `art/props.json`). Yeni asset ARAMA/İNDİRME.
Önceki denemede görev çok büyük kaldı; bu sefer sadece yerleşim ve sahneye kurma. Kısa tut, önce çalışan en basit hali yap.

## Dokunabileceğin dosyalar
- `tools/osm/place_props.py` (yeni)
- `game/data/zones/ortabahce_props.json` (yeni, script üretir)
- `game/src/world/prop_placer.gd` (yeni)
- `game/tests/test_props.gd` (yeni)
- `game/scenes/main.tscn` — SADECE `World` (NavigationRegion3D) altına `PropPlacer` düğümü eklemek için
- `agy-tasks/done/008-ortabahce-detay.report.md`

## Yapılacaklar (sırayla; her adımdan sonra test et)
1. `place_props.py` (standart kütüphane, `random.Random(42)`): `game/data/zones/ortabahce_greybox.json`'u oku.
   - Ağaç (`tree_birch`, `tree_pine`, `tree_common` karışık) ve çalı (`bush_common`, `bush_berries`): `areas` çokgenlerinin içine,
     birbirinden ≥ 4 m, yol çizgilerinden ≥ 2.5 m, bina çokgenlerinden ≥ 3 m uzak, orijinden ≥ 6 m uzak. Toplam ağaç ≤ 120, çalı ≤ 80.
   - Bank (`bench`): ismi "Ortabahçe" olan alanın içindeki yollar boyunca her ~18 m'de, yolun 1.8 m yanına, yola dönük (yaw).
     Lamba (`lamp`) her ~25 m, çöp kutusu (`trashcan`) her 3 bankın birinin yanında. Bunlar için de bina/orijin kuralı geçerli.
   - Çıktı: `{"props": [{"type": "...", "pos": [x, z], "yaw": rad, "scale": s}]}` (ağaç ölçeği 0.9-1.2 rastgele, diğerleri 1).
2. `prop_placer.gd` (Node3D, `@export_file var data_path`): JSON'u okur; tür başına glb'yi bir kez yükleyip içindeki
   MeshInstance3D'lerin mesh'lerini (ve yerel dönüşümlerini) alır; her mesh için bir `MultiMeshInstance3D` kurar.
   Çarpışma: tek bir `StaticBody3D`; ağaç ve lamba için ince `CylinderShape3D` (yarıçap 0.3, yükseklik 3), bank ve çöp kutusu için
   `BoxShape3D`; çalılara yok. `_ready` içinde kurulmalı (NavigationRegion bir kare sonra pişirir, engeller navmesh'e girsin).
3. Boyut kontrolü: glb'lerin gerçek boyu farklı olabilir. Bir kez yükleyip AABB'ye bak; ağaç 4-7 m, bank ~1.6 m genişlik,
   lamba 3-4 m olacak şekilde tür başına `const` ölçek çarpanı koy.
4. `main.tscn`: `World` altına `PropPlacer` (`data_path = "res://data/zones/ortabahce_props.json"`), Greybox'tan SONRA.
5. `test_props.gd`: JSON yükleniyor; tüm türlerin glb'si var; hiçbir prop bina çokgeni içinde değil; orijine 6 m'den yakın yok;
   toplam üçgen (art/props.json'daki tris × adet) < 250.000.

## Kabul kriterleri
- [ ] `C:/Tools/Godot/godot --headless --path game --import` hatasız
- [ ] `C:/Tools/Godot/godot --headless --path game -s res://tests/run_tests.gd` exit 0 ve çıktıda `SCRIPT ERROR` yok
- [ ] `C:/Tools/Godot/godot --headless --path game --quit-after 60` çıktısında `ERROR`/`SCRIPT ERROR` yok
- [ ] Ekran görüntüsü `agy-tasks/done/008-ortabahce.png` (görüntü kodu repo DIŞINDA, `%TEMP%`'te). Bu adım zor gelirse ATLA, rapora yaz.

## Kurallar
- CLAUDE.md'ye uy. GDScript tipler açık. Sihirli sayılar `const`. `Services._ready()` çağırma.
- git commit/push YAPMA (runner yapar).
- Raporu iş bitmeden de olsa, sonunda MUTLAKA yaz: `agy-tasks/done/008-ortabahce-detay.report.md` (Türkçe; ne yaptın, ne kaldı).
