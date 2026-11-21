# 005 — Davutpaşa Kampüsü OSM Verisi Raporu (ROADMAP 5.1)

## 1. Ne Yapıldı?
1. **`tools/osm/osm_to_greybox.py` Geriye Uyumlu Genişletildi:**
   - `--area-way <osm_way_id>` seçeneği eklendi: Belirtilen OSM way ID'sine (kampüs sınırı için `666081501`) ait poligon ayıklanarak nokta-çokgen içinde kontrolü (`point_in_polygon` ışın dökme / ray casting algoritması) eklendi. Yapıların (bina/alan/yol) ağırlık merkezinin (`centroid`) çokgen sınırları içinde olup olmadığı test edilerek filtreleme yapılması sağlandı. Sınırın kendisi (`args.area_way`) binalara veya alanlara dahil edilmedi.
   - `--origin-park <park_adı>` seçeneği eklendi: Orijin koordinatları (`lat0`, `lon0`) için park seçimi bağımsız hale getirildi (`--origin-park "Ortabahçe"`). Böylece kampüs geneli `davutpasa_campus.json` ile mevcut `ortabahce_greybox.json` birebir aynı koordinat sistemini ($+X$ doğu, $-Z$ kuzey, Ortabahçe ağırlık merkezi $= (0, 0)$) paylaşmaktadır.
   - `--center-park` ve `--radius` kombinasyonu geriye dönük tam uyumlu korundu.
   - Çıkış JSON'undaki `radius` değeri `--area-way` kullanıldığında kampüs çokgeninin orijine en uzak köşesine göre otomatik hesaplanacak şekilde dinamik kılındı (~1098.5 m).

2. **`game/data/zones/davutpasa_campus.json` Üretildi:**
   - Komut: `python -I tools/osm/osm_to_greybox.py art/reference/osm/davutpasa.json --area-way 666081501 --origin-park "Ortabahçe" --out game/data/zones/davutpasa_campus.json`
   - İçerik:
     - **140 bina** (61 adlandırılmış, 79 isimsiz blok/yapı)
     - **141 alan** (çim, park, spor sahaları)
     - **309 yol** (yaya yolu, servis yolları, patikalar)
     - Orijin: `lat: 41.026074`, `lon: 28.8893207` (Ortabahçe)
     - Yarıçap (`radius`): 1098.5 m

3. **`art/reference/osm/README.md` Dokümantasyonu Hazırlandı:**
   - Veri kaynağı ve ODbL lisans bilgisi belirtildi.
   - Overpass API üzerinden verinin nasıl indirileceği ve script komutları eklendi.
   - Koordinat sistemi detaylandırıldı.
   - Adı olan 61 binanın tamamını içeren tablo (Ad, Yaklaşık Merkez $(x, z)$, Taban Alanı $m^2$, Kat $\to$ Yükseklik $m$, Kapsam Notu) oluşturuldu.
   - `DECISIONS.md` harita kapsamındaki yerlerin analizi yapıldı ve OSM'de eksik olanlar raporlandı.

---

## 2. Hangi Dosyalara Dokunuldu?
Sadece görev tanımında izin verilen dosyalara dokunuldu:
- `tools/osm/osm_to_greybox.py` (güncellendi — geriye uyumlu genişletildi)
- `game/data/zones/davutpasa_campus.json` (yeni oluşturuldu)
- `art/reference/osm/README.md` (yeni oluşturuldu)
- `agy-tasks/done/005-kampus-osm.report.md` (bu rapor)

*Dokunulmayanlar:*
- `art/reference/osm/davutpasa.json` (kampüs sınırı way 666081501 ve tüm kampüs verisini zaten eksiksiz içerdiği için yeniden indirme gerekmedi, korundu).
- `game/data/zones/ortabahce_greybox.json` (hiçbir şekilde değiştirilmedi, byte-byte korundu).
- Hiçbir `git commit` veya `git push` yapılmadı.

---

