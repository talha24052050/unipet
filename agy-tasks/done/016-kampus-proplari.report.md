# 016 — Ağaç/bank/lamba kampüsün tamamına (mobil bütçeyle) Görev Raporu

## Ne Yaptın
1. **`tools/osm/place_props.py` genişletildi:**
   - `--greybox`, `--out` ve `--seed` argümanları eklendi.
   - Varsayılan çalışma modu mevcut Ortabahçe davranışını koruyacak şekilde yapılandırıldı; `ortabahce_props.json` dosyasının yeniden üretiminde dosyanın birebir aynı kaldığı doğrulandı.
   - Kampüs için `--greybox game/data/zones/kampus_greybox.json --out game/data/zones/kampus_props.json` desteği eklendi.
   - Kampüste tüm yaya yolları (`kind != "service"`) taranarak banklar (~38 m aralıkla, en fazla 250), lambalar (~45 m aralıkla, en fazla 200) ve her 3 banktan birinin yanına çöp kutuları yerleştirildi.
   - Alanlar (141 adet çokgen) taranarak ağaç (600 adet, sınır <= 700) ve çalılar (250 adet, sınır <= 300) yerleştirildi.
   - Binalardan >= 3 m, yollardan >= 2.5 m (ağaç/çalı için), orijinden >= 6 m ve proplardan >= 4 m mesafeler kontrol edildi (seed 42).
   - Bounding box ve spatial hash (mekânsal ızgara) optimizasyonları ile kampüs prop yerleşimi saniyeler içinde tamamlanır hale getirildi.
2. **`game/data/zones/kampus_props.json` üretildi:**
   - Toplam 1.364 prop: 600 ağaç, 250 çalı, 246 bank, 186 lamba, 82 çöp kutusu.
3. **`game/src/world/prop_placer.gd` hücreleme ve LOD görünürlük menzili:**
   - Proplar 100 m × 100 m hücrelere (`CELL_SIZE = 100.0`) ve türlerine göre gruplandı.
   - Her (hücre, tür) kombinasyonu için ayrı bir `MultiMeshInstance3D` oluşturuldu.
   - Görünürlük menzilleri tanımlandı:
     - Ağaçlar: `visibility_range_end = 220.0`
     - Bank, lamba, çöp kutusu, çalı: `visibility_range_end = 120.0`
     - `visibility_range_end_margin = 20.0`
     - `visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF`
   - Çarpışma şekilleri `PropsStaticBody` altında tek parça halinde oluşturulmaya devam etti (görünürlükten bağımsız).
   - `PropPlacer.get_cell(pos: Vector2) -> Vector2i` fonksiyonu eklendi.
4. **`game/data/zones/zones.json` güncellendi:**
   - Sadece `kampus` bölgesinin `"props"` alanı `"res://data/zones/kampus_props.json"` yapıldı.
5. **Navmesh yeniden pişirildi:**
   - `tools/nav/bake_zone_navmeshes.gd` çalıştırılarak yeni prop düzenine göre `game/data/zones/kampus_navmesh.res` dosyası başarıyla güncellendi (12.874 poligon).
6. **`game/tests/test_props.gd` güncellendi ve genişletildi:**
   - Hem `ortabahce_props.json` hem de `kampus_props.json` yüklenme doğrulaması,
   - Tüm prop türlerinin geçerli GLB modellerinin varlığı,
   - Bounding box destekli geometri kontrolü ile hiçbir propun binalar içinde yer almadığının doğrulanması,
   - Orijin güvenli mesafe kontrolü (>= 6 m),
   - 100 m × 100 m hücreleme fonksiyonunun (`get_cell`) pozitif/negatif koordinatlarda doğrulanması,
   - Kampüs üçgen bütçesi doğrulaması (< 1.600.000, gerçekleşen: 1.334.789),
   - Tek oyuncu noktasından 220 m içindeki üçgen sayısı doğrulaması (< 300.000, Ortabahçe merkezi (0,0): 183.245; rastgele noktalar: 127.550, 243.949, 101.159),
   - `PropPlacer`'ın sahnede hücreli `MultiMeshInstance3D` ve visibility range değerlerini doğru kurduğunun doğrulanması.

## Hangi Dosyalar
- `tools/osm/place_props.py` (değiştirildi)
- `game/data/zones/kampus_props.json` (yeni dosya)
- `game/src/world/prop_placer.gd` (değiştirildi)
- `game/data/zones/zones.json` (değiştirildi - yalnızca kampus props referansı)
- `game/data/zones/kampus_navmesh.res` (yeniden pişirildi / güncellendi)
- `game/tests/test_props.gd` (değiştirildi)
- `agy-tasks/done/016-kampus-proplari.report.md` (yeni dosya)

## Test Sonucu
- `C:/Tools/Godot/godot_console.exe --headless --path game -s res://tests/run_tests.gd`:
  - **129 geçti, 0 başarısız** (exit code 0, SCRIPT ERROR yok).
  - `test_prebaked_navmeshes_up_to_date` testi başarıyla geçti.
- `C:/Tools/Godot/godot.exe --headless --path game --quit-after 60`:
  - **0 hata / SCRIPT ERROR** (exit code 0).

## Belirsiz Kalanlar
- Yok. Tüm gereksinimler ve kabul kriterleri eksiksiz karşılandı.
