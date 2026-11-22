# 018 — Ses efektleri (CC0, küçük paket)

## Amaç
Oyuna temel ses efektleri: buton, chat, emote, bakım eylemi, ayak sesi, ışınlanma. Sadece **CC0** ses kullan.
İnternet kısıtlı: toplam indirme **en fazla 15 MB**. Kaynak: Kenney (CC0) — ör. https://kenney.nl/assets/interface-sounds ,
https://kenney.nl/assets/impact-sounds (sayfadaki "Download" zip). Zip'leri `C:\Tools\downloads\` altına indir, repo'ya sadece
KULLANDIĞIN dosyaları `.ogg` olarak koy (toplam < 1.5 MB). Başka kaynak kullanma; bulamazsan rapora yaz.

## Dokunabileceğin dosyalar
- `game/assets/sfx/` (yeni klasör; sadece kullanılan .ogg dosyaları ve .import'ları)
- `game/src/core/sfx.gd` (yeni) — autoload `Sfx`
- `game/project.godot` — SADECE `[autoload]` bölümüne `Sfx="*res://src/core/sfx.gd"` eklemek için
- `game/src/ui/chat_menu.gd`
- `game/src/ui/care_hud.gd`
- `game/src/ui/campus_map.gd`
- `game/src/ui/pet_select.gd`
- `game/src/player/player.gd`
- `game/tests/test_sfx.gd` (yeni)
- `game/assets/CREDITS.md` — tek satır ekle
- `agy-tasks/done/018-sesler.report.md`
Başka dosyaya dokunma.

## Yapılacaklar
1. `sfx.gd` (Node, autoload): `play(name: StringName)` — isim → dosya sözlüğü (`const SOUNDS`), aynı anda en çok 6 ses (AudioStreamPlayer havuzu),
   ses düzeyi `var volume_db`, `var enabled: bool = true`. Bilinmeyen isim → sessizce geç (push_warning bir kez). Ses dosyası yoksa çökme.
   İsimler: `&"ui_click"`, `&"chat_send"`, `&"chat_receive"`, `&"emote"`, `&"care_ok"`, `&"care_fail"`, `&"teleport"`, `&"step"`.
2. Bağlantılar (her biri tek satır `Sfx.play(...)`):
   - pet_select / campus_map / care_hud / chat_menu butonları → `ui_click`
   - chat_menu: gönderince `chat_send`; başka birinin mesajı gelince `chat_receive` (yerel oyuncunun kendi mesajında değil)
   - care_hud: `care_updated` ok → `care_ok`, ok değil → `care_fail`
   - campus_map: ışınlanınca (`travel`) `teleport`
   - player.gd: yürürken yaklaşık her 0.38 sn'de bir `step` (hıza göre; dururken yok). Kodu küçük tut, tek fonksiyon.
3. `test_sfx.gd`: tüm isimlerin dosyası var ve yüklenebiliyor; bilinmeyen isim çökmez; havuz 6'yı aşmaz.
4. `CREDITS.md`: kullanılan Kenney paket(ler)i, CC0, kenney.nl.

## Kabul kriterleri
- [ ] `C:/Tools/Godot/godot --headless --path game --import` hatasız
- [ ] `C:/Tools/Godot/godot --headless --path game -s res://tests/run_tests.gd` exit 0, `SCRIPT ERROR` yok
- [ ] `C:/Tools/Godot/godot --headless --path game --quit-after 60` çıktısında `ERROR`/`SCRIPT ERROR` yok
- [ ] Repo'ya giren ses dosyalarının toplamı < 1.5 MB (rapora boyut listesi)

## Kurallar
- CLAUDE.md'ye uy. Sadece CC0. GDScript tipler açık. Testleri hileyle geçirme. git commit/push YAPMA.
- Raporu iş bitmese de MUTLAKA yaz: `agy-tasks/done/018-sesler.report.md` (indirme boyutları dahil).
