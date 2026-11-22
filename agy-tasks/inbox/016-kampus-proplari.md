# 016 — Ağaç/bank/lamba kampüsün tamamına (mobil bütçeyle)

## Amaç
Şu an proplar sadece Ortabahçe'de (`game/data/zones/ortabahce_props.json`). Kampüs artık tek bölge
(`game/data/zones/kampus_greybox.json`, 140 bina, 141 alan, 309 yol). Propları tüm kampüse yay, ama telefon kaldırsın:
kampüsü ızgara hücrelerine böl, her hücre ayrı MultiMesh olsun ve uzaktaki hücreler çizilmesin.
Modeller hazır (`game/assets/props/*.glb`, `art/props.json`). İNTERNETTEN HİÇBİR ŞEY İNDİRME.

## Dokunabileceğin dosyalar
- `tools/osm/place_props.py`
- `game/data/zones/kampus_props.json` (yeni, script üretir)
- `game/src/world/prop_placer.gd`
- `game/data/zones/zones.json` — SADECE kampus'un `"props"` alanını `res://data/zones/kampus_props.json` yapmak için
- `game/tests/test_props.gd`
- `agy-tasks/done/016-kampus-proplari.report.md`
Başka dosyaya dokunma.

## Yapılacaklar
1. `place_props.py`'ye `--greybox` ve `--out` parametreleri ekle (varsayılanlar mevcut Ortabahçe davranışı; `ortabahce_props.json`
   aynı kalmalı). Kampüs için: `--greybox game/data/zones/kampus_greybox.json --out game/data/zones/kampus_props.json`.
   Kurallar aynı (bina/yol/orijin mesafeleri, seed 42). Kampüs sınırları: ağaç ≤ 700, çalı ≤ 300, bank/lamba/çöp kutusu tüm yaya yollarında
   (sadece Ortabahçe değil) ama toplam bank ≤ 250, lamba ≤ 200.
2. `prop_placer.gd`: propları 100 m × 100 m hücrelere grupla; her (hücre, tür) için bir `MultiMeshInstance3D`.
   Her MultiMeshInstance3D'ye `visibility_range_end` ver: ağaç 220 m, bank/lamba/çöp/çalı 120 m (`visibility_range_end_margin` 20,
   `visibility_range_fade_mode` = FADE_SELF). Çarpışma şekilleri değişmez (görünürlükten bağımsız).
3. `zones.json`'da kampus `props` → `res://data/zones/kampus_props.json`.
4. NOT: prop yerleşimi değişince yürüme haritası özeti değişir; `tools/nav/bake_zone_navmeshes.gd`'yi ÇALIŞTIR ki
   `game/data/zones/kampus_navmesh.res` güncellensin (3-4 dk sürer; komut: `C:/Tools/Godot/godot --headless --path game -s C:/Users/talha/Documents/unipet/tools/nav/bake_zone_navmeshes.gd`)
   ve bu dosyayı da değiştirmen gerekir — bu dosya da izinli: `game/data/zones/kampus_navmesh.res`.
5. Test (`test_props.gd`): kampus_props yükleniyor; hiçbir prop bina içinde değil; Ortabahçe JSON'u hâlâ geçerli; hücreleme fonksiyonu
   doğru hücre veriyor; toplam üçgen (tris × adet) < 1.600.000 ama tek bir oyuncu noktasından 220 m içindeki üçgen < 300.000
   (Ortabahçe merkezi ve 3 rastgele noktada ölç).

## Kabul kriterleri
- [ ] `C:/Tools/Godot/godot --headless --path game -s res://tests/run_tests.gd` exit 0, `SCRIPT ERROR` yok
      (`test_prebaked_navmeshes_up_to_date` dahil — navmesh'i yeniden pişirmezsen bu test kırılır)
- [ ] `C:/Tools/Godot/godot --headless --path game --quit-after 60` çıktısında `ERROR`/`SCRIPT ERROR` yok

## Kurallar
- CLAUDE.md'ye uy. GDScript tipler açık, sihirli sayılar `const`. Python sadece standart kütüphane. Testleri hileyle geçirme.
- git commit/push YAPMA. Raporu iş bitmese de MUTLAKA yaz: `agy-tasks/done/016-kampus-proplari.report.md`.
