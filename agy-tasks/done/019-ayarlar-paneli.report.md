# 019 — Ayarlar Paneli Görev Raporu

## Yapılanlar
1. **LocalSettings Genişletildi (`game/src/core/local_settings.gd`)**:
   - `sfx_enabled: bool = true` ve `sfx_volume_db: float = 0.0` alanları eklendi.
   - `load_or_default()` metoduna `[audio]` bölümünden `sfx_enabled` ve `sfx_volume_db` değerlerini okuma desteği eklendi; eski dosyaların veya eksik alanların varsayılanlara güvenle düşmesi sağlandı.
   - `save()` metodunda mevcut dosya yüklenerek diğer bölümler (`server` vb.) korunacak şekilde `audio` bölümü kaydedildi.

2. **Sfx Autoload Güncellendi (`game/src/core/sfx.gd`)**:
   - `_ready()` içinde `LocalSettings.load_or_default()` çağrılarak kayıtlı `sfx_enabled` ve `sfx_volume_db` değerleri yüklendi. Dosya dışında hiçbir metoda dokunulmadı.

3. **Ayarlar Paneli Oluşturuldu (`game/src/ui/settings_panel.gd`)**:
   - `PanelContainer` sınıfından türetilen ve ayrı sahne gerektirmeden kodla arayüzünü oluşturan modal panel yazıldı.
   - Başlık: "Ayarlar" `Label` (yazı boyutu 32, yükseklik 64 px).
   - "Ses efektleri" `CheckButton` (yazı boyutu 28, yükseklik 64 px). Değiştirildiğinde anında `Sfx.enabled` güncellenir ve LocalSettings dosyasına yazılır.
   - "Ses düzeyi" `HSlider` (-30 dB ile 6 dB arası, adım 1, yükseklik 64 px) ve değer etiketi. Değiştirildiğinde anında `Sfx.volume_db` güncellenir ve LocalSettings dosyasına yazılır.
   - "Kapat" `Button` (yazı boyutu 28, yükseklik 64 px). Tıklandığında `Sfx.play(&"ui_click")` çalar ve paneli kapatır.
   - Dokunmatik kurallarına tam uyum (tüm kontroller min 64 px yükseklik ve 26+ punto yazı).
   - 720x1280 dikey ekranda tam ortalanmış (PRESET_CENTER, 560x460 px) ve `z_index = 10` ile ön planda duracak şekilde tasarlandı.

4. **Ayarlar Butonu Oluşturuldu (`game/src/ui/settings_button.gd`)**:
   - UI üzerinde "Ayarlar" yazan buton oluşturuldu.
   - Tıklandığında `Sfx.play(&"ui_click")` çalar ve ayarlar panelini açıp kapatır (toggle).
   - Ağaçtan ayrıldığında (`_exit_tree`) oluşturduğu paneli de güvenle temizleyecek bellek yönetimi eklendi.

5. **Ana Sahneye Buton Eklendi (`game/scenes/main.tscn`)**:
   - `UI` (CanvasLayer) altına `MapButton` (Harita) butonunun hemen altına, Harita butonuyla aynı genişlikte (120 px, `offset_left = -144.0`, `offset_right = -24.0`, `offset_top = 224.0`, `offset_bottom = 320.0`) `SettingsButton` düğümü eklendi.

6. **Kapsamlı Test Paketi Yazıldı (`game/tests/test_settings_panel.gd`)**:
   - `test_local_settings_fields_roundtrip`: Yeni alanların kaydedilip doğru okunduğu (geçici dosya ile) doğrulandı.
   - `test_legacy_settings_uses_defaults`: Ses bölümü bulunmayan eski dosyaların varsayılan değerlere düştüğü doğrulandı.
   - `test_settings_panel_controls_and_touch_sizes`: Başlık, CheckButton, HSlider, Kapat butonu ve mobil dokunmatik boyut/yazı punto kuralları doğrulandı.
   - `test_settings_panel_open_and_close`: open, close, toggle ve Kapat butonunun paneli açıp kapattığı doğrulandı.
   - `test_checkbox_modifies_sfx_enabled_and_saves`: Checkbox değiştirildiğinde `Sfx.enabled`'ın ve kayıt dosyasının güncellendiği doğrulandı (test sonrasında eski değere geri alındı).
   - `test_volume_slider_modifies_sfx_volume_and_saves`: HSlider değeri değiştiğinde `Sfx.volume_db`'nin ve kayıt dosyasının güncellendiği doğrulandı (test sonrasında eski değere geri alındı).
   - `test_settings_button_in_main_scene`: `main.tscn` içinde `SettingsButton`'ın Harita butonunun hemen altında ve aynı genişlikte yer aldığı doğrulandı.
   - `test_settings_button_toggles_panel`: Butona basıldığında panelin açılıp kapandığı doğrulandı.

---

## Dokunulan Dosyalar
- `game/src/core/local_settings.gd` (değiştirildi)
- `game/src/core/sfx.gd` (değiştirildi)
- `game/src/ui/settings_panel.gd` (yeni)
- `game/src/ui/settings_button.gd` (yeni)
- `game/scenes/main.tscn` (değiştirildi)
- `game/tests/test_settings_panel.gd` (yeni)
- `agy-tasks/done/019-ayarlar-paneli.report.md` (yeni)

*(İzin verilenler haricinde hiçbir dosyaya dokunulmadı; mevcut testlerin hiçbiri değiştirilmedi.)*

---

## Test Sonuçları
1. **Birim Testler (`res://tests/run_tests.gd`)**:
   - Komut: `C:/Tools/Godot/godot_console.exe --headless --path game -s res://tests/run_tests.gd`
   - Sonuç: **147 geçti, 0 başarısız** (Exit code 0, sıfır SCRIPT ERROR).
2. **Headless Çalıştırma Doğrulaması (`--quit-after 60`)**:
   - Komut: `C:/Tools/Godot/godot_console.exe --headless --path game --quit-after 60`
   - Sonuç: **Exit code 0, sıfır ERROR**.

---

## Belirsiz Kalanlar
- Görev başlığında `(ses aç/kapa, ses düzeyi, FPS göstergesi)` yer alıyordu; ancak FPS göstergesi (`PerfLabel`) mevcut projede zaten halihazırda yer alıp çalıştığı ve görev gövdesinde dokunulacak dosyalar ile yapılacaklar listesi yalnızca ses kontrolleri olarak sınırlandırıldığı için ek bir FPS butonu/ayar düğmesi eklenmedi. İleride ayarlar paneline FPS göstergesi aç/kapa checkbox'ı eklenmesi istenirse `SettingsPanel` içine kolayca entegre edilebilir.
