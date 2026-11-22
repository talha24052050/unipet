# 013 — Gece Lambaları Görev Raporu

## 1. Ne Yapıldı?
Ortabahçe ve kampüs bölgelerinde gece sokak lambalarının yanması ve mobil bütçeyi koruyarak dinamik aydınlatma sağlanması amacıyla `StreetLights` sistemi geliştirildi:

1. **Sokak Lambaları Yöneticisi (`game/src/world/street_lights.gd`):**
   - İlgili bölgenin prop JSON dosyasındaki (`ortabahce_props.json`) `lamp` türündeki propların konumlarını okur (Ortabahçe'de 54 adet).
   - Her lambanın tepesine (`LAMP_HEIGHT = 3.5` m) sarı (`Color(1.0, 0.94, 0.65)`), unshaded `StandardMaterial3D` malzemeli kürelerden oluşan tek bir `MultiMeshInstance3D` ("ampul") kurar. Gündüzleri gizlenir, geceleri görünür hale gelerek ucuz bir ampul ışıltısı sağlar.
   - Mobil bütçeyi zorlamamak için havuzda en fazla 4 adet `OmniLight3D` tutulur (`MAX_ACTIVE_LIGHTS = 4`, `LIGHT_RANGE = 8.0` m, `shadow_enabled = false`).
   - Her 0.5 saniyede bir oyuncuya en yakın en çok 4 lamba seçilir ve `OmniLight3D` düğümleri bu konumlara taşınarak aktif edilir. Gündüzleri tüm ışıklar kapatılır (aktif ışık sayısı 0).
   - `DayNight` düğümü (`../../DayNight` ya da `@export var day_night: Node`) üzerinden `current_hour()` değeri okunur ve `DayNight.sample(hour)["is_day"]` ile dakikada bir gece/gündüz durumu senkronize edilir.
   - Props içermeyen bölgelerde (`fef` vb.) veya veri bulunmadığında sessizce ve hatasız şekilde 0 lamba ile sonlanır.

2. **Ana Sahne Entegrasyonu (`game/scenes/main.tscn`):**
   - Sadece `World` (NavigationRegion3D) altına `PropPlacer`'ın hemen ardına `StreetLights` düğümü eklendi:
     - `data_path = "res://data/zones/ortabahce_props.json"`
     - `day_night = NodePath("../../DayNight")`
     - `player = NodePath("../../Player")`

3. **Birim Testleri (`game/tests/test_street_lights.gd`):**
   - `test_bulb_count_matches_lamp_count`: JSON'daki lamba sayısı (54) ile üretilen ampul sayısının eşitliğini doğrular.
   - `test_night_mode_active_lights`: Gece modunda aktif OmniLight sayısının $\le 4$ ve $> 0$ olduğunu, menzilin 8 m ve gölgenin kapalı olduğunu, oyuncu hareket ettikçe ışıkların en yakın lambalara taşındığını test eder.
   - `test_day_mode_zero_active_lights`: Gündüz modunda aktif OmniLight sayısının 0 olduğunu ve ampul mesh'inin gizlendiğini doğrular.
   - `test_zone_without_props_no_error`: Prop'suz bölgede (`fef` ve boş veri) hatasız çalıştığını ve 0 lamba döndürdüğünü doğrular.
   - `test_day_night_node_integration`: DayNight saat değişimlerinde (12:00 gündüz, 02:00 gece) doğru aydınlatma modunun uygulandığını test eder.
   - `test_main_scene_integration`: `main.tscn` içerisinde `World/StreetLights` düğümünün script ve day_night referanslarıyla eksiksiz yer aldığını doğrular.

4. **Ekran Görüntüsü:**
   - Kod repo dışında (`$env:TEMP`) bağımsız render betiğiyle sahne gece saatinde (02:00) çalıştırılarak `agy-tasks/done/013-gece.png` dosyasına ekran görüntüsü kaydedildi.

---

## 2. Hangi Dosyalar?
Sadece izin verilen dosyalar üzerinde çalışılmıştır:
- `game/src/world/street_lights.gd` (yeni)
- `game/tests/test_street_lights.gd` (yeni)
- `game/scenes/main.tscn` (sadece World altına StreetLights düğümü ve script kaynağı eklendi)
- `agy-tasks/done/013-gece.png` (gece ekran görüntüsü)
- `agy-tasks/done/013-gece-lambalari.report.md` (bu rapor)

*(Git commit veya push YAPILMAMIŞTIR.)*

---

## 3. Test Sonuçları
- `C:/Tools/Godot/godot_console.exe --headless --path game -s res://tests/run_tests.gd`:
  - **123 geçti, 0 başarısız** (SCRIPT ERROR yok, exit code 0).
- `C:/Tools/Godot/godot_console.exe --headless --path game --quit-after 60`:
  - ERROR / SCRIPT ERROR yok, exit code 0 ile kapandı.
- `agy-tasks/done/013-gece.png`:
  - 100 KB boyutunda gece aydınlatması ekran görüntüsü üretildi.

---

## 4. Belirsiz Kalanlar
- Belirsiz kalan herhangi bir konu bulunmamaktadır. Görevdeki tüm isterler ve kurallar eksiksiz tamamlanmıştır.
