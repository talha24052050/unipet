# UniPet ⭐

YTÜ Davutpaşa kampüsünde geçen 3D, multiplayer, mobil pet oyunu. Godot 4.7 · Supabase · Nakama.

## Talha için kurulum (tek seferlik)

İndirme boyutları küçük tutuldu; Android export template'leri (~1 GB) **indirmen gerekmiyor**, APK'yı GitHub Actions üretecek.

1. **Godot 4.7.2 Standard** (~70 MB, kurulum yok, zip'ten açılıyor): https://godotengine.org/download/windows/
   Açtığın exe'yi `C:\Tools\Godot\godot.exe` gibi bir yere koy ve bu klasörü PATH'e ekle (ya da exe'yi `godot.exe` olarak yeniden adlandır).
2. Repo'yu klonla:
   ```powershell
   git clone https://github.com/talha24052050/unipet
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
Claude Code ile repo klasöründe çalış; kurallar `CLAUDE.md`, sıradaki iş `docs/ROADMAP.md`.
