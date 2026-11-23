# iOS Ön Hazırlık ve Derleme Rehberi

UniPet Godot 4.7 (`mobile` renderer + `etc2_astc`) kullandığı için oyun kodu iOS ile doğrudan uyumludur.

## Hazır olanlar
- **Safe Area (`game/src/ui/safe_area*.gd`):** iPhone çentiği / Dynamic Island ve alttaki Home Indicator için otomatik kenar boşluğu.
- **Yaşam döngüsü (`game/src/core/app_lifecycle.gd`):** Arka plana alınınca ses durdurma + joystick bırakma; geri dönünce anında ağ yeniden bağlanma + bakım güncelleme.
- **iOS İkon Seti (`game/assets/icons/ios/`):** Apple kurallarına uygun şeffaflıksız (RGB) PNG seti. İkon değişirse yenilemek için:
  ```bash
  python tools/assets/make_ios_icons.py
  ```
- **Export Preset (`tools/ci/export_presets.cfg` → `[preset.1]` "iOS"):** Bundle ID `io.github.talha24052050.unipet`, dikey kilit, `*.json, secrets.cfg` dahil, `export_project_only=true` (Xcode projesi üretir).

## Mac / Xcode ile ilk iPhone denemesi
1. Mac'te Godot 4.7.2 + iOS export template'lerini kur.
2. `cp tools/ci/export_presets.cfg game/export_presets.cfg`
3. Godot'tan (veya CLI ile) Xcode projesini üret:
   ```bash
   godot --headless --path game --import
   godot --headless --path game --export-debug "iOS" ../build/ios/UniPet.xcodeproj
   ```
4. `build/ios/UniPet.xcodeproj` dosyasını Xcode'da aç → **Signing & Capabilities** → kendi Apple ID / Team'ini seç → USB ile bağlı iPhone'a **Run**.

## TestFlight / App Store için gerekecekler
1. **Apple Developer Program** hesabı ($99/yıl) ve App Store Connect'te `io.github.talha24052050.unipet` uygulaması.
2. **HTTPS / ATS:** Yayın sunucusu (`NAKAMA_HOST`) ve Supabase zaten HTTPS/WSS kullanıyor (yerel geliştirme hariç `http://` kullanılmaz).
3. **Hesap silme:** App Store incelemesi öncesi Ayarlar paneline "Hesabımı sil" seçeneği + gizlilik politikası bağlantısı eklenecek.
4. **GitHub Actions (isteğe bağlı):** `macos-latest` runner üzerinde Xcode projesi / imzalı `.ipa` otomasyonu (sertifika + provisioning profile secret'ları ile).
