# 005 — Davutpaşa kampüsünün tamamı için OSM verisi (ROADMAP 5.1)

## Amaç
Ortabahçe için yazılmış `tools/osm/osm_to_greybox.py` scriptini kampüsün tamamına genişletip kampüs geneli greybox
verisini üretmek. Oyun koduna dokunma; sadece veri ve script.

## Dokunabileceğin dosyalar
- `tools/osm/osm_to_greybox.py` (geriye uyumlu genişlet: mevcut `--center-park` kullanımı aynı çıktıyı vermeye devam etmeli)
- `art/reference/osm/davutpasa.json` (gerekirse Overpass'tan yeniden çek; kampüs sınırı OSM way 666081501)
- `game/data/zones/davutpasa_campus.json` (yeni)
- `art/reference/osm/README.md` (yeni)
- `agy-tasks/done/005-kampus-osm.report.md`
Başka dosyaya dokunma (özellikle `game/data/zones/ortabahce_greybox.json` aynı kalmalı).

## Yapılacaklar
1. Scripte `--area-way <osm_way_id>` seçeneği ekle: merkez = o alanın ağırlık merkezi, sadece alan çokgeninin İÇİNDEKİ
   (ağırlık merkezi içeride kalan) bina/alan/yolları al (`--radius` yerine). Orijin yine Ortabahçe merkezi olsun ki iki
   dosya aynı koordinat sisteminde olsun: `--origin-park "Ortabahçe"` seçeneği ekle.
2. `game/data/zones/davutpasa_campus.json` üret: `--area-way 666081501 --origin-park "Ortabahçe"`.
3. `art/reference/osm/README.md`: veri kaynağı (ODbL), nasıl yeniden üretilir (komutlar), ve bir tablo:
   adı olan tüm binalar → yaklaşık merkez (x, z metre), taban alanı (m²), kat → yükseklik. DECISIONS.md'deki harita
   kapsamındaki yerleri (fakülteler, Büyükev, Hokka, fakülte kafeleri, yemekhane, büyük saha) özellikle işaretle;
   OSM'de bulunamayanları "eksik" diye listele.
4. Doğrulama: script her iki komutla da çalışıyor; `ortabahce_greybox.json` byte-byte değişmedi (`git diff --stat` boş).

## Kabul kriterleri
- [ ] `python -I tools/osm/osm_to_greybox.py art/reference/osm/davutpasa.json --center-park "Ortabahçe" --radius 220 --out game/data/zones/ortabahce_greybox.json` sonrası `git diff game/data/zones/ortabahce_greybox.json` boş
- [ ] `davutpasa_campus.json` var, bina sayısı rapordа
- [ ] `C:/Tools/Godot/godot --headless --path game -s res://tests/run_tests.gd` exit 0

## Kurallar
- CLAUDE.md'ye uy. Python'da sadece standart kütüphane. git commit/push YAPMA (runner yapar).
- Rapor: `agy-tasks/done/005-kampus-osm.report.md`, Türkçe.
