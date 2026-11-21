# 008 — Ortabahçe detayları: ağaç, bank, lamba, çalı (ROADMAP 5.3)

## Amaç
Greybox Ortabahçe'yi canlandırmak: çim alanlara ağaç/çalı, yolların kenarına bank ve lamba. Sadece CC0 asset,
mobil bütçe içinde. Yerleşim elle değil, mevcut greybox verisinden (`game/data/zones/ortabahce_greybox.json`) üretilsin.

## Dokunabileceğin dosyalar
- `art/props.json` (yeni) — kullanılan asset'lerin kaynak listesi (poly.pizza id, glb uuid, lisans, üçgen sayısı)
- `tools/assets/fetch_props.py` (yeni) — `art/props.json`'dan glb indirir (örnek: `tools/assets/fetch_pets.py`)
- `game/assets/props/` (yeni klasör; sadece indirilen .glb ve Godot'un .import dosyaları)
- `tools/osm/place_props.py` (yeni) — greybox JSON'dan yerleşim üretir
- `game/data/zones/ortabahce_props.json` (yeni) — üretilen yerleşim
- `game/src/world/prop_placer.gd` (yeni) — yerleşimi sahneye kurar
- `game/tests/test_props.gd` (yeni)
- `game/scenes/main.tscn` — SADECE `World` (NavigationRegion3D) altına PropPlacer düğümü eklemek için
- `game/assets/CREDITS.md` — tek satır ekle
- `agy-tasks/done/008-ortabahce-detay.report.md`
Başka dosyaya dokunma (`greybox_builder.gd` dahil).

## Yapılacaklar
1. Asset: poly.pizza'da **Quaternius** (CC0) modelleri ara: 2-3 ağaç türü, 1-2 çalı, bank, sokak lambası, çöp kutusu.
   Her biri < 1500 üçgen (ağaç < 2500). Sayfa: `https://poly.pizza/m/<id>`, glb: `https://static.poly.pizza/<uuid>.glb`
   (sayfa HTML'inde `static.poly.pizza/<uuid>.glb` geçer; lisans ve "By Quaternius" sayfada yazar). Animasyonlu olanları alma.
   Bulamazsan başka CC0 kaynağı kullanma, rapora yaz.
2. `place_props.py` (sadece standart kütüphane, deterministik: sabit seed):
   - Ağaç/çalı: `areas` içindeki çim/park çokgenlerinin İÇİNE, birbirinden ≥ 4 m, yollardan ≥ 2.5 m, binalardan ≥ 3 m uzak;
     yoğunluk ~ 1 ağaç / 120 m², toplam ağaç ≤ 160.
   - Bank + lamba: Ortabahçe parkı içindeki yollar (`paths`) boyunca ~ her 18 m'de bir, yolun 1.8 m yanına, yola bakacak şekilde
     (yaw), lamba ~ her 25 m. Çöp kutusu bankların bir kısmının yanında.
   - Çıktı: `{"props": [{"type": "tree_a", "pos": [x, z], "yaw": rad, "scale": s}]}`.
3. `prop_placer.gd` (Node3D): JSON'u okur, her tür için glb'yi bir kez yükler. Çok sayıda kopya için `MultiMeshInstance3D`
   kullan (tür başına bir tane; glb'deki mesh'i çıkar). Ağaç/lamba/bank için basit çarpışma: ağaç gövdesi ve lamba = ince
   `CylinderShape3D`, bank = `BoxShape3D` (tek bir StaticBody3D altında çok shape olabilir). Çalılara çarpışma YOK.
   `NavigationRegion3D` çocuk geometriyi çarpışmadan pişirdiği için engeller navmesh'e otomatik girer.
4. Test: JSON yükleniyor; tüm `type`'ların glb'si var; hiçbir prop bina çokgeninin içinde değil; oyuncunun başlangıç noktasına
   (orijin) 3 m'den yakın prop yok; toplam üçgen bütçesi (tür üçgeni × adet) < 250.000.
5. `CREDITS.md`'ye satır: kullanılan Quaternius paket(ler)i, CC0, poly.pizza.

## Kabul kriterleri
- [ ] `C:/Tools/Godot/godot --headless --path game --import` hatasız
- [ ] `C:/Tools/Godot/godot --headless --path game -s res://tests/run_tests.gd` exit 0
- [ ] `C:/Tools/Godot/godot --headless --path game --quit-after 60` çıktısında `ERROR`/`SCRIPT ERROR` yok
- [ ] Ekran görüntüsü `agy-tasks/done/008-ortabahce.png`: oyun kamerasından Ortabahçe (görüntü kodu repo DIŞINDA, `%TEMP%`'te)

## Kurallar
- CLAUDE.md'ye uy. GDScript tipler açık. Python sadece standart kütüphane. Sihirli sayılar `const`.
- Görüntü alma kodunu oyun koduna KOYMA. `Services._ready()` çağırma.
- git commit/push YAPMA (runner yapar).
- Rapor: `agy-tasks/done/008-ortabahce-detay.report.md`, Türkçe.
