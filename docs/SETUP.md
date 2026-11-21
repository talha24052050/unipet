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
3. Godot'u aç → **Import** → `unipet/game/project.godot` → çalıştır (F5). Gri bir zemin ve "UniPet — Parça 0 iskeleti" yazısı görmelisin.
4. **Antigravity testi** (agy'ye bir kez giriş yapmış olmalısın): repo klasöründe
   ```powershell
   powershell -ExecutionPolicy Bypass -File tools/agy-runner/agy-runner.ps1
   ```
   Yeni bir pencerede agy açılıp `agy-tasks/inbox/001-kurulum-testi.md` görevini yapmalı, sonra runner sonucu commit'leyip push'lamalı.
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
