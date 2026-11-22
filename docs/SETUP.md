# Geliştirme ortamı kurulumu

## Klasör yapısı (önemli)

Her şey **tek klasörde**: repo'nun kendisi. Önerilen yer:

```
C:\Users\<kullanıcı>\Documents\unipet      <- repo kökü: Claude Code'u BURADA aç
├─ game\                                    <- Godot projesi: Godot'ta BUNU aç (project.godot)
├─ docs\, tools\, agy-tasks\, ...
```

- **Claude Code / Antigravity / git komutları:** repo kökünde (`...\Documents\unipet`).
- **Godot editörü:** `...\Documents\unipet\game\project.godot`.
- OneDrive senkronlu klasörlere koyma (Godot'un `.godot` önbelleğiyle sorun çıkarır).

## Kurulum (tek seferlik)

İndirme boyutları küçük tutuldu; Android export template'leri (~1 GB) **indirmen gerekmiyor**, APK'yı GitHub Actions üretecek.

1. **Godot 4.7.2 Standard** (~70 MB, kurulum yok, zip'ten açılıyor): https://godotengine.org/download/windows/
   Açtığın exe'yi `C:\Tools\Godot\godot.exe` gibi bir yere koy ve bu klasörü PATH'e ekle (ya da exe'yi `godot.exe` olarak yeniden adlandır).
2. Repo'yu klonla:
   ```powershell
   cd $HOME\Documents
   git clone https://github.com/talha24052050/unipet
   cd unipet
   ```
3. Godot'u aç → **Import** → `unipet/game/project.godot` → çalıştır (F5). Gri bir zemin ve oyunu görmelisin.
4. **Antigravity testi** (agy'ye bir kez giriş yapmış olmalısın): repo klasöründe
   ```powershell
   powershell -ExecutionPolicy Bypass -File tools/agy-runner/agy-runner.ps1
   ```
   Yeni bir pencerede agy açılıp görevleri yapmalı, sonra runner sonucu commit'leyip push'lamalı.
   Not: runner agy'yi `--dangerously-skip-permissions` ile çalıştırır (onay sormadan dosya düzenler/komut çalıştırır), sadece repo klasöründe.
   İstemezsen `-AgyArgs ""` ver; o zaman açılan pencerede onayları sen verirsin.

## Geliştirme
Claude Code ile repo kök klasöründe çalış; kurallar `CLAUDE.md`, sıradaki iş `docs/ROADMAP.md`.

## Telefona Godot'tan tek tıkla kurulum
1. Android telefonunu USB kablosuyla bilgisayara bağla.
2. Telefonda Geliştirici Seçenekleri'nden **USB hata ayıklama**yı aç ve ekrandaki bilgisayar yetki onayını kabul et.
3. Godot editöründe projeyi aç (`game/project.godot`).
4. Editörün sağ üst köşesinde (Oynat butonlarının yanında) beliren **Android simgesi**ne (One-click Deploy) tıkla.
5. Proje derlenip APK otomatik olarak telefona kurulur ve Remote Debug eşliğinde çalıştırılır.

## Telefona USB ile komut satırından kurulum (`tools/deploy-phone.ps1`)

Godot editörü açık olmadan, doğrudan PowerShell üzerinden bağlı Android telefona APK derleyip kurabilir ve açabilirsiniz:

1. Android telefonunuzu USB ile bilgisayara bağlayın ve **USB hata ayıklama**yı açıp bilgisayar yetkisini onaylayın.
2. Repo kök dizininde çalıştırın:
   ```powershell
   powershell -ExecutionPolicy Bypass -File tools/deploy-phone.ps1
   ```
   Script otomatik olarak Android debug APK'sını derler, `adb` ile cihaza yükler (telefonda GitHub sürümü varsa kaldırıp temiz kurar), uygulamayı başlatır ve konsola logcat loglarını basar.

**Parametreler:**
- `-LogSeconds <saniye>`: Uygulama açıldıktan sonra logcat izleme süresi (varsayılan: `10` sn).
  ```powershell
  powershell -ExecutionPolicy Bypass -File tools/deploy-phone.ps1 -LogSeconds 20
  ```
- `-Shot`: Uygulama açılıp log süresi dolduktan sonra telefon ekranının görüntüsünü alır ve `C:\Tools\downloads\phone.png` dosyasına kaydeder.
  ```powershell
  powershell -ExecutionPolicy Bypass -File tools/deploy-phone.ps1 -Shot
  ```

## Docker'sız yerel sunucu (`server/local-nakama.ps1`)

Çok oyunculu backend'i yerelde test etmek için Docker Desktop kurmanıza gerek yoktur. `server/local-nakama.ps1` scripti gerekli Nakama ve gömülü PostgreSQL ikililerini indirip `C:\Tools\nakama-local` klasörüne kurar ve yönetici izni gerektirmeden çalıştırır.

1. **Sunucuyu başlatmak için:**
   ```powershell
   powershell -ExecutionPolicy Bypass -File server/local-nakama.ps1
   ```
   İlk çalıştırmada Nakama (~15 MB) ve Postgres (~300 MB) indirilir, veritabanı hazırlanır ve göçler uygulanır.
   - Nakama API: `http://127.0.0.1:7350`
   - Nakama Web Konsolu: `http://127.0.0.1:7351` (Kullanıcı adı: `admin`, Şifre: `password`)
   - Postgres portu: `5433`

2. **Sunucuyu durdurmak için:**
   ```powershell
   powershell -ExecutionPolicy Bypass -File server/local-nakama.ps1 -Stop
   ```

3. **Oyundan bağlanmak için:**
   - Masaüstünde oynarken giriş ekranında sunucu adresine `127.0.0.1` yazmanız yeterlidir.
   - Aynı Wi-Fi ağındaki telefondan veya internet üzerinden arkadaşlarla oynamak için `server/play-with-friends.ps1` scripti kullanılır (`docs/ARKADASLARLA_OYNA.md`).
