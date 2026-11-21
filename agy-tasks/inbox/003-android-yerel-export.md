# 003 — Android export'u bu bilgisayarda çalışır hale getir

## Amaç
Godot editöründen tek tıkla (One-click Deploy) telefona kurabilmek ve yerelde APK üretebilmek.
Android SDK (`%LOCALAPPDATA%\Android\Sdk`), Java ve debug keystore zaten kurulu ve Godot editör ayarlarında tanımlı.
Eksik olan sadece export template'leri: `C:\Tools\downloads\godot-4.7.2-templates.tpz` (indirildi, ~1.1 GB).

## Dokunabileceğin dosyalar
- `%APPDATA%\Godot\export_templates\4.7.2.stable\` (template kurulumu)
- `C:\Tools\downloads\` (geçici dosyalar; işin bitince .tpz'yi SİLME, rapora boyutunu yaz)
- `game/export_presets.cfg` (yerel, .gitignore'da; repo'daki `tools/ci/export_presets.cfg` kopyası zaten orada)
- `docs/SETUP.md` — sonuna "Telefona Godot'tan tek tıkla kurulum" bölümü ekle
- `agy-tasks/done/003-android-yerel-export.report.md`
Repo'daki başka hiçbir dosyaya dokunma.

## Yapılacaklar
1. `.tpz` bir zip'tir. İçindeki `templates/` klasörünün içeriğini `%APPDATA%\Godot\export_templates\4.7.2.stable\` altına çıkar
   (sonunda o klasörde `version.txt` ve `android_debug.apk` olmalı). Zip bozuksa/eksikse dur ve rapora yaz.
2. Yerel export dene:
   `C:/Tools/Godot/godot.exe --headless --path game --export-debug "Android" ../build/unipet-local.apk`
   (`build/` .gitignore'da değilse dosyayı repo'ya EKLEME — runner `git add -A` yapar; işin bitince `build/` klasörünü sil
   ya da APK'yı `C:\Tools\downloads\` altına taşı.) Çıkan APK boyutunu ve export çıktısındaki uyarıları rapora yaz.
3. `%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe devices` çalıştır. Telefon bağlı ve yetkiliyse:
   `adb install -r <apk>` ile kur ve `adb shell monkey -p io.github.talha24052050.unipet 1` ile başlat; 10 sn sonra
   `adb logcat -d -s godot:*` çıktısının son 50 satırını rapora koy. Telefon yoksa bu adımı atla, rapora "telefon bağlı değildi" yaz.
4. `docs/SETUP.md`'ye kısa bölüm: telefonu USB ile bağla, USB hata ayıklamayı onayla, Godot editöründe sağ üstteki
   Android ikonuna bas (Remote Debug ile çalışır). Türkçe, 5-8 satır.

## Kabul kriterleri
- [ ] `%APPDATA%\Godot\export_templates\4.7.2.stable\android_debug.apk` var
- [ ] Yerel export APK üretti (boyutu rapordа) ya da neden üretemediği hata çıktısıyla rapordа
- [ ] Repo'da `docs/SETUP.md` ve rapor dışında değişiklik yok (`git status` çıktısını rapora koy)

## Kurallar
- CLAUDE.md'ye uy. git commit/push YAPMA (runner yapar).
- Bitince raporu `agy-tasks/done/003-android-yerel-export.report.md`'ye Türkçe yaz: ne yaptın, komut çıktıları, belirsiz kalanlar.
