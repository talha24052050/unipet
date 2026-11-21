# 003 — Android Yerel Export Raporu

## Ne Yapıldı
1. **Export Template Kurulumu:**
   - `C:\Tools\downloads\godot-4.7.2-templates.tpz` zip arşivi kontrol edildi (boyut: 1.281.349.702 bayt).
   - Arşiv içerisindeki `templates/` klasörünün içeriği `%APPDATA%\Godot\export_templates\4.7.2.stable\` dizinine çıkarıldı.
   - Dizin içinde `version.txt` (içerik: `4.7.2.stable`) ve `android_debug.apk` (127.260.725 bayt) dahil 35 template dosyası doğrulandı.
   - `.tpz` dosyası silinmedi, `C:\Tools\downloads\` altında muhafaza edildi.

2. **Yerel Android Export:**
   - `C:/Tools/Godot/godot_console.exe --headless --path game --export-debug "Android" ../build/unipet-local.apk` komutu çalıştırıldı.
   - Export işlemi başarıyla tamamlandı. `apksigner` ile `debug.keystore` kullanılarak APK imzalandı ve doğrulandı.
   - Üretilen APK boyutu: **28.959.726 bayt** (~27.6 MB).
   - Export çıktısında herhangi bir hata veya uyarı oluşmadı.
   - Repo temizliğini korumak adına üretilen APK `C:\Tools\downloads\unipet-local.apk` konumuna taşındı ve geçici `build/` dizini temizlendi.

3. **ADB / Telefon Bağlantı Testi:**
   - `%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe devices` çalıştırıldı.
   - Çıktıda telefon bağlı değildi (`List of devices attached` boş). Talimat gereği cihaz kurulum ve logcat adımı atlandı.

4. **Dokümantasyon Güncellemesi:**
   - `docs/SETUP.md` dosyasının sonuna 5 adımlık "Telefona Godot'tan tek tıkla kurulum" bölümü eklendi.

5. **Testler:**
   - Mevcut tüm testler (`res://tests/run_tests.gd`) çalıştırıldı: 42 testin tamamı başarılı.

## Hangi Dosyalar
- `%APPDATA%\Godot\export_templates\4.7.2.stable\` (template'ler kuruldu)
- `C:\Tools\downloads\godot-4.7.2-templates.tpz` (okundu, silinmedi: 1.281.349.702 bayt)
- `C:\Tools\downloads\unipet-local.apk` (üretilen yerel APK: 28.959.726 bayt)
- `docs/SETUP.md` (kılavuz bölümü eklendi)
- `agy-tasks/done/003-android-yerel-export.report.md` (bu rapor)
*İzin verilen dosyalar dışında repo'da hiçbir dosyaya dokunulmadı.*

## Komut Çıktıları

### 1. Export Komutu Çıktısı
```
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org

[   0% ] first_scan_filesystem | Started Projenin ilk başlatılması (5 steps)
[   0% ] first_scan_filesystem | Dosya yapısı taranıyor...
[  16% ] first_scan_filesystem | Genel sınıf isimleri yükleniyor...
[  33% ] first_scan_filesystem | GDExtension'lar doğrulanıyor...
[  50% ] first_scan_filesystem | Otomatik yükleme betikleri oluşturuluyor...
[  66% ] first_scan_filesystem | Eklentiler başlatılıyor...
[  83% ] first_scan_filesystem | Dosya taraması başlatılıyor...
[ DONE ] first_scan_filesystem

[   0% ] export | Started Android için dışa aktarılıyor (105 steps)
0 param: --xr_mode_regular
1 param: --xr-mode
2 param: off
3 param: --fullscreen
4 param: --background_color
5 param: #000000
[   0% ] export | APK oluşturuluyor...
ADDING: classes.dex
...
ADDING: lib/arm64-v8a/libc++_shared.so
ADDING: lib/arm64-v8a/libgodot_android.so
Adding application metadata org.godotengine.rendering.method
Adding application metadata org.godotengine.editor.version
Adding feature android.hardware.vulkan.level
Adding feature android.hardware.vulkan.version
Adding permission android.permission.INTERNET
...
[   0% ] export | Dosyalar ekleniyor...
[  97% ] export | APK hizalanıyor ...
[  98% ] export | APK hata ayıklama sürümü imzalanıyor...
Signing binary using: 
C:\Users\talha\AppData\Local\Android\Sdk/build-tools/36.0.0/apksigner.bat sign --verbose --ks <REDACTED> --ks-pass pass:<REDACTED> --ks-key-alias <REDACTED> C:/Users/talha/Documents/unipet/build/unipet-local.apk
Signed

