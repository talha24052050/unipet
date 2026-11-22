# 014 — 4 yeni aksesuar (indirme YOK, Godot ilkel şekilleriyle)

## Amaç
Mevcut 4 aksesuara (`hat_cap`, `glasses`, `scarf`, `backpack`) her slottan birer yenisini ekle. İnternet kısıtlı: hiçbir şey indirme;
`game/assets/accessories/*.tscn` örneklerindeki gibi Godot ilkel mesh'leriyle (Box/Cylinder/Sphere/Torus/Prism) yap.

## Dokunabileceğin dosyalar
- `game/assets/accessories/beanie.tscn`, `sunglasses.tscn`, `bowtie.tscn`, `wings.tscn` (yeni)
- `game/data/accessories/beanie.tres`, `sunglasses.tres`, `bowtie.tres`, `wings.tres` (yeni)
- `game/tests/test_new_accessories.gd` (yeni)
- `agy-tasks/done/014-yeni-aksesuarlar.report.md`
Başka dosyaya dokunma.

## Yapılacaklar
1. Sahne kuralları `game/src/characters/accessory_def.gd` başındaki yorumda: ~1 m boy / 0.9 m genişlikte pete göre metre cinsinden,
   pivot: head = tabanı, face = köprü ortası, neck = halka merkezi, back = sırta değen yüz; +Z öne bakar. Mevcut 4 sahneye bakıp aynı ölçekte yap.
2. Aksesuarlar (renkler YTÜ: lacivert `Color(0.12, 0.18, 0.42)`, sarı `Color(0.96, 0.76, 0.2)` ağırlıklı):
   - `beanie` (head, "Bere"): yarım küre + kıvrık kenar + üstte ponpon
   - `sunglasses` (face, "Güneş gözlüğü"): koyu camlı, köşeli çerçeve
   - `bowtie` (neck, "Papyon"): iki üçgen prizma + ortada küçük küp (boynun önünde, halka değil; pivot boyun merkezi, papyon +Z'de öne doğru)
   - `wings` (back, "Kanatlar"): iki ince, hafif açılı beyaz kanat (yassı kutu/prizma), sırttan dışarı
   Her biri < 300 üçgen.
3. `.tres` dosyaları mevcutlar gibi (`script_class="AccessoryDef"`, id, display_name, slot, scene_path).
4. Test: 8 aksesuar yükleniyor; yeni 4'ü 6 petin hepsine takılabiliyor (`res://src/characters/pet_visual.gd` → `set_character` + `equip`
   true döner); her slotta 2 seçenek var.

## Kabul kriterleri
- [ ] `C:/Tools/Godot/godot --headless --path game --import` hatasız
- [ ] `C:/Tools/Godot/godot --headless --path game -s res://tests/run_tests.gd` exit 0, çıktıda `SCRIPT ERROR` yok
- [ ] Ekran görüntüsü (kod repo DIŞINDA): `agy-tasks/done/014-aksesuarlar.png` — bir pet yeni 4 aksesuarla. Zor gelirse atla.

## Kurallar
- İNTERNETTEN HİÇBİR ŞEY İNDİRME. GDScript/tscn kurallarına uy. git commit/push YAPMA.
- Raporu iş bitmese de MUTLAKA yaz: `agy-tasks/done/014-yeni-aksesuarlar.report.md` (Türkçe).
