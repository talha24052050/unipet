# 002 — Pet Seçme ve Aksesuar Giydirme Ekranı Raporu

## Ne Yapıldı
- **Pet Seçim Ekranı (`pet_select.tscn` ve `pet_select.gd`):**
  - Dikey 720x1280 mobil çözünürlüğe uygun tam ekran arayüz oluşturuldu.
  - Üst yarıda `SubViewportContainer` ve `SubViewport` içinde izole bir 3D sahne kuruldu (`WorldEnvironment`, çift yönlü `DirectionalLight3D`, `Camera3D`, `PetPivot` ve `PetVisual`).
  - Petin kendi etrafında yavaşça dönmesi ve ekran üzerinden parmak/fare ile yatay sürükleyerek 360 derece döndürülebilmesi sağlandı.
  - Pet seçimi için sol/sağ ok butonları ve pet adı etiketi eklendi. Pet değiştiğinde `PetVisual.set_character` çağrılıp `play_emote(&"emote_wave")` animasyonu tetiklenmektedir.
  - 4 aksesuar slotu (Kafa, Yüz, Boyun, Sırt) için slot adı, mevcut aksesuar adı ve "Değiştir" butonundan oluşan satırlar eklendi. Butona her basıldığında slottaki aksesuarlar ve "Yok" seçeneği arasında anlık önizlemeyle geçiş yapılmaktadır.
  - "Başla" butonu ile yapılan seçim `LocalProfile` içine yazılıp `save()` çağrılmakta ve `res://scenes/main.tscn` sahnesi yüklenmektedir.
  - Açılışta `LocalProfile.load_or_default()` ile kayıtlı profil ekrana yüklenmektedir.
  - Mobil gereksinimlere uygun olarak tüm butonlar en az 96 px yüksekliğinde (`custom_minimum_size.y >= 96`), tüm yazılar font boyutu en az 28 (`font_size >= 28`) olarak tasarlandı.
- **Ana Sahne Güncellemesi (`main.tscn`):**
  - `UI` CanvasLayer altına sağ üst köşede küçük bir "Pet" butonu eklendi (`mouse_filter = STOP` ile dokunuşu oyuna geçirmeden `pet_select.tscn` sahnesine dönmektedir).
- **Proje Başlangıç Sahnesi (`project.godot`):**
  - `run/main_scene` satırı `"res://scenes/ui/pet_select.tscn"` olarak güncellendi.
- **Birim Testler (`test_pet_select.gd`):**
  - Sahne yükleme ve bileşen kontrolü (`test_scene_loads`),
  - Pet değiştirme fonksiyonlarının profili güncellemesi ve sarması (`test_pet_navigation_updates_profile`),
  - Aksesuar döndürme fonksiyonunun profili ve slot durumunu güncellemesi (`test_accessory_cycling_updates_profile`),
  - Profil kaydetme ve diskten geri yükleme doğrulama (`test_profile_persistence`),
  - Mobil buton boyutları ve font boyutlarının standartlara uygunluğunun tespiti (`test_button_heights_and_font_sizes`) testleri yazıldı.
- **Görsel Kabul Kriteri (`002-pet-secim.png`):**
  - Sahne oyun penceresinde açılarak 4 aksesuarın (Kep, Gözlük, Atkı, Sırt çantası) takılı olduğu durumun ekran görüntüsü alındı ve `agy-tasks/done/002-pet-secim.png` olarak kaydedildi.

## Hangi Dosyalar
- `game/scenes/ui/pet_select.tscn` (yeni)
- `game/src/ui/pet_select.gd` (yeni)
- `game/tests/test_pet_select.gd` (yeni)
- `game/scenes/main.tscn` (yalnızca UI CanvasLayer altına "Pet" butonu eklendi)
- `game/project.godot` (yalnızca `run/main_scene` satırı güncellendi)
- `agy-tasks/done/002-pet-secim.png` (kabul kriteri ekran görüntüsü)
- `agy-tasks/done/002-pet-secim-ekrani.report.md` (bu rapor)
*İzin verilen dosyalar dışında hiçbir dosyaya (`pet_visual.gd`, `player.gd`, `local_profile.gd`, `config.gd`, `.tres` vb.) dokunulmadı.*

## Test Sonucu
- `C:/Tools/Godot/godot --headless --path game --import` -> Hatasız tamamlandı (exit 0).
- `C:/Tools/Godot/godot --headless --path game -s res://tests/run_tests.gd` -> **38 geçti, 0 başarısız** (Mevcut 33 test + 5 yeni test, exit 0).
- `C:/Tools/Godot/godot --headless --path game --quit-after 60` -> Çıktıda hiçbir `ERROR` veya `SCRIPT ERROR` yok (exit 0).
- `agy-tasks/done/002-pet-secim.png` oluşturuldu ve görsel olarak doğrulandı.

## Belirsiz Kalanlar
- Herhangi bir belirsizlik veya çözülmemiş sorun bulunmamaktadır. Görevdeki tüm kriterler eksiksiz tamamlanmıştır.
