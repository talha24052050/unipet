# 020 — Parke taşı yollar + kırmızı tuğla kenar + klasik fener

## Amaç
Gerçek Davutpaşa'da yaya yolları gri küp taş (parke), kenarları kırmızı tuğla şerit; fenerler beyaz küre başlıklı klasik
siyah direkler. Oyunu buna benzet. İNTERNETTEN HİÇBİR ŞEY İNDİRME (her şey kodla/shader ile).

## Dokunabileceğin dosyalar
- `game/src/world/greybox_builder.gd` — SADECE `_build_path` fonksiyonu ve yol ile ilgili yeni sabitler/yardımcılar
- `game/assets/shaders/path_cobble.gdshader` (yeni)
- `game/src/world/prop_placer.gd` — SADECE "lamp" görünümü için
- `game/src/world/lamp_mesh.gd` (yeni, kodla fener mesh'i üretir)
- `game/tests/test_paths_lamps.gd` (yeni)
- `agy-tasks/done/020-parke-yollar-fenerler.report.md`
Başka dosyaya dokunma. `building_style.gd`, `building_wall.gdshader`, `day_night.gd`, `tools/assets/*` dosyalarına DOKUNMA (Claude çalışıyor).

## Yapılacaklar
1. Yaya yolları (`footway`, `path`, `pedestrian`; `service` HARİÇ — o asfalt kalsın):
   - `path_cobble.gdshader`: dünya XZ koordinatına göre ~0.25 m küp taş deseni (açık gri taşlar #B9B7B2 civarı, aralarda koyu derz
     #8E8C88), küçük renk oynaması (hash ile), kenara 0.35 m kala kırmızı tuğla şeridi (#A9553F civarı). Kenar uzaklığı için mesh'e
     UV.x = yol genişliği boyunca 0..1 koy (0 ve 1 kenar), shader `UV.x`'e bakar. `mobile` renderer'da çalışmalı, doku dosyası YOK.
   - Yol mesh'inin UV'si yoksa ekle. Mevcut yol genişlikleri ve yükseklik aynı kalsın; navmesh'i ETKİLEMESİN
     (yol geometrisi aynı, sadece materyal/UV değişir).
2. Fener (`lamp_mesh.gd`): siyah ince direk (~3.6 m, alt kaide biraz kalın), üstte beyaz/krem küre (r≈0.25, gece `emission` ile
   parlak), toplam < 300 üçgen. `prop_placer.gd`'de "lamp" tipi için glb yerine bu mesh kullanılsın (MultiMesh sistemine uyumlu
   şekilde; mevcut chunk/visibility mantığını bozma). Gece ışıkları (StreetLights) aynı konumlarda kalmalı.
3. Test: yaya yolunda UV.x 0..1 aralığında; service yolu cobble materyali KULLANMIYOR; fener mesh'i < 300 üçgen ve yüksekliği 3–4.5 m;
   prop_placer "lamp" için mesh üretiyor.
4. Ekran görüntüsü (repo dışı değil, `agy-tasks/done/020-yollar.png`): Ortabahçe'de bir yol + fener. Zor gelirse atla.

## Kabul kriterleri
- [ ] `C:/Tools/Godot/godot --headless --path game -s res://tests/run_tests.gd` exit 0, `SCRIPT ERROR` yok
- [ ] `C:/Tools/Godot/godot --headless --path game --quit-after 60` çıktısında `ERROR` yok
- [ ] Mevcut testlerin hiçbiri değiştirilmedi

## Kurallar
- CLAUDE.md'ye uy. GDScript tipler açık, sihirli sayılar `const`. Testleri hileyle geçirme. git commit/push YAPMA.
- Raporu iş bitmese de MUTLAKA yaz: `agy-tasks/done/020-parke-yollar-fenerler.report.md`.
