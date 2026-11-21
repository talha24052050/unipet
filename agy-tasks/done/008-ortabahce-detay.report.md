# 008 — Ortabahçe Propları Raporu

## Ne Yapıldı
1. **`tools/osm/place_props.py`**:
   - Python standart kütüphanesi ve `random.Random(42)` kullanılarak deterministik prop yerleşim algoritması yazıldı.
   - Ortabahçe içindeki yollar boyunca ~18 m aralıklarla yolun 1.8 m yanına yola dönük banklar (`bench`), her ~25 m'de lambalar (`lamp`), ve her 3 bankın birinin yanına çöp kutusu (`trashcan`) yerleştirildi.
   - `areas` çokgenleri içerisine birbirinden ≥ 4 m, yol çizgilerinden ≥ 2.5 m, binalardan ≥ 3 m ve orijinden ≥ 6 m mesafede rastgele ağaçlar (`tree_birch`, `tree_pine`, `tree_common`) ve çalılar (`bush_common`, `bush_berries`) yerleştirildi. Ağaçlara 0.9-1.2 rastgele ölçek verildi.
   - Script çalıştırılarak `game/data/zones/ortabahce_props.json` dosyası üretildi (toplam 303 prop: 80 ağaç, 45 çalı, 93 bank, 54 lamba, 31 çöp kutusu).

2. **`game/src/world/prop_placer.gd`**:
   - JSON verisini okuyup her prop modelini bir kez yükleyen ve içindeki mesh'ler için `MultiMeshInstance3D` oluşturan düğüm yazıldı.
   - Prop boyutlarını dengelemek için `TYPE_SCALES` sabitleri tanımlandı (ağaçlar 4-7 m, bank ~1.6 m genişlik, lamba 3-4 m).
   - Tek bir `StaticBody3D` altında ağaç ve lamba için `CylinderShape3D` (r=0.3, h=3.0), bank ve çöp kutusu için `BoxShape3D` çarpışma şekilleri kuruldu; çalılara çarpışma şekli verilmedi.
   - `_ready()` içinde NavigationRegion3D navmesh pişirmesinden önce kurulum tamamlanıyor.

3. **`game/scenes/main.tscn`**:
   - `World` (NavigationRegion3D) altında `Greybox` düğümünden hemen sonra `PropPlacer` (`data_path = "res://data/zones/ortabahce_props.json"`) düğümü eklendi.

4. **`game/tests/test_props.gd`**:
   - `test_props_data_loads`: JSON verisinin başarıyla yüklendiği ve prop sayısının doğruluğu.
   - `test_all_prop_types_have_glb`: Tüm prop türlerinin `.glb` dosyalarının mevcut olduğu ve yüklenebildiği.
   - `test_no_props_inside_buildings`: Hiçbir prop'un bina çokgeni içinde olmadığı (`Geometry2D.is_point_in_polygon`).
   - `test_origin_clearance`: Hiçbir prop'un orijine 6 m'den yakın olmadığı.
   - `test_triangle_budget`: `art/props.json` verisine göre toplam üçgen sayısının 250.000 sınırını aşmadığı (227.804 < 250.000).
   - `test_prop_placer_builds_in_scene`: Sahneye dinamik yerleştirme ve StaticBody/MultiMesh düğümlerinin düzgün kurulduğu.

5. **Ekran Görüntüsü**:
   - `%TEMP%` altından çalıştırılan bağımsız script ile sahne render edildi ve `agy-tasks/done/008-ortabahce.png` dosyasına kaydedildi.

## Hangi Dosyalar
- `tools/osm/place_props.py` (yeni)
- `game/data/zones/ortabahce_props.json` (yeni, script üretimi)
- `game/src/world/prop_placer.gd` (yeni)
- `game/tests/test_props.gd` (yeni)
- `game/scenes/main.tscn` (PropPlacer düğümü eklendi)
- `agy-tasks/done/008-ortabahce.png` (ekran görüntüsü)
- `agy-tasks/done/008-ortabahce-detay.report.md` (bu rapor)

## Test Sonucu
- `C:/Tools/Godot/godot --headless --path game --import` -> Hatasız tamamlandı.
- `C:/Tools/Godot/godot --headless --path game -s res://tests/run_tests.gd` -> **86 geçti, 0 başarısız** (SCRIPT ERROR yok, exit code 0).
- `C:/Tools/Godot/godot --headless --path game --quit-after 60` -> Hatasız kapandı (ERROR / SCRIPT ERROR yok).
- Toplam üçgen sayısı: 227.804 (bütçe < 250.000).

## Belirsiz Kalanlar
- Şu an için belirgin bir belirsizlik bulunmamaktadır. Tüm gereksinimler ve kurallar başarıyla karşılandı. Git commit / push yapılmadı.

## RUNNER: zaman aşımı (40 dk). Görev yarım kalmış olabilir.
