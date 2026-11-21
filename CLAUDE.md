# UniPet — Claude Code proje kuralları

YTÜ Davutpaşa kampüsünde geçen, mobil (önce Android), 3D, multiplayer, sosyal pet oyunu.
Ekip: Talha (karar verici, test eden) + Claude (geliştirme) + Antigravity/agy (lokal Windows işleri).

## Önce oku
- `docs/DECISIONS.md` — alınmış kararlar. Bunlara aykırı iş yapma; değişmesi gerekiyorsa Talha'ya sor.
- `docs/ROADMAP.md` — parçalar ve task'lar. Sıradaki işi buradan al, bitince işaretle.
- `docs/ARCHITECTURE.md` — klasör yapısı ve servis katmanı.

## Çalışma şekli (zorunlu)
1. Bir seferde **tek task**. Task bitince: test çalıştır → commit → push → Talha'ya kısa rapor.
2. Her **parçanın** sonunda dur ve Talha'nın onayını bekle (`checkpoint` skill'i).
3. Kararı Talha verir. Birden fazla makul seçenek varsa seçenekleri + önerini sun, kendin seçme.
4. Talha'yla Türkçe, kısa ve dürüst konuş. Gereksiz açıklama yok.
5. Talha'nın interneti kısıtlı: büyük indirmeleri (export template, Android SDK, büyük asset) ona yaptırma; mümkünse GitHub Actions'ta yap. Yapman gerekiyorsa önce boyutunu söyle.

## Kod kuralları
- Motor: **Godot 4.7**, dil: **GDScript**, tipler her yerde açık (`var x: int`, `-> void`).
- Godot projesi `game/` altında. Sunucu kodu `server/`, Blender scriptleri `art/blender/`.
- Oyun kodu backend'leri **asla** doğrudan kullanmaz: `Services.net`, `Services.auth`, `Services.characters`.
  Yeni backend = yeni implementasyon dosyası + `Config` ve `services.gd`'de bir satır.
- Karakterler `data/characters/*.tres` (CharacterDef). Kodda model yolu/animasyon adı hardcode edilmez.
- Chat her zaman `ChatMessage` ile; `Kind.PRESET | EMOTE | FREE`. Serbest chat `Config.FREE_CHAT_ENABLED` arkasında.
- Gizli anahtarlar repo'ya girmez (`.gitignore`'da `secrets.cfg`, `.env`).
- Mobil önce: `mobile` renderer, düşük poly, dokunmatik kontroller, dikey ekran.
- iOS'a geçişi bozacak Android'e özel kod yazma; gerekiyorsa `OS.get_name()` arkasına al.

## Komutlar
```bash
# testler (CI de aynısını çalıştırır)
godot --headless --path game --import
godot --headless --path game -s res://tests/run_tests.gd
```
Windows'ta `godot` yerine Godot exe yolunu kullan.

## Skill'ler
- `godot-dev` — sahne/script yazma, test, asset import kuralları
- `agy-delegate` — Antigravity'ye iş verme
- `checkpoint` — task/parça bitiş prosedürü