[  99% ] export | APK doğrulanıyor...
[ DONE ] export
```

### 2. ADB Cihaz Listesi
```
* daemon not running; starting now at tcp:5037
* daemon started successfully
List of devices attached

```
*(Telefon bağlı değildi)*

### 3. Git Status Çıktısı
```
On branch main
Your branch is up to date with 'origin/main'.

Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
  (use "git restore <file>..." to discard changes in working directory)
	modified:   docs/SETUP.md

Untracked files:
  (use "git add <file>..." to include in what will be committed)
	agy-tasks/done/003-android-yerel-export.report.md

no changes added to commit (use "git add" and/or "git commit -a")
```

### 4. Proje Birim Testleri
```
  ok   test_auth.gd::test_parse_session_ok
  ok   test_auth.gd::test_parse_session_rejects_incomplete
  ok   test_auth.gd::test_error_messages_turkish
  ok   test_auth.gd::test_unconfigured_service_fails_gracefully
  ok   test_controls.gd::test_value_deadzone
  ok   test_controls.gd::test_value_clamped_full
  ok   test_controls.gd::test_value_half
  ok   test_controls.gd::test_multitouch_ownership
  ok   test_controls.gd::test_screen_to_world_camera_yaw
  ok   test_controls.gd::test_tap_vs_drag
  ok   test_controls.gd::test_direction_to_ignores_height
  ok   test_controls.gd::test_camera_pitch_clamped
  ok   test_controls.gd::test_camera_pinch_zoom
  ok   test_core.gd::test_email_domain_allowed
  ok   test_core.gd::test_email_domain_rejected
  ok   test_core.gd::test_chat_message_roundtrip
  ok   test_core.gd::test_free_text_trimmed
  ok   test_core.gd::test_character_def_validation
  ok   test_core.gd::test_local_profile_roundtrip
  ok   test_greybox.gd::test_data_loads
  ok   test_greybox.gd::test_all_buildings_triangulate
  ok   test_greybox.gd::test_spawn_not_inside_building
  ok   test_greybox.gd::test_extrude_faces_outward
  ok   test_pet_select.gd::test_scene_loads
  ok   test_pet_select.gd::test_pet_navigation_updates_profile
  ok   test_pet_select.gd::test_accessory_cycling_updates_profile
  ok   test_pet_select.gd::test_profile_persistence
  ok   test_pet_select.gd::test_button_heights_and_font_sizes
  ok   test_pet_visual.gd::test_locomotion_selection
  ok   test_pet_visual.gd::test_visual_plays_logical_animations
  ok   test_pet_visual.gd::test_footprint_reasonable
  ok   test_pet_visual.gd::test_accessories_load_and_equip_on_all_pets
  ok   test_pet_visual.gd::test_accessories_survive_pet_change
  ok   test_pet_visual.gd::test_hat_sits_on_head_top
  ok   test_pets.gd::test_pet_models_have_core_animations
  ok   test_pets.gd::test_registry_loads_all_pets
  ok   test_pets.gd::test_defs_match_models
  ok   test_player.gd::test_gravity_when_airborne
  ok   test_player.gd::test_no_fall_on_floor
  ok   test_player.gd::test_reaches_walk_speed
  ok   test_player.gd::test_diagonal_not_faster
  ok   test_player.gd::test_stops_without_input

42 geçti, 0 başarısız
```

## Belirsiz Kalanlar
- Bilgisayara o anda USB ile bağlı bir fiziksel Android cihaz bulunmadığı için APK'nın cihaza yüklenmesi ve logcat çıktısının alınması adımı çalıştırılamadı. Ancak yerel export template'leri, Godot Android SDK / Java / Keystore yapılandırması ve APK oluşturma/imzalama hattı eksiksiz şekilde doğrulanmıştır. Cihaz bağlandığında Godot içerisinden tek tıkla doğrudan telefona dağıtım yapılabilir haldedir.
