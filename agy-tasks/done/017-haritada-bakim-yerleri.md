# 017 — Haritada bakım yerleri (yemek / dinlenme / oyun bonusu)

## Amaç
Bakım eylemleri yere bağlı (`game/data/care_spots.json`: `eat` zorunlu, `rest` ve `play` 2× bonus). Oyuncu haritada bu yerleri görsün.
İNTERNETTEN HİÇBİR ŞEY İNDİRME (simgeler `_draw` ile çizilir, doku/ikon dosyası yok).

## Dokunabileceğin dosyalar
- `game/src/ui/campus_map.gd`
- `game/tests/test_campus_map.gd`
- `agy-tasks/done/017-haritada-bakim-yerleri.report.md`
Başka dosyaya dokunma.

## Yapılacaklar
1. `campus_map.gd` `_ready`'de `res://data/care_spots.json`'u oku. Her yer için haritada yarı saydam daire (yarıçap = `r` metre, haritanın ölçeğiyle)
   ve ortasında küçük simge çiz: `eat` turuncu daire + çatal-bıçak benzeri iki çizgi, `rest` mavi daire + "z" harfi,
   `play` yeşil daire + küçük top (daire). Simgeler yer adlarının (`_draw_places`) ALTINDA çizilsin, adları kapatmasın.
2. Haritanın altına (onay paneli kapalıyken) tek satır açıklama: "● Yemek  ● Dinlenme 2×  ● Oyun 2×" (renkli noktalar, `draw_string`).
3. Bir yere dokunma davranışı DEĞİŞMEZ (sadece yer adlarına dokununca ışınlanma).
4. Test: care_spots yükleniyor (yer sayısı JSON ile aynı); bir `play` yerinin harita koordinatı ekran içinde; çizim hatasız (sahne 2 kare çizilir,
   hata sayacı 0 — mevcut testlerdeki `_make` yardımcı fonksiyonunu kullan).

## Kabul kriterleri
- [ ] `C:/Tools/Godot/godot --headless --path game -s res://tests/run_tests.gd` exit 0, `SCRIPT ERROR` yok
- [ ] Ekran görüntüsü (kod repo DIŞINDA): `agy-tasks/done/017-harita.png`. Zor gelirse atla.

## Kurallar
- CLAUDE.md'ye uy. GDScript tipler açık, sihirli sayılar `const`. Testleri hileyle geçirme. git commit/push YAPMA.
- Raporu iş bitmese de MUTLAKA yaz: `agy-tasks/done/017-haritada-bakim-yerleri.report.md`.
