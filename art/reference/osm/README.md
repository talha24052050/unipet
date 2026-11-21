# Yıldız Teknik Üniversitesi Davutpaşa Kampüsü — OSM Veri Referansı

Bu doküman, UniPet projesinde kullanılan YTÜ Davutpaşa Kampüsü OpenStreetMap (OSM) verilerini, veri kaynağını, üretim komutlarını ve `DECISIONS.md` harita kapsamı doğrultusundaki bina analizini açıklar.

---

## 1. Veri Kaynağı ve Lisans
- **Kaynak:** [OpenStreetMap (OSM)](https://www.openstreetmap.org/)
- **Sınır:** YTÜ Davutpaşa Yerleşkesi OSM Way `666081501`
- **Lisans:** [Open Database License (ODbL)](https://opendatacommons.org/licenses/odbl/) (OpenStreetMap contributors)
- **Ham Veri Dosyası:** `art/reference/osm/davutpasa.json` (Overpass API v0.7.62)

---

## 2. Nasıl Yeniden Üretilir?

### A. Ham OSM Verisini Çekme (Overpass API)
Kampüs sınır çokgeni (Way 666081501) içerisindeki tüm bina, yol ve yeşil alan verilerini Overpass API üzerinden indirmek için:
```bash
curl -d "[out:json][timeout:60];way(666081501);map_to_area->.campus;(way(area.campus););out geom;" https://overpass-api.de/api/interpreter -o art/reference/osm/davutpasa.json
```

### B. Greybox Verisi Üretme (`tools/osm/osm_to_greybox.py`)
Script sadece Python standart kütüphanesini kullanır ve iki modda çalışır:

1. **Ortabahçe Bölgesi (Prototip)**
   - Ortabahçe merkez alınarak 220 metre yarıçapındaki binaları/yolları/alanları filtreler.
   ```bash
   python -I tools/osm/osm_to_greybox.py art/reference/osm/davutpasa.json --center-park "Ortabahçe" --radius 220 --out game/data/zones/ortabahce_greybox.json
   ```

2. **Tüm Davutpaşa Kampüsü (`davutpasa_campus.json`)**
   - Kampüs sınır çokgeni (`--area-way 666081501`) içinde kalan tüm yapıları filtreler.
   - Orijin olarak Ortabahçe parkının merkezi (`--origin-park "Ortabahçe"`) kullanılır; böylece Ortabahçe ve tüm kampüs aynı koordinat sistemini paylaşır.
   ```bash
   python -I tools/osm/osm_to_greybox.py art/reference/osm/davutpasa.json --area-way 666081501 --origin-park "Ortabahçe" --out game/data/zones/davutpasa_campus.json
   ```

---

## 3. Koordinat Sistemi
- **Godot Koordinat Ekseni:** $+X$ Doğu, $-Z$ Kuzey, $+Y$ Yukarı.
- **Orijin (0, 0):** Ortabahçe ağırlık merkezi (`lat: 41.026074`, `lon: 28.8893207`).
- **Kampüs Kapsamı:** Ortabahçe orijinine göre yaklaşık $-459$ m ile $+860$ m doğu/batı, $-712$ m ile $+839$ m kuzey/güney (maksimum yarıçap ~1098.5 m).

---

## 4. `DECISIONS.md` Kapsamındaki Yerlerin Durumu

`docs/DECISIONS.md` içerisinde kararlaştırılan harita kapsamı:
> *"Sadece bina dışları: tam Ortabahçe, tüm Davutpaşa fakülteleri, Büyükev, Hokka, fakülte kafeleri, yemekhane, büyük saha"*

### Durum Analizi
| Hedef Yer | OSM Durumu | OSM Varlık / Açıklama |
|---|---|---|
| **Ortabahçe** | ✅ Mevcut | `way 625567217` (`name="Ortabahçe"`, `leisure=park`) |
| **Büyükev** | ✅ Mevcut | `way 525243971` (`name="BÜYÜK EV"`, 918.7 m²) |
| **Hokka** | ✅ Mevcut | `way 524755836` (`name="Hokka"`, 241.3 m²) |
| **Yemekhane** | ✅ Mevcut | `way 524504140` (`name="Yemekhane"`, 2367.8 m²) |
| **Elektrik-Elektronik Fakültesi** | ✅ Mevcut | `way 521663491` (`name="Elektrik Elektronik Fakültesi"`) + Blok A, B, C, D |
| **Fen-Edebiyat Fakültesi** | ✅ Mevcut | `way 521908127` (`name="A Blok - Fen Edebiyat Fakültesi Dekanlığı"`) + B, D, E Bloklar |
| **İnşaat / Harita / Çevre Bölümleri** | ✅ Mevcut | `way 662486378` (İnşaat), `662488989` (Harita), `662484539` (Çevre) + A, B, C Bloklar |
| **Eğitim Fakültesi** | ✅ Mevcut | `way 900518084` (`name="Eğitim Fakültesi"`, 4423.9 m²) |
| **Yabancı Diller Yüksekokulu** | ✅ Mevcut | `way 664705166` (`name="Yabancı Diller Yüksekokulu"`, 1816.6 m²) |
| **Davutpaşa Kışlası** | ✅ Mevcut | `way 624676665` (14587.1 m² avlulu tarihi yapı; fakülte/bölümleri barındırır) |
| **Fakülte Kafeleri** | ⚠️ Kısmen Mevcut | `KAYINTI KAFE`, `YILDIZ CAFE`, `Eskafe`, `Academic Lounge` mevcut; diğerleri bina içi |
| **Büyük Saha (Stadyum)** | ⚠️ Kısmen / İsimsiz | `way 521339557` (105x68 m futbol sahası alanı mevcut, ancak `name` etiketi yok) |

### OSM'de Bulunamayan ("Eksik") Yerler
Aşağıdaki yerler OSM veritabanında ayrı bir bina adı olarak etiketlenmemiştir:
1. **Kimya-Metalurji Fakültesi:** OSM'de adı geçen bir bina yok. Yerleşkede isimsiz bloklardan birinde veya FEF civarındadır.
2. **Sanat ve Tasarım Fakültesi:** OSM'de bağımsız bina olarak yer almaz; tarihi Davutpaşa Kışlası içerisindedir.
3. **İktisadi ve İdari Bilimler Fakültesi (İİBF):** OSM'de bağımsız bina kaydı yoktur.
4. **Uygulamalı Bilimler Fakültesi:** OSM'de bağımsız bina kaydı yoktur.
5. **Büyük Saha İsim Etiketi:** Sahaya ait `way 521339557` geometrisi (`leisure=pitch`, `sport=soccer`) mevcuttur ancak `name` etiketi boştur. Ayrıca bina değil alan (`areas`) katmanındadır.
6. **Fakülte İçi Özel Kafeler:** FEF kafe, İnşaat çatı kafe gibi fakülteye özel kafeler müstakil bina olmadıklarından OSM'de ayrı birer bina poligonu olarak bulunmaz.

---

## 5. Adı Olan Tüm Binalar Tablosu (Toplam 61 Yapı)

| Bina Adı | Yaklaşık Merkez (x, z metre) | Taban Alanı (m²) | Kat → Yükseklik | Kapsam Notu |
|---|---|---|---|---|
| 18001 TM | (-7.7, -512.9) | 68.3 | 3 kat (10.5 m) | Diğer Kampüs Yapısı |
| A Blok | (-36.4, 290.2) | 811.8 | 3 kat (10.5 m) | ⭐ DECISIONS.md: Fakülte / Derslik Bloğu |
| A Blok - Fen Edebiyat Fakültesi Dekanlığı | (164.2, -184.8) | 1109.4 | 3 kat (10.5 m) | ⭐ DECISIONS.md: Fakülte |
| A1 | (-40.0, 662.1) | 2563.8 | 3 kat (10.5 m) | Teknopark / Kampüs Bloğu |
| A2 | (-68.7, 764.5) | 2564.2 | 3 kat (10.5 m) | Teknopark / Kampüs Bloğu |
| Academic Lounge | (-37.4, 350.7) | 330.3 | 1 kat (3.5 m) | ⭐ DECISIONS.md: Fakülte Kafe (Academic Lounge) |
| B Blok | (-76.2, 260.1) | 850.7 | 3 kat (10.5 m) | ⭐ DECISIONS.md: Fakülte / Derslik Bloğu |
| B Blok | (275.1, -249.0) | 2744.2 | 3 kat (10.5 m) | ⭐ DECISIONS.md: Fakülte / Derslik Bloğu |
| B1 | (20.0, 659.6) | 2571.8 | 3 kat (10.5 m) | Teknopark / Kampüs Bloğu |
| B2 | (-14.8, 767.3) | 2570.9 | 4 kat (14.0 m) | Teknopark / Kampüs Bloğu |
| Blok A | (25.7, -325.7) | 1829.9 | 3 kat (10.5 m) | ⭐ DECISIONS.md: Fakülte / Derslik Bloğu |
| Blok B | (69.1, -316.2) | 2010.7 | 3 kat (10.5 m) | ⭐ DECISIONS.md: Fakülte / Derslik Bloğu |
| Blok C | (93.3, -270.0) | 2373.5 | 3 kat (10.5 m) | ⭐ DECISIONS.md: Fakülte / Derslik Bloğu |
| Blok D | (126.3, -244.8) | 1798.2 | 3 kat (10.5 m) | ⭐ DECISIONS.md: Fakülte / Derslik Bloğu |
| BÜYÜK EV | (-15.5, -74.5) | 918.7 | 1 kat (3.5 m) | ⭐ DECISIONS.md: Büyükev |
| C Blok | (-117.0, 226.0) | 809.8 | 3 kat (10.5 m) | ⭐ DECISIONS.md: Fakülte / Derslik Bloğu |
| C1 | (84.8, 661.6) | 2570.7 | 3 kat (10.5 m) | Teknopark / Kampüs Bloğu |
| C1 Blok | (-224.1, -480.2) | 672.1 | 5 kat (17.5 m) | ⭐ DECISIONS.md: Fakülte / Derslik Bloğu |
| C2 | (47.9, 761.6) | 2571.2 | 3 kat (10.5 m) | Teknopark / Kampüs Bloğu |
| C2 Blok | (-144.0, -447.0) | 671.8 | 5 kat (17.5 m) | ⭐ DECISIONS.md: Fakülte / Derslik Bloğu |
| D Blok | (220.9, -197.1) | 2237.7 | 3 kat (10.5 m) | ⭐ DECISIONS.md: Fakülte / Derslik Bloğu |
| D Blok - Harita Mühendisliği | (-66.7, 331.0) | 1849.1 | 3 kat (10.5 m) | ⭐ DECISIONS.md: Fakülte |
| D1 | (147.0, 658.7) | 2576.8 | 3 kat (10.5 m) | Teknopark / Kampüs Bloğu |
| D2 | (111.5, 763.7) | 2577.2 | 3 kat (10.5 m) | Teknopark / Kampüs Bloğu |
| Davutpaşa Kışlası Mesciti | (-64.5, -14.2) | 209.7 | 2 kat (7.0 m) | ⭐ DECISIONS.md: Kışla (Fakülte / Bölüm içerir) |
| E Blok | (208.5, -245.3) | 2261.9 | 3 kat (10.5 m) | ⭐ DECISIONS.md: Fakülte / Derslik Bloğu |
| E Blok - İnşaat Mühendisliği | (-109.5, 300.8) | 1757.0 | 3 kat (10.5 m) | ⭐ DECISIONS.md: Fakülte |
| Elektrik Elektronik Fakültesi | (47.1, -254.7) | 1947.0 | 3 kat (10.5 m) | ⭐ DECISIONS.md: Fakülte |
| Eskafe | (133.6, 339.7) | 539.0 | 1 kat (3.5 m) | ⭐ DECISIONS.md: Fakülte Kafe (Eskafe) |
| Eğitim Fakültesi | (-280.0, -304.8) | 4423.9 | 4 kat (14.0 m) | ⭐ DECISIONS.md: Fakülte |
| F Blok | (-158.0, -521.1) | 1033.6 | 5 kat (17.5 m) | ⭐ DECISIONS.md: Fakülte / Derslik Bloğu |
| F Blok - Çevre Mühendisliği | (-149.3, 268.9) | 1916.2 | 3 kat (10.5 m) | ⭐ DECISIONS.md: Fakülte |
| Gülbahar Hatun Yurdu Sosyal Tesisi | (-354.9, -474.6) | 1951.9 | 10 kat (35.0 m) | Yurt / Sosyal Tesis |
| Hidrolik Laboratuarı | (-168.4, 429.9) | 4338.3 | 2 kat (7.0 m) | Diğer Kampüs Yapısı |
| Hokka | (-75.2, -106.6) | 241.3 | 1 kat (3.5 m) | ⭐ DECISIONS.md: Hokka |
| J1 Blok | (-279.5, -446.6) | 704.8 | 5 kat (17.5 m) | ⭐ DECISIONS.md: Fakülte / Derslik Bloğu |
| J2 Blok | (-240.3, -417.4) | 704.9 | 5 kat (17.5 m) | ⭐ DECISIONS.md: Fakülte / Derslik Bloğu |
| J3 Blok | (-203.2, -391.5) | 705.2 | 5 kat (17.5 m) | ⭐ DECISIONS.md: Fakülte / Derslik Bloğu |
| K1 Blok | (-112.7, -492.6) | 631.4 | 5 kat (17.5 m) | ⭐ DECISIONS.md: Fakülte / Derslik Bloğu |
| K2 Blok | (-170.1, -473.9) | 631.7 | 5 kat (17.5 m) | ⭐ DECISIONS.md: Fakülte / Derslik Bloğu |
| KAYINTI KAFE | (-99.9, -124.7) | 241.5 | 1 kat (3.5 m) | ⭐ DECISIONS.md: Fakülte Kafe (KAYINTI KAFE) |
| Kapalı Yüzme Havuzu | (-298.8, -213.6) | 1751.1 | 2 kat (7.0 m) | Diğer Kampüs Yapısı |
| L1 Blok | (-111.3, -428.1) | 856.5 | 5 kat (17.5 m) | ⭐ DECISIONS.md: Fakülte / Derslik Bloğu |
| L2 Blok | (-94.0, -392.5) | 856.9 | 5 kat (17.5 m) | ⭐ DECISIONS.md: Fakülte / Derslik Bloğu |
| L3 Blok | (-68.5, -371.4) | 856.5 | 5 kat (17.5 m) | ⭐ DECISIONS.md: Fakülte / Derslik Bloğu |
| Laboratuvar | (-161.5, 324.5) | 2432.3 | 3 kat (10.5 m) | Diğer Kampüs Yapısı |
| Merkez Kütüphanesi | (-77.2, -182.7) | 3180.2 | 3 kat (10.5 m) | Kütüphane |
| Misafirhane | (516.5, 368.8) | 1595.7 | 1 kat (3.5 m) | Diğer Kampüs Yapısı |
| Otağ-ı Hümayun | (434.4, 255.3) | 454.0 | 2 kat (7.0 m) | Diğer Kampüs Yapısı |
| Tarihi Hamam | (35.8, -137.0) | 1278.3 | 1 kat (3.5 m) | Diğer Kampüs Yapısı |
| Topraksız Tarım Araştırma ve Uygulama Serası | (-358.9, -421.4) | 1800.2 | 2 kat (7.0 m) | Diğer Kampüs Yapısı |
| YILDIZ CAFE | (216.6, -2.8) | 653.9 | 2 kat (7.0 m) | ⭐ DECISIONS.md: Fakülte Kafe (YILDIZ CAFE) |
| YTÜ Merkez Laboratuvarı | (-55.3, 512.3) | 2269.4 | 3 kat (10.5 m) | Diğer Kampüs Yapısı |
| Yabancı Diller Yüksekokulu | (165.1, 506.7) | 1816.6 | 3 kat (10.5 m) | ⭐ DECISIONS.md: Fakülte |
| Yemekhane | (-103.5, -95.2) | 2367.8 | 4 kat (14.0 m) | ⭐ DECISIONS.md: Yemekhane |
| Yıldız Teknik Store | (264.5, 2.9) | 330.1 | 2 kat (7.0 m) | Diğer Kampüs Yapısı |
| Yıldız Teknik Üniversitesi Davutpaşa Kışlası | (17.6, 26.9) | 14587.1 | 2 kat (7.0 m) | ⭐ DECISIONS.md: Kışla (Fakülte / Bölüm içerir) |
| Çağdaş Yaşam Sennur-Selçuk Öztap Kız Öğrenci Yurdu | (-179.8, -197.8) | 477.8 | 3 kat (10.5 m) | Diğer Kampüs Yapısı |
| İstanbul Kız Liseliler Kadın Öğrenci Yurdu | (-119.6, -233.4) | 380.7 | 3 kat (10.5 m) | Diğer Kampüs Yapısı |
| Şehit Mehmet Şefik Şefkatlioğlu Anaokulu | (-178.2, -363.9) | 464.2 | 3 kat (10.5 m) | Diğer Kampüs Yapısı |
| Şehit Prof. Dr. İlhan Varank Kütüphanesi | (405.0, 463.4) | 1217.4 | 3 kat (10.5 m) | Kütüphane |

---

## 6. Özet İstatistikler
- **Toplam Bina Sayısı:** 140 (61 adlandırılmış, 79 isimsiz)
- **Toplam Alan (Park/Çim/Saha) Sayısı:** 141
- **Toplam Yol (Yaya/Servis) Sayısı:** 309
- **Kampüs Dış Çevre Yarıçapı:** ~1098.5 m

## Referans: YTÜ Davutpaşa krokisi
https://hrm.yildiz.edu.tr/sites/hrm.yildiz.edu.tr/files/2023-02/davutpasa-kampusu-kroki-1.jpg
Bölge adları/konumları (game/data/zones/zones.json) bu krokiye bakılarak belirlendi. Görsel YTÜ'ye ait; oyuna ve repo'ya GİRMEZ, harita ekranı OSM verisinden çizilir.
