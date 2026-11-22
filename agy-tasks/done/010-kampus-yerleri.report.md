# 010 — Kampüs Yer Listesi (Landmark) Görev Raporu

## 1. Ne Yapıldı?
- YTÜ Davutpaşa Kampüsü'nün resmi kampüs haritasındaki 38 numaralı yer, 4 kapı/ulaşım noktası ve eski krokideki 5 ünlü kampüs kafesi olmak üzere toplam **47 yer** analiz edildi.
- `tools/osm/make_places.py` scripti geliştirildi (sadece Python standart kütüphanesi).
- OSM verisi (`game/data/zones/davutpasa_campus.json`) ve bölge tanımları (`game/data/zones/zones.json`) kullanılarak `game/data/places.json` dosyası deterministik biçimde üretildi.
- Türkçe karakter ve büyük/küçük harf duyarsız normalizasyon algoritmasıyla OSM binaları ve alanları sorgulandı:
  - Adı OSM'de doğrudan veya yakın benzerlikle bulunan yerler `source: "osm"` ve `osm_name` ile eşleştirildi (19 yer).
  - OSM'de bağımsız bina/alan adı bulunmayan veya açık alan niteliğindeki yerler resmi harita ve kroki görselleriyle doğrulanarak elle koordinatlandırıldı (`source: "manual"`, 28 yer).
  - Elle belirlenen tüm koordinatlar ve gerekçeleri script içerisinde `MANUAL_PLACES` sözlüğünde yorum satırlarıyla açıkça belgelendi.
- Her yerin konumu `zones.json` bölgelerinin yarıçaplarına göre test edildi ve birden fazla bölgeye düşenlerde merkeze en yakın olan bölge atandı; hiçbir bölgeye düşmeyenler boş string `""` bırakıldı.
- `game/tests/test_places.gd` test paketi yazıldı: dosya yükleme ve şema geçerliliği, benzersiz id'ler, kampüs sınırları kontrolü (-500..900, -700..850) ve zorunlu landmark'ların (Yemekhane, Ortabahçe, İnşaat Fakültesi, YTÜ Stadyumu) bölge atamaları doğrulandı.

---

## 2. Hangi Dosyalar?
- `tools/osm/make_places.py` (yeni)
- `game/data/places.json` (yeni, script üretir)
- `game/tests/test_places.gd` (yeni)
- `agy-tasks/done/010-kampus-yerleri.report.md` (yeni)

*(Başka hiçbir dosyaya dokunulmamıştır. Git commit veya push yapılmamıştır.)*

---

## 3. Eşleşme Tablosu (Yer → OSM Adı / Manual)

