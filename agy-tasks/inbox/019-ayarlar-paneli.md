# 019 — Ayarlar paneli (ses aç/kapa, ses düzeyi, FPS göstergesi)

## Amaç
Oyunda küçük bir "Ayarlar" paneli: ses efektleri aç/kapa, ses düzeyi kaydırıcısı. Ayarlar kalıcı (`user://settings.cfg`, mevcut LocalSettings).
İNTERNETTEN HİÇBİR ŞEY İNDİRME.

## Dokunabileceğin dosyalar
- `game/src/core/local_settings.gd` — yeni alanlar: `sfx_enabled: bool = true`, `sfx_volume_db: float = 0.0` (load/save'e ekle, eski dosyalar bozulmasın)
- `game/src/ui/settings_panel.gd` (yeni)
- `game/src/ui/settings_button.gd` (yeni)
- `game/scenes/main.tscn` — SADECE UI altına `SettingsButton` (Button) düğümü eklemek için; Harita butonunun (MapButton) hemen altına, aynı genişlikte
- `game/src/core/sfx.gd` — SADECE `_ready` içinde LocalSettings'ten `enabled`/`volume_db` okumak için
- `game/tests/test_settings_panel.gd` (yeni)
- `agy-tasks/done/019-ayarlar-paneli.report.md`
Başka dosyaya dokunma.

## Yapılacaklar
1. `settings_button.gd`: "Ayarlar" yazan buton; basınca paneli aç/kapa (panel kodla oluşturulabilir, ayrı .tscn şart değil). Basınca `Sfx.play(&"ui_click")`.
2. `settings_panel.gd` (PanelContainer): başlık "Ayarlar", `CheckButton` "Ses efektleri", `HSlider` "Ses düzeyi" (-30..6 dB, adım 1),
   "Kapat" butonu. Değişince anında `Sfx.enabled` / `Sfx.volume_db` güncellenir ve LocalSettings kaydedilir.
   Dokunmatik için büyük kontroller (min yükseklik 64 px, yazı 26+). Dikey 720x1280 ekranda ortada.
3. `sfx.gd` `_ready`: LocalSettings'ten ayarları yükle.
4. Test: LocalSettings yeni alanları kaydedip geri okuyor (geçici yol kullan, `user://test_settings.cfg`, sonra sil); eski (alanları olmayan) dosya
   varsayılanlara düşüyor; panel açılıp kapanıyor; checkbox `Sfx.enabled`'ı değiştiriyor (testten sonra eski değere geri al).

## Kabul kriterleri
- [ ] `C:/Tools/Godot/godot --headless --path game -s res://tests/run_tests.gd` exit 0, `SCRIPT ERROR` yok
- [ ] `C:/Tools/Godot/godot --headless --path game --quit-after 60` çıktısında `ERROR` yok
- [ ] Mevcut testlerin hiçbiri değiştirilmedi

## Kurallar
- CLAUDE.md'ye uy. GDScript tipler açık, sihirli sayılar `const`. Testleri hileyle geçirme. git commit/push YAPMA.
- Raporu iş bitmese de MUTLAKA yaz: `agy-tasks/done/019-ayarlar-paneli.report.md`.
