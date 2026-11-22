# 011 — Kampüs Görsel Stili Görev Raporu

## 1. Ne Yapıldı?
YTÜ Davutpaşa Kampüsü'nün resmi harita çizim diline uygun olarak greybox binalar, yollar ve zemin stilize edildi:

1. **Bina Stil Yöneticisi (`game/src/world/building_style.gd`):**
   - `style_for(name: String, height: float, footprint_area: float) -> StringName` saf fonksiyonu eklendi.
   - Türkçe karakter ve büyük/küçük harf duyarsız normalizasyon ile şu 4 stil sınıflandırıldı:
     - `&"historic"`: Kışla, Taşbina, Sanat ve Tasarım, Otağ-ı Hümayun, Sancak Köşkü, Tarihi Hamam, Mescit, Cami isimlerini içeren tarihi yapılar. Krem duvar (`#EFE3C8`), kiremit çatısı (`#B9473A`), beyaz pencere çerçeveleri.
     - `&"dorm"`: Çok katlı yurt ve lojmanlar (isimde Yurt/Yurdu, Lojman veya harf+rakam Blok kodu olup $\ge 4$ kat olanlar). Beyaz-krem duvar, düzenli pencere ızgarası, tuğla rengi çerçeve vurgusu (`#A85242`).
     - `&"modern"`: Diğer adlı fakülte/idari binalar veya $\ge 2$ katlı büyük binalar. Açık gri/beyaz duvar, koyu mavi-gri yatay pencere şeritleri (`#26384A`), düz açık gri çatı.
     - `&"small"`: Adsız ve taban alanı küçük ($\le 300\text{ m}^2$) kulübe/depolar. Sade gri doku.
   - Taban alanı hesabı için Shoelace (`polygon_area`) fonksiyonu eklendi.
   - Harita stiline uygun renk sabitleri ve shader parametre eşlemeleri tanımlandı.

2. **Prosedürel Duvar & Pencere Shader'ı (`game/assets/shaders/building_wall.gdshader`):**
   - Mobil uyumlu Spatial Shader yazıldı (`diffuse_lambert, specular_schlick_ggx`, unshaded değil).
   - Dünya koordinatları (`world_pos`) ve yüzey normali üzerinden UV gerektirmeksizin dinamik pencere çizimi sağlandı.
   - 3.5 metre kat yüksekliği ile kat aralıkları ve duvar teğet vektörü (`wall_dir`) üzerinden metrik yatay konum (`wall_u`) hesaplandı.
   - `style` uniform'una göre 3 farklı pencere tarzı oluşturuldu:
     - `0`: Modern fakülteler için yatay pencere şeritleri ve dikey kayıtlar.
     - `1`: Yurtlar için düzenli pencere ızgarası ve çerçeve vurgusu.
     - `2`: Tarihi binalar için beyaz çerçeveli, kemerli tepe kavisli pencereler.
   - Çatı ve yatay yüzeylerde (`world_normal.y > 0.5`) pencereler kapatılarak düz çatı rengi uygulandı.

3. **Tarihi Binalara Kırma (Hip) Çatı Mesh Üretimi (`GreyboxBuilder.build_hip_roof`):**
   - Tarihi binaların üstüne taban çokgeninin içe ofsetini (`Geometry2D.offset_polygon`, -2.0m derinlik) kullanarak 2.5m yüksekliğinde kırma çatı eğimli yüzeyleri ve düz tepe tavanı ("iç halkayı düz kapat") inşa edildi.
   - En yakın köşe çifti üzerinden köprülü çokgen üçgenlemesi ile halka/avlu şekilli yapılar (Kışla/Taşbina avlusu) dahil tüm tarihi binalarda hatasız çatı geometrisi üretildi.
   - Ofsetin başarısız olması durumunda düz çatıda kalacak şekilde hata koruması sağlandı.
   - Çatı görsel `MeshInstance3D` ("Roof") olarak eklendi; collision ve geçit mantığına dokunulmadı.

4. **Zemin ve Yol Paleti:**
   - Zemin ve çim alanlar canlı yeşil tonuna (`#7DBA4F`),
   - Yaya yolları krem/açık griye (`#E8E4D9`),
   - Araç yolları (`kind == "service"`) koyu griye (`#4A4F55`) çekildi.

5. **Ekran Görüntüleri:**
   - `%TEMP%` üzerinden çalışan bağımsız kamera betiğiyle Kışla'nın yukarıdan-eğik görünümü (`agy-tasks/done/011-kisla.png`) ve FEF bölgesinin görünümü (`agy-tasks/done/011-fef.png`) kaydedildi.

---

## 2. Hangi Dosyalar?
İzin verilen dosyalar dışında hiçbir dosyaya dokunulmamıştır:
- `game/src/world/building_style.gd` (yeni)
- `game/assets/shaders/building_wall.gdshader` (yeni)
- `game/src/world/greybox_builder.gd` (güncellendi — malzeme seçimi, hip roof entegrasyonu, zemin/yol renkleri; çarpışma/geçit mantığına dokunulmadı)
- `game/tests/test_building_style.gd` (yeni test paketi)
- `agy-tasks/done/011-kisla.png` (yeni ekran görüntüsü)
- `agy-tasks/done/011-fef.png` (yeni ekran görüntüsü)
- `agy-tasks/done/011-kampus-stili.report.md` (yeni rapor)

*(Git commit veya push YAPILMAMIŞTIR.)*

---

## 3. Test Sonuçları

1. **Godot Import Testi:**
   ```bash
   C:/Tools/Godot/godot_console.exe --headless --path game --import
   ```
   Çıktı: `[ DONE ]` — 0 hata, 0 uyarı.

2. **Birim Testleri:**
   ```bash
   C:/Tools/Godot/godot_console.exe --headless --path game -s res://tests/run_tests.gd
   ```
   Çıktı:
   - `test_building_style.gd::test_style_for_historic` -> `ok`
   - `test_building_style.gd::test_style_for_dorm` -> `ok`
   - `test_building_style.gd::test_style_for_modern` -> `ok`
   - `test_building_style.gd::test_style_for_small` -> `ok`
   - `test_building_style.gd::test_shader_compiles` -> `ok`
   - `test_building_style.gd::test_hip_roof_mesh` -> `ok`
   - `test_building_style.gd::test_all_zones_build_greybox_no_errors` -> `ok`
   - **Toplam:** **117 geçti, 0 başarısız**, `SCRIPT ERROR` yok.

3. **Çalıştırma Testi:**
   ```bash
   C:/Tools/Godot/godot_console.exe --headless --path game --quit-after 60
   ```
   Çıktı: Exit code 0, çıktıda `ERROR` veya `SCRIPT ERROR` yok.

---

## 4. Belirsiz Kalanlar / Notlar
- Zemin katta giriş kapıları henüz çizilmemiştir; görev tanımında belirtildiği üzere ("Zemin katta kapı aralıklarına gerek yok") pencere şeritleri/ızgaraları zemin kata da uygulanmaktadır. İleride kapı veya bina tabelası detayları için doku veya shader varyasyonları eklenebilir.
- Kırma çatı tarihi binalarda görsel `MeshInstance3D` olarak eklenmiştir. Çarpışma ve navmesh gövdesi, oyuncunun ve petlerin hareket akışını bozmamak adına düz çatı seviyesinde kalmaktadır.