## 3. Test Sonuçları ve Kabul Kriterleri

### [x] 1. Ortabahçe Geriye Dönük Uyumluluk Testi
Komut:
```bash
python -I tools/osm/osm_to_greybox.py art/reference/osm/davutpasa.json --center-park "Ortabahçe" --radius 220 --out game/data/zones/ortabahce_greybox.json
git diff --exit-code game/data/zones/ortabahce_greybox.json
```
**Sonuç:** `git diff` çıktısı tamamen boştur. Dosya byte-byte aynı kalmıştır.

### [x] 2. `davutpasa_campus.json` Varlığı ve İstatistikleri
Komut:
```bash
python -I tools/osm/osm_to_greybox.py art/reference/osm/davutpasa.json --area-way 666081501 --origin-park "Ortabahçe" --out game/data/zones/davutpasa_campus.json
```
**Sonuç:**
- `game/data/zones/davutpasa_campus.json` başarıyla üretildi.
- **Bina Sayısı:** **140 bina** (61 adlandırılmış bina, 79 isimsiz bina)
- **Alan Sayısı:** 141 alan
- **Yol Sayısı:** 309 yol

### [x] 3. Godot Test Runner
Komut:
```bash
C:/Tools/Godot/godot --headless --path game -s res://tests/run_tests.gd
```
**Sonuç:** Çıkış kodu **0** (Tüm mevcut testler başarıyla geçti).

---

## 4. Belirsiz Kalanlar ve `DECISIONS.md` Karşılaştırması

`docs/DECISIONS.md` harita kapsamı:
> *"Sadece bina dışları: tam Ortabahçe, tüm Davutpaşa fakülteleri, Büyükev, Hokka, fakülte kafeleri, yemekhane, büyük saha"*

OSM verileriyle karşılaştırma ve belirsiz kalan noktalar:
1. **Büyük Saha (Stadyum):**
   - OSM'de `way 521339557` olarak standart nizami futbol sahası (~105x68 m) yer almaktadır. `leisure: pitch`, `sport: soccer`, `surface: artificial_turf` etiketlerine sahiptir.
   - Ancak OSM'de bir `name` etiketi bulunmamaktadır (isimsizdir) ve `building` olmadığı için binalar değil alanlar (`areas`) listesinde yer alır. Harita modellemesinde bu alan "Büyük Saha / Stadyum" olarak referans alınabilir.
2. **Eksik Fakülteler:**
   - **Mevcut olanlar:** Elektrik-Elektronik Fakültesi (`Blok A-D` dahil), Fen-Edebiyat Fakültesi (`Dekanlık ve B, D, E Bloklar`), İnşaat/Harita/Çevre Mühendisliği blokları (`D, E, F Bloklar`), Eğitim Fakültesi, Yabancı Diller Yüksekokulu, Tarihi Davutpaşa Kışlası.
   - **OSM'de adı geçmeyenler (Eksik):**
     - *Kimya-Metalurji Fakültesi:* OSM'de isimli bir binası yoktur. Kampüsteki isimsiz bloklardan birine karşılık gelmektedir.
     - *Sanat ve Tasarım Fakültesi:* Tarihi Kışla bünyesinde yer aldığından müstakil bina olarak etiketlenmemiştir.
     - *İktisadi ve İdari Bilimler Fakültesi:* Müstakil bir bina olarak bulunmamaktadır.
     - *Uygulamalı Bilimler Fakültesi:* OSM'de adlandırılmamıştır.
3. **Fakülte Kafeleri:**
   - `KAYINTI KAFE`, `YILDIZ CAFE`, `Eskafe` ve `Academic Lounge` adıyla binalar OSM'de mevcuttur.
   - Belirli fakültelerin iç kafeleri (FEF Kafe, İnşaat Çatı Kafe vb.) müstakil bina poligonu olmadığından OSM'de yer almamaktadır; fakülte binalarının içine dahil olarak düşünülmelidir.
