# 002 — Pet seçme + aksesuar giydirme ekranı (ROADMAP 2.6)

## Amaç
Oyuncu oyuna girmeden önce 6 petten birini seçsin ve 4 slota (kafa, yüz, boyun, sırt) aksesuar taksın.
Seçim `LocalProfile` ile kaydedilir; ana sahnedeki oyuncu açılışta bu kaydı zaten uyguluyor
(`game/src/player/player.gd` → `apply_profile`). Senin işin sadece ekran ve akış.

## Dokunabileceğin dosyalar
- `game/scenes/ui/pet_select.tscn` (yeni)
- `game/src/ui/pet_select.gd` (yeni)
- `game/tests/test_pet_select.gd` (yeni)
- `game/scenes/main.tscn` — SADECE `UI` CanvasLayer altına bir "Pet" butonu eklemek için
- `game/project.godot` — SADECE `run/main_scene` satırı
- `agy-tasks/done/002-pet-secim-ekrani.report.md`
Bunların dışına dokunma. Özellikle `pet_visual.gd`, `player.gd`, `local_profile.gd`, `config.gd`, `.tres` dosyaları DEĞİŞMEYECEK.
Bir şey eksikse değiştirme, rapora yaz.

## Kullanacağın hazır API'ler (oku, değiştirme)
- `Services.characters.selectable() -> Array[CharacterDef]` — `def.id`, `def.display_name`
- `Services.accessories.for_slot(slot) -> Array[AccessoryDef]` — `acc.id`, `acc.display_name`; `Services.accessories.get_def(id)`
- `CharacterDef.ACCESSORY_SLOTS` = `["head", "face", "neck", "back"]`
- `res://src/characters/pet_visual.gd` (Node3D): `set_character(def)`, `equip(acc) -> bool`, `unequip(slot)`,
  `play_emote(&"emote_wave")` (pet seçilince bir kez oynat, sevimli dursun)
- `res://src/core/local_profile.gd`: `LocalProfile.load_or_default()`, alanlar `pet_id: StringName`,
  `accessories: Dictionary` (slot → aksesuar id), `save()`

## Yapılacaklar
1. `pet_select.tscn`: kök `Control` (tam ekran, dikey 720x1280 tasarım). Üst yarı: `SubViewportContainer` + `SubViewport`
   içinde kendi küçük 3D dünyası (ışık, düz renkli arka plan, kamera) ve bir `PetVisual`. Pet yavaşça kendi etrafında dönsün
   ya da parmakla sürükleyince dönsün (ikisinden biri yeter, sürükleme daha iyi).
2. Pet seçimi: petin adı + sol/sağ ok butonları (ya da yatay kaydırılan isim listesi). Değişince `PetVisual.set_character`.
3. Aksesuar: her slot için bir satır: slot adı (Türkçe: Kafa, Yüz, Boyun, Sırt) + aksesuar adı + değiştir butonu.
   Değiştir, o slottaki aksesuarlar ve "Yok" arasında döner. Önizlemede anında takılır/çıkar.
4. "Başla" butonu: `LocalProfile`'a yaz, `save()`, `get_tree().change_scene_to_file("res://scenes/main.tscn")`.
5. Açılışta mevcut kaydı (`load_or_default`) ekrana yükle (son seçim görünsün).
6. `project.godot` → `run/main_scene="res://scenes/ui/pet_select.tscn"`.
7. `main.tscn` → `UI` altına sağ üstte küçük "Pet" butonu: basınca `pet_select.tscn`'e dön.
   Bu buton dokunuşu oyuna (dokun-yürü/kamera) geçirmemeli (`mouse_filter = STOP`, normal Button bunu yapar).
8. Mobil: butonlar en az 96 px yüksek, yazılar okunur (font_size ≥ 28), parmakla rahat basılır. Tema/stil basit olsun.
9. Test (`test_pet_select.gd`, mevcut testlerin formatında: `test_*` fonksiyonu "" dönerse geçer):
   sahne yükleniyor; pet değiştirme ve aksesuar döndürme fonksiyonların `LocalProfile` alanlarını doğru dolduruyor
   (UI'ya basmadan, fonksiyonları doğrudan çağırarak). Gerekirse dosyaya yazmak için `user://test_*.cfg` kullan ve sil.

## Kabul kriterleri
- [ ] `C:/Tools/Godot/godot --headless --path game --import` hatasız
- [ ] `C:/Tools/Godot/godot --headless --path game -s res://tests/run_tests.gd` exit 0 (mevcut 33 test + seninkiler)
- [ ] `C:/Tools/Godot/godot --headless --path game --quit-after 60` çıktısında `ERROR`/`SCRIPT ERROR` yok
- [ ] Ekranı oyun penceresinde aç, bir ekran görüntüsü al ve `agy-tasks/done/002-pet-secim.png` olarak kaydet
      (pet + en az iki aksesuar takılı görünsün)

## Kurallar
- CLAUDE.md ve docs/DECISIONS.md'ye uy. GDScript, tipler her yerde açık (`var x: int`, `-> void`).
- Model yolu / animasyon adı hardcode etme; her şey `Services` ve `CharacterDef` üzerinden.
- Kullanıcıya görünen metinler Türkçe.
- git commit/push YAPMA (runner yapar).
- Bitince raporu `agy-tasks/done/002-pet-secim-ekrani.report.md`'ye Türkçe yaz: ne yaptın, hangi dosyalar,
  test sonucu, belirsiz kalanlar.
