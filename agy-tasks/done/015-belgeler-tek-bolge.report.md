# 015 — Belgeleri tek bölgeye göre güncelle Raporu

**Tarih:** 2026-11-22 06:45  
**Görev:** `agy-tasks/inbox/015-belgeler-tek-bolge.md`  
**Durum:** Tamamlandı  

---

## 1. Ne Yapıldı?

Talha'nın kararı doğrultusunda (`docs/DECISIONS.md` 2026-11-22 ve commit `fe67dd5`) kampüsteki 7 bölge yapısının kaldırılarak tüm kampüsün tek bölgeye ("kampus") geçirilmesi ve haritadan ışınlanma mekanizması belgeler üzerinde güncellendi:

1. **`docs/ARCHITECTURE.md`:**
   - Dizin ağacındaki `data/` ("kampüs verileri") ve `nav/` ("kampüs navmesh'ini önceden pişiren araç") açıklamaları tek bölge mimarisine göre güncellendi.
   - Eski "Bölgeler" başlığı ve içeriği kaldırıldı, yerine **"Kampüs (tek bölge)"** başlığı eklendi:
     - 140 bina, 141 alan, 309 yol içeren tek `"kampus"` tanımı (`game/data/zones/zones.json` ve `ZoneCatalog`), Ortabahçe doğuş noktası (`[0, 0]`) ve tek yürüme haritası (`game/data/zones/kampus_navmesh.res`, hücre boyutu 0.5 m, 7053 poligon, ~70 KB) açıklandı.
     - `RuntimeNavRegion`'ın sha256 kaynak özeti kontrolü ve ~2-3 saniyelik arka plan pişirme mantığı ile `tools/nav/bake_zone_navmeshes.gd` aracı belgelendi.
     - **Işınlanma akışı** 3-4 satırla açıklandı: Haritada (`CampusMap`) 38 resmî yer adından birine dokunup "Git" seçildiğinde sunucu odasından çıkılması (`Services.net.leave_zone()`), hedef koordinatın `Services.pending_teleport`'a atanması, oyun sahnesinin (`main.tscn`) yeniden yüklenmesi ve `player.gd` içindeki `_try_snap_to_navmesh` ile karakterin yürünebilir en yakın noktaya oturtulup odaya yeniden bağlanması.
   - Testler bölümündeki Nakama testi açıklaması ("kampüs oda eşleşmelerini") ve Değiştirilebilirlik İlkeleri madde 5 ("Kampüs/oda: Tek bölge (`kampus`) üzerinden sunucu `kampus-1`, `kampus-2` kanallarına dağıtır (oda kapasitesi: `Config.ROOM_CAPACITY = 40` oyuncu)") güncellendi.

2. **`docs/DURUM.md`:**
   - "Son güncelleme" tarihi `2026-11-22 06:40 (Antigravity)` olarak güncellendi.
   - Giriş / Oyun adımlarındaki harita butonu açıklaması güncellendi (7 bölge arasında geçiş yerine yer adına dokunup ışınlanma).
   - "Çalışan sistemler" tablosunda bölge bazlı navmesh yerine tek navmesh (0.5 m hücre) + ışınlanma; kampüs satırında 7 bölge yerine tek bölge (140 bina, 141 alan, 309 yol) yazıldı.
   - "Agy'de" görev listesi güncellendi: 012-014 tamamlandı, 015 bu görev tamamlandı, 016 kutuda bekliyor.
   - "Bilinen eksikler" altındaki eski "Bölgeler arası geçiş sadece harita ekranından..." maddesi kaldırıldı (5.4b tamamlandı), yerine sıradaki iş olan tüm kampüs prop yerleşimi (016) eklendi.

3. **`docs/ARKADASLARLA_OYNA.md`:**
   - 5. maddedeki ifade güncellendi: `Hepiniz aynı kampüste, aynı odaya düşersiniz (Ortabahçe'de doğuş, oda 40 kişi; haritadan istenen yere ışınlanılabilir).`

