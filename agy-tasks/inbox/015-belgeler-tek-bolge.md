# 015 — Belgeleri tek bölgeye göre güncelle (kod DEĞİŞMEZ)

## Amaç
Talha kararı (2026-11-22): bölge yok, **tüm kampüs tek bölge**; haritadan bir yere dokununca **ışınlanılır**.
Kod buna geçti (commit `fe67dd5`); belgeler hâlâ 7 bölgeyi anlatıyor. Koddan doğrulayarak düzelt.

## Dokunabileceğin dosyalar
- `docs/ARCHITECTURE.md`
- `docs/DURUM.md`
- `docs/ARKADASLARLA_OYNA.md`
- `README.md`
- `agy-tasks/done/015-belgeler-tek-bolge.report.md`

## Yapılacaklar
1. Kaynak: `game/data/zones/zones.json` (tek "kampus"), `game/src/ui/campus_map.gd` (yer adına dokun → `Services.pending_teleport`),
   `game/src/player/player.gd` (`_try_snap_to_navmesh`), `game/src/world/runtime_nav_region.gd` + `tools/nav/bake_zone_navmeshes.gd`
   (tek `kampus_navmesh.res`, hücre 0.5 m, büyük harita arka planda ~2-3 sn'de hazır), `server/nakama/modules/index.js` (`ZONES = ["kampus"]`).
2. `ARCHITECTURE.md`: "Bölgeler" bölümünü "Kampüs (tek bölge)" olarak yeniden yaz; ışınlanma akışını 3-4 satırla anlat.
3. `DURUM.md`: tabloda 7 bölge yerine tek kampüs + ışınlanma; "Son güncelleme" tarihi; agy listesinde 012-014 tamam, 015-016.
4. `ARKADASLARLA_OYNA.md` ve `README.md`: bölge geçen yerleri düzelt (herkes aynı kampüste, oda 40 kişi).

## Kabul kriterleri
- [ ] Sadece yukarıdaki dosyalar değişti
- [ ] Belgelerde "7 bölge", "bölgeler arası" gibi eski ifade kalmadı (rapora `grep` çıktısı koy)

## Kurallar
- Türkçe, kısa, koddan doğrulanmış. İNTERNETTEN HİÇBİR ŞEY İNDİRME. git commit/push YAPMA.
- Raporu iş bitmese de MUTLAKA yaz: `agy-tasks/done/015-belgeler-tek-bolge.report.md`.
