# 010 — Kampüs yer listesi (landmark) verisi

## Amaç
Oyunda bina adları ve harita ekranı için tek bir yer listesi: YTÜ'nün resmi kampüs haritasındaki numaralı yerler
OSM verimizle eşleştirilip `game/data/places.json`'a yazılacak. Görselin kendisi oyuna/repo'ya GİRMEZ; sadece isim ve
yaklaşık konum bilgisi kullanılır.

## Kaynaklar (oku)
- Yer listesi (aşağıda, resmi haritadan; görsel: https://tanitim.yildiz.edu.tr/images/kampusler/harita-davutpasa.jpg)
- Eski kroki (konum doğrulamak için): https://hrm.yildiz.edu.tr/sites/hrm.yildiz.edu.tr/files/2023-02/davutpasa-kampusu-kroki-1.jpg
- `game/data/zones/davutpasa_campus.json` (OSM binaları/alanları, Ortabahçe merkezli metre: +X doğu, -Z kuzey)
- `art/reference/osm/README.md` (adlı binalar tablosu), `game/data/zones/zones.json` (bölgeler: center + radius)

Resmi haritadaki yerler:
1 Taşbina / Rektörlük / İdari Bilimler / Enstitüler · 2 Ortabahçe · 3 Yemekhane · 4 Elektrik-Elektronik Fakültesi ·
5 Fen-Edebiyat Fakültesi · 6 Kimya-Metalurji Fakültesi · 7 İktisat ve İdari Bilimler Fakültesi · 8 Ring ve Otobüs Peronu ·
9 Otağ-ı Hümayun · 10 Kongre Merkezi · 11 Kütüphane · 12 Yabancı Diller Yüksekokulu · 13 Teknopark · 14 Merkez Laboratuvarı ·
15 Hidrodinamik Laboratuvarı · 16 İnşaat Fakültesi · 17 Bilgelik Yolu · 18 YTÜ Stadyumu · 19 Kulüpler Vadisi ·
20 Spor Kompleksi / Beden Eğitimi Bölümü · 21 Açık Oyun Sahaları · 22 Yıldız Store / Süpermarket ·
23 Şehide Türkan Türkmen Tekin Kız Öğrenci Yurdu · 24 Eğitim Fakültesi · 25 Mediko · 26 Bilgi İşlem Merkezi ·
27 YTÜ-KYK Erkek ve Kız Yurdu · 28 Lojmanlar · 29 Sanat ve Tasarım Fakültesi · 30 Sancak Köşkü · 31 Yeni Kütüphane ·
32 Güvenlik Müdürlüğü · 33 Temiz Enerji Teknolojileri Enstitüsü · 34 Yıldız Teknopark Yönetim Binası · 35 Innovation Hub ·
36 Academic Lounge · 37 Misafirhane · 38 Cami
Ayrıca: A Girişi, B Girişi, Teknopark Girişi, M1A Davutpaşa-YTÜ metro durağı (kampüs dışında, B girişine yakın).
Eski krokiden: Hokka, Kayıntı Kafe, Büyük Ev, Eskafe, YILDIZ CAFE (OSM'de adlı binalar).

## Dokunabileceğin dosyalar
- `tools/osm/make_places.py` (yeni)
- `game/data/places.json` (yeni, script üretir)
- `game/tests/test_places.gd` (yeni)
- `agy-tasks/done/010-kampus-yerleri.report.md`
Başka dosyaya dokunma.

## Yapılacaklar
1. `make_places.py` (standart kütüphane): her yer için OSM'de en iyi eşleşmeyi bul (bina adı benzerliği; Türkçe karakter ve
   büyük/küçük harf duyarsız). Eşleşme yoksa ya da emin değilsen, iki haritadaki konuma ve OSM'deki yakın isimsiz binalara/alanlara
   bakarak ELLE koordinat ver ve `"source": "manual"` yaz; eşleşenlerde `"source": "osm"` ve `"osm_name"`.
   Elle konumları scriptin içinde açıkça bir sözlükte tut (gerekçesi yorum satırında).
2. Çıktı: `{"places": [{"id": "yemekhane", "name": "Yemekhane", "kind": "food|faculty|dorm|sport|landmark|service|gate|transport",
   "pos": [x, z], "zone": "<zones.json id ya da boş>", "source": "osm|manual", "osm_name": "..."}]}`.
   `zone`: konum hangi bölgenin yarıçapı içindeyse (birden fazlaysa merkeze en yakın).
3. Rapor: eşleşme tablosu (yer → OSM adı / manual) ve hiçbir bölgeye düşmeyen yerlerin listesi (bölge eklemek gerekebilir).
4. Test: dosya yükleniyor; id'ler benzersiz; tüm konumlar kampüs sınırları içinde (x -500..900, z -700..850);
   Yemekhane, Ortabahçe, İnşaat Fakültesi, YTÜ Stadyumu var ve bir bölgeye düşüyor.

## Kabul kriterleri
- [ ] `C:/Tools/Godot/godot --headless --path game -s res://tests/run_tests.gd` exit 0, çıktıda `SCRIPT ERROR` yok
- [ ] `python -I tools/osm/make_places.py` tekrar çalışınca aynı dosyayı üretir (deterministik)

## Kurallar
- CLAUDE.md'ye uy. Python sadece standart kütüphane. git commit/push YAPMA.
- Raporu iş bitmese de MUTLAKA yaz: `agy-tasks/done/010-kampus-yerleri.report.md` (Türkçe).