| No | ID | Yer Adı | Tür (`kind`) | Kaynak (`source`) | OSM Adı / Manuel Gerekçesi | Konum [X, Z] | Bölge (`zone`) |
|:---|:---|:---|:---|:---|:---|:---|:---|
| 1 | `tasbina` | Taşbina / Rektörlük / İdari Bilimler / Enstitüler | `landmark` | `osm` | Yıldız Teknik Üniversitesi Davutpaşa Kışlası | [17.6, 26.9] | `ortabahce` |
| 2 | `ortabahce` | Ortabahçe | `landmark` | `osm` | Ortabahçe | [-2.1, 5.3] | `ortabahce` |
| 3 | `yemekhane` | Yemekhane | `food` | `osm` | Yemekhane | [-103.5, -95.2] | `ortabahce` |
| 4 | `elektrik_elektronik_fakultesi` | Elektrik-Elektronik Fakültesi | `faculty` | `osm` | Elektrik Elektronik Fakültesi | [47.1, -254.7] | `fef` |
| 5 | `fen_edebiyat_fakultesi` | Fen-Edebiyat Fakültesi | `faculty` | `osm` | A Blok - Fen Edebiyat Fakültesi Dekanlığı | [164.2, -184.8] | `fef` |
| 6 | `kimya_metalurji_fakultesi` | Kimya-Metalurji Fakültesi | `faculty` | `manual` | B, D, E blokları civarındaki kompleks | [240.0, -230.0] | `fef` |
| 7 | `iktisat_ve_idari_bilimler_fakultesi` | İktisat ve İdari Bilimler Fakültesi | `faculty` | `manual` | FEF kuzeydoğusu isimsiz bina çifti (Bldg 129, 130) | [353.8, -183.8] | *(bölge dışı)* |
| 8 | `ring_ve_otobus_peronu` | Ring ve Otobüs Peronu | `transport` | `manual` | Otobüs peronları ve ring bekleme cebi | [210.0, -95.0] | `fef` |
| 9 | `otag_i_humayun` | Otağ-ı Hümayun | `landmark` | `osm` | Otağ-ı Hümayun | [434.4, 255.3] | `kutuphane` |
| 10 | `kongre_merkezi` | Kongre Merkezi | `service` | `manual` | Dairesel isimsiz modern kongre binası (Bldg 82) | [549.2, 305.7] | `kutuphane` |
| 11 | `kutuphane` | Kütüphane | `service` | `osm` | Şehit Prof. Dr. İlhan Varank Kütüphanesi | [405.0, 463.4] | `kutuphane` |
| 12 | `yabanci_diller_yuksekokulu` | Yabancı Diller Yüksekokulu | `faculty` | `osm` | Yabancı Diller Yüksekokulu | [165.1, 506.7] | `guney` |
| 13 | `teknopark` | Teknopark | `service` | `manual` | A1-D2 Teknopark blokları merkezi | [53.5, 660.5] | `guney` |
| 14 | `merkez_laboratuvari` | Merkez Laboratuvarı | `service` | `osm` | YTÜ Merkez Laboratuvarı | [-55.3, 512.3] | `guney` |
| 15 | `hidrodinamik_laboratuvari` | Hidrodinamik Laboratuvarı | `service` | `osm` | Hidrolik Laboratuarı | [-168.4, 429.9] | `insaat` |
| 16 | `insaat_fakultesi` | İnşaat Fakültesi | `faculty` | `osm` | E Blok - İnşaat Mühendisliği | [-109.5, 300.8] | `insaat` |
| 17 | `bilgelik_yolu` | Bilgelik Yolu | `landmark` | `manual` | Taşbina-YDYO arası tören/yürüyüş yolu (OSM way 1437077332) | [130.4, 300.3] | `insaat` |
| 18 | `ytu_stadyumu` | YTÜ Stadyumu | `sport` | `manual` | Futbol stadyumu isimsiz pitch alanı (Area 0) | [-285.5, 49.3] | `saha` |
| 19 | `kulupler_vadisi` | Kulüpler Vadisi | `sport` | `manual` | Stadyum kuzeyindeki kulüp konteynerleri vadisi | [-280.0, -20.0] | `saha` |
| 20 | `spor_kompleksi` | Spor Kompleksi / Beden Eğitimi Bölümü | `sport` | `manual` | Kapalı yüzme havuzu ve spor salonu (Bldg 95) | [-298.8, -213.6] | `egitim` |
| 21 | `acik_oyun_sahalari` | Açık Oyun Sahaları | `sport` | `manual` | Açık tenis, basketbol ve halı sahalar kompleksi | [-260.0, -115.0] | `saha` |
| 22 | `yildiz_store_supermarket` | Yıldız Store / Süpermarket | `service` | `manual` | Yemekhane batı cephesi market yapısı (Bldg 40) | [-127.8, -68.0] | `saha` |
| 23 | `sehide_turkan_turkmen_tekin_kiz_ogrenci_yurdu` | Şehide Türkan Türkmen Tekin Kız Öğrenci Yurdu | `dorm` | `manual` | Kız yurdu kulesi (OSM Bldg 37 Çağdaş Yaşam) | [-179.8, -197.8] | `egitim` |
| 24 | `egitim_fakultesi` | Eğitim Fakültesi | `faculty` | `osm` | Eğitim Fakültesi | [-280.0, -304.8] | `egitim` |
| 25 | `mediko` | Mediko | `service` | `manual` | Sağlık merkezi binası (Bldg 96) | [-373.1, -315.7] | `egitim` |
| 26 | `bilgi_islem_merkezi` | Bilgi İşlem Merkezi | `service` | `manual` | Bilgi İşlem Daire Başkanlığı binası (Bldg 97) | [-374.7, -370.5] | `egitim` |
| 27 | `ytu_kyk_yurdu` | YTÜ-KYK Erkek ve Kız Yurdu | `dorm` | `manual` | Kuzeybatı KYK yurtları yerleşkesi | [-354.9, -474.6] | *(bölge dışı)* |
| 28 | `lojmanlar` | Lojmanlar | `dorm` | `manual` | Öğretim üyesi lojman blokları (J, K, L, C, F) | [-170.0, -450.0] | *(bölge dışı)* |
| 29 | `sanat_ve_tasarim_fakultesi` | Sanat ve Tasarım Fakültesi | `faculty` | `manual` | Taşbina batı kanadı | [-100.0, 50.0] | `ortabahce` |
| 30 | `sancak_kosku` | Sancak Köşkü | `landmark` | `manual` | YDYO doğusundaki koruluk içi tarihi köşk | [300.0, 350.0] | `kutuphane` |
| 31 | `yeni_kutuphane` | Yeni Kütüphane | `service` | `osm` | Merkez Kütüphanesi | [-77.2, -182.7] | `ortabahce` |
| 32 | `guvenlik_mudurlugu` | Güvenlik Müdürlüğü | `service` | `manual` | Güvenlik hizmet binası (OSM Bldg 137) | [95.4, 426.2] | `guney` |
| 33 | `temiz_enerji_enstitusu` | Temiz Enerji Teknolojileri Enstitüsü | `service` | `manual` | Güneş panelli enstitü yapısı | [10.0, 470.0] | `guney` |
| 34 | `yildiz_teknopark_yonetim_binasi` | Yıldız Teknopark Yönetim Binası | `service` | `manual` | Teknopark yönetim binası (OSM Bldg 93) | [-140.9, 551.0] | `guney` |
| 35 | `innovation_hub` | Innovation Hub | `service` | `manual` | Teknopark kuluçka / inovasyon yapısı | [-200.0, 530.0] | *(bölge dışı)* |
| 36 | `academic_lounge` | Academic Lounge | `food` | `osm` | Academic Lounge | [-37.4, 350.7] | `insaat` |
| 37 | `misafirhane` | Misafirhane | `service` | `osm` | Misafirhane | [516.5, 368.8] | `kutuphane` |
| 38 | `cami` | Cami | `landmark` | `manual` | Davutpaşa Kampüs Camii (kuzey kapı/lojmanlar) | [-70.0, -345.0] | *(bölge dışı)* |
| - | `a_girisi` | A Girişi | `gate` | `manual` | Ana doğu nizamiye kapısı (41AT durakları) | [800.0, 575.0] | *(bölge dışı)* |
| - | `b_girisi` | B Girişi | `gate` | `manual` | Kuzey nizamiye kapısı (metro bağlantısı) | [-70.0, -470.0] | *(bölge dışı)* |
| - | `teknopark_girisi` | Teknopark Girişi | `gate` | `manual` | Teknopark güney nizamiye kapısı | [15.0, 830.0] | *(bölge dışı)* |
| - | `m1a_davutpasa_ytu_metro` | M1A Davutpaşa-YTÜ metro durağı | `transport` | `manual` | Kampüs dışı viyadük metro istasyonu | [-40.0, -560.0] | *(bölge dışı)* |
| - | `hokka` | Hokka | `food` | `osm` | Hokka | [-75.2, -106.6] | `ortabahce` |
| - | `kayinti_kafe` | Kayıntı Kafe | `food` | `osm` | KAYINTI KAFE | [-99.9, -124.7] | `ortabahce` |
| - | `buyuk_ev` | Büyük Ev | `food` | `osm` | BÜYÜK EV | [-15.5, -74.5] | `ortabahce` |
| - | `eskafe` | Eskafe | `food` | `osm` | Eskafe | [133.6, 339.7] | `insaat` |
| - | `yildiz_cafe` | YILDIZ CAFE | `food` | `osm` | YILDIZ CAFE | [216.6, -2.8] | `ortabahce` |

