# 017 — Haritada Bakım Yerleri (Yemek / Dinlenme / Oyun Bonusu) Görev Raporu

## Ne Yaptın
1. **`game/src/ui/campus_map.gd` içine bakım yerleri ve lejant çizimi eklendi:**
   - `res://data/care_spots.json` dosyasını `_ready` aşamasında okuyan altyapı kuruldu (`CARE_SPOTS_DATA` sabiti ve `_care_spots` / `care_spots` özellikleri).
   - Her bakım yeri için harita ölçeğine göre (`r * _scale` piksel yarıçapında) yarı saydam dairesel etki alanı (`SPOT_AREA_ALPHA = 0.22`) ve belirgin kontur çizgisi (`SPOT_AREA_OUTLINE_ALPHA = 0.5`) çizildi.
   - Her bakım yerinin merkezine özel simgeler (rozetler) çizildi:
     - `eat`: Turuncu daire (`Color(0.92, 0.45, 0.1)`) + çatal ve bıçak çizgileri (sol çatala üst dişler, sağ bıçak düz gövde).
     - `rest`: Mavi daire (`Color(0.2, 0.5, 0.9)`) + "z" harfi.
     - `play`: Yeşil daire (`Color(0.25, 0.68, 0.28)`) + küçük top (beyaz daire).
   - Kulüpler Vadisi gibi aynı koordinatı paylaşan yerler (`rest` ve `play` aynı noktada) için simgeler yan yana kaydırılarak ikisinin de net bir şekilde görünmesi sağlandı.
   - Simgeler ve etki alanları yer adlarının (`_draw_places`) **altında** çizildi, böylece bina/yer isimlerinin okunurluğu korunmuştur.
   - Haritanın alt kısmına (onay paneli kapalıyken) yatay olarak ortalanmış tek satır açıklama lejantı çizildi: `"● Yemek   ● Dinlenme 2×   ● Oyun 2×"`. Renkli noktalar `draw_circle` ve beyaz kontur ile belirginleştirildi, metinler `draw_string` ve `draw_string_outline` ile çizildi.
   - Dokunma davranışı kesinlikle değiştirilmedi; sadece yer adlarına dokunulduğunda ışınlanma paneli açılmaya devam etmektedir.
2. **`game/tests/test_campus_map.gd` testleri eklendi:**
   - `test_care_spots_loaded_and_drawn()` fonksiyonu eklendi:
     - `res://data/care_spots.json` dosyasındaki toplam yer sayısı (9 adet: 3 eat, 2 rest, 4 play) ile haritaya yüklenen yer sayısının birebir eşit olduğu doğrulandı.
     - Bir `play` yerinin harita koordinatının ekran sınırları (`Rect2(Vector2.ZERO, m.size)`) içinde kaldığı doğrulandı.
     - `_make()` fonksiyonu ile oluşturulan sahnede 2 kare çizim gerçekleştirildi (1. kare varsayılan görünüm/lejant açık, 2. kare yer seçilip onay paneli açıkken); hata sayacı 0 ve SCRIPT ERROR olmadan çalıştığı doğrulandı.
3. **Ekran görüntüsü üretildi:**
   - Kod repo dışında bir scratch script üzerinden mobil dikey ekran boyutunda (720×1280) harita sahnesi çalıştırılarak `agy-tasks/done/017-harita.png` dosyası oluşturuldu ve görsel kalite doğrulandı.

## Hangi Dosyalar
- `game/src/ui/campus_map.gd` (değiştirildi)
- `game/tests/test_campus_map.gd` (değiştirildi)
- `agy-tasks/done/017-harita.png` (üretilen ekran görüntüsü)
- `agy-tasks/done/017-haritada-bakim-yerleri.report.md` (bu rapor)

## Test Sonucu
- `C:/Tools/Godot/godot --headless --path game -s res://tests/run_tests.gd`:
  - **131 geçti, 0 başarısız** (exit code 0, SCRIPT ERROR yok).
  - `test_campus_map.gd::test_care_spots_loaded_and_drawn` testi başarıyla geçti.

## Belirsiz Kalanlar
- Yok. Tüm gereksinimler ve kabul kriterleri eksiksiz karşılandı.