4. **`README.md`:**
   - "Nasıl denenir" 3. adımdaki ifade güncellendi: `sağ üstteki "Harita" butonuyla kampüs haritasını açıp yer adına dokunarak ışınlanabilirsiniz (herkes tek kampüste aynı odada buluşur, oda 40 kişi).`

---

## 2. Hangi Dosyalar Değiştirildi?

Sadece görev tanımında izin verilen dosyalar değiştirildi ve rapor oluşturuldu:
- `docs/ARCHITECTURE.md` (değiştirildi)
- `docs/DURUM.md` (değiştirildi)
- `docs/ARKADASLARLA_OYNA.md` (değiştirildi)
- `README.md` (değiştirildi)
- `agy-tasks/done/015-belgeler-tek-bolge.report.md` (bu rapor)

Hiçbir kod dosyasına dokunulmadı. `git commit` veya `git push` **yapılmadı**.

---

## 3. Test Sonuçları

1. **Nakama Sunucu Modülü Testleri:**
   ```powershell
   node server/nakama/test/module.test.js
   ```
   Çıktı:
   ```
   nakama modül testleri: OK
   ```

2. **Godot Test Runner (127 birim ve entegrasyon testi):**
   ```powershell
   godot_console.exe --headless --path game -s res://tests/run_tests.gd
   ```
   Çıktı:
   ```
   127 geçti, 0 başarısız (çıkış kodu: 0)
   ```

3. **Eski İfadelerin Taranması (`grep` Denetimi):**
   Güncellenen belgelerde ("7 bölge", "bölgeler arası") gibi eski ifadelerin taranması:
   ```powershell
   git grep -i -E "7 bölge|bölgeler arası" README.md docs/ARCHITECTURE.md docs/ARKADASLARLA_OYNA.md docs/DURUM.md
   ```
   Çıktı:
   ```
   (Eşleşme bulunamadı, çıkış kodu: 1)
   ```

   Tüm dokümantasyondaki kalan "bölge" ifadeleri kontrol edildiğinde yalnızca tek bölge mimarisini açıklayan referanslar kaldığı doğrulandı:
   ```powershell
   git grep -n -i "bölge" README.md docs/ARCHITECTURE.md docs/ARKADASLARLA_OYNA.md docs/DURUM.md
   ```
   Çıktı:
   ```
   docs/ARCHITECTURE.md:39:## Kampüs (tek bölge)
   docs/ARCHITECTURE.md:40:Tüm kampüs tek bölge olarak modellenmiştir (`game/data/zones/zones.json` ve `ZoneCatalog` içinde `"kampus"` tanımı: 140 bina, 141 alan, 309 yol; doğuş noktası Ortabahçe)...
   docs/ARCHITECTURE.md:83:5. **Kampüs/oda:** Tek bölge (`kampus`) üzerinden sunucu `kampus-1`, `kampus-2` kanallarına dağıtır (oda kapasitesi: `Config.ROOM_CAPACITY = 40` oyuncu).
   docs/DURUM.md:33:| Kampüs: Tek bölge (tüm kampüs: 140 bina, 141 alan, 309 yol), OSM yerleşimi, 38 resmi yer (`game/data/places.json`), kampüs görsel stili (kiremit çatı, pencere shader'ı, bina renkleri), haritadan ışınlanma | ✅ |
   docs/DURUM.md:45:- 015 belgeleri tek bölgeye göre güncelle — tamamlandı (bu görev)
   ```

---

## 4. Belirsiz Kalanlar

- Herhangi bir belirsizlik bulunmamaktadır. Kod yapısı (`game/data/zones/zones.json`, `game/src/ui/campus_map.gd`, `game/src/player/player.gd`, `server/nakama/modules/index.js`) ile dokümanlar birebir uyumlu hale getirilmiştir.