---

## 4. Hiçbir Bölgeye Düşmeyen Yerler (9 Yer)
Aşağıdaki yerler `game/data/zones/zones.json` içerisindeki mevcut 7 bölgenin yarıçap sınırlarının dışında kalmaktadır (`zone: ""`):

1. **İktisat ve İdari Bilimler Fakültesi (`pos: [353.8, -183.8]`):**
   - FEF merkezine `[130, -230]` olan mesafesi 228.5 metredir. FEF yarıçapı 220 metre olduğu için sınırın yalnızca ~8.5 metre dışında kalmıştır. (Öneri: FEF yarıçapı 235 metreye çıkarılırsa kapsanabilir veya İİBF ayrı bir bölge yapılabilir).
2. **YTÜ-KYK Erkek ve Kız Yurdu (`pos: [-354.9, -474.6]`):**
   - Eğitim / Yurtlar bölgesi merkezine `[-290, -260]` 224 metre mesafededir (bölge yarıçapı 160 m). Kampüsün kuzeybatı ucundadır.
3. **Lojmanlar (`pos: [-170.0, -450.0]`):**
   - Kampüsün kuzeyindeki lojman bloklarıdır. En yakın bölge Eğitim'e 224 m mesafededir.
4. **Cami (`pos: [-70.0, -345.0]`):**
   - Lojmanlar ve B kapısı kavşağındaki ana kampüs camisidir.
5. **Innovation Hub (`pos: [-200.0, 530.0]`):**
   - Teknopark alanının en batı ucudur. Güney bölgesi yarıçapının (230 m) dışında kalır.
6. **A Girişi (`pos: [800.0, 575.0]`):**
   - Kampüsün en doğu nizamiye kapısıdır.
7. **B Girişi (`pos: [-70.0, -470.0]`):**
   - Kampüsün en kuzey nizamiye kapısıdır.
8. **Teknopark Girişi (`pos: [15.0, 830.0]`):**
   - Kampüsün en güney nizamiye kapısıdır.
9. **M1A Davutpaşa-YTÜ metro durağı (`pos: [-40.0, -560.0]`):**
   - Kampüs sınırları dışındaki metro viyadük istasyonudur.

*(Not: Bu yerler için ileride "kuzey_lojmanlar" veya "teknopark" gibi yeni bölgelerin açılması ROADMAP kapsamında değerlendirilebilir).*

---

## 5. Test Sonuçları
- **Godot Test Runner:**
  Komut: `C:/Tools/Godot/godot --headless --path game -s res://tests/run_tests.gd`
  Çıktı: `108 geçti, 0 başarısız`, exit code 0, çıktıda hiçbir `SCRIPT ERROR` yok.
  Eklenen testler:
  - `test_places.gd::test_places_file_loads_and_schema_valid` (ok)
  - `test_places.gd::test_places_ids_unique` (ok)
  - `test_places.gd::test_places_within_campus_bounds` (ok)
  - `test_places.gd::test_required_landmarks_present_and_zoned` (ok: Yemekhane, Ortabahçe, İnşaat Fakültesi, YTÜ Stadyumu)
- **Determinizm Kontrolü:**
  Komut: `python -I tools/osm/make_places.py`
  Tekrar çalıştırıldığında `game/data/places.json` üzerinde `git diff` çıktısı boştur; dosya tamamen deterministiktir.

---

## 6. Belirsiz Kalanlar / Açık Konular
1. **İİBF Bölge Kapsamı:** İktisat ve İdari Bilimler Fakültesi FEF yarıçapının yalnızca 8.5 metre dışında kalmaktadır. `zones.json`'da FEF yarıçapının 220 m'den 235 m'ye güncellenmesi veya ileride ayrı bölge yapılması Talha'nın onayına sunulabilir.
2. **Kuzey / Lojmanlar Bölgesi:** KYK Yurtları, Lojmanlar ve Davutpaşa Camii kampüsün kuzeyinde yer almakta olup mevcut 7 greybox bölgesi arasında bir "kuzey/lojman" bölgesi bulunmamaktadır.
3. **Teknopark Bölgesi:** Teknopark binaları şu anda `guney` bölgesine dahil edilirken, Teknopark Girişi ve Innovation Hub bu yarıçapın dışında kalmaktadır.
