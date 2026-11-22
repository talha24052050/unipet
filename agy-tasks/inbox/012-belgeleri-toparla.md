# 012 — Belgeleri güncelle ve toparla (kod DEĞİŞMEZ)

## Amaç
Son iki günde çok şey eklendi; belgeler geride kaldı. Kodu okuyarak belgeleri gerçeğe uydur. Kod dosyalarına dokunma.

## Dokunabileceğin dosyalar
- `docs/ARCHITECTURE.md`
- `docs/DURUM.md`
- `docs/SETUP.md`
- `README.md`
- `agy-tasks/README.md`
- `agy-tasks/done/012-belgeleri-toparla.report.md`

## Yapılacaklar
1. `docs/ARCHITECTURE.md`: klasör ağacını gerçek duruma getir (`game/src/` altındaki tüm klasörler: auth, care, characters, core, net, player, ui, world;
   `tools/` altı: agy-runner, assets, ci, e2e, nav, osm, deploy-phone.ps1; `server/` altı: nakama/modules, nakama/test, supabase, deploy,
   local-nakama.ps1, play-with-friends.ps1). Her biri için tek satır açıklama. Yeni bölümler (kısa, 3-6 satır): **Bölgeler** (zones.json,
   ZoneCatalog, Services.current_zone, greybox/props/navmesh bölgeye göre; hazır navmesh ve kaynak özeti), **Pet bakımı** (kurallar iki
   tarafta aynı, sunucu yetkili, OP_CARE), **Ağ protokolü** (opcode tablosu: 1 STATE, 2 CHAT, 3 SNAPSHOT, 4 PROFILE, 5 CARE — yön ve alanlar;
   kaynak `server/nakama/modules/index.js`), **Yayın/geliştirme ayrımı** (`Config.IS_RELEASE`, mock/offline vs supabase/nakama),
   **Testler** (run_tests.gd hata sayacı, test_*.gd, node modül testi, e2e, CI işleri).
2. `docs/DURUM.md`: "Son güncelleme" tarihini ve tabloyu son commit'lere göre güncelle (`git log --oneline -40`); 009 bakım ekranı,
   010 yer listesi, 011 kampüs stili, harita ekranı yer adları, gece-gündüz, hız koruması/isim filtresi, CI e2e, deploy-phone.ps1 eklendi.
   "Agy'de" bölümünü boşalt ya da kalan görevleri yaz.
3. `docs/SETUP.md`: telefona USB ile kurulum için `tools/deploy-phone.ps1` (parametreler: `-Shot`, `-LogSeconds`) bölümü; Docker'sız yerel
   sunucu (`server/local-nakama.ps1`) bölümü.
4. `README.md`: oyunun ne olduğu (3-4 cümle) + "Nasıl denenir" (APK linki: https://github.com/talha24052050/unipet/releases/download/android-debug/unipet-debug.apk,
   giriş için `000`) + belgelere bağlantılar. Uzun tutma.
5. `agy-tasks/README.md`: runner'ın artık sadece görevde izin verilen dosyaları commit'lediğini, satırdaki tüm `yol`ların alındığını,
   raporun her durumda yazılması gerektiğini ekle.

## Kabul kriterleri
- [ ] Sadece yukarıdaki dosyalar değişti (`git status`)
- [ ] Belgelerdeki her dosya yolu gerçekten var (rapora kontrol listesi koy)

## Kurallar
- Türkçe, kısa ve doğru. Emin olmadığın şeyi yazma; koddan doğrula.
- git commit/push YAPMA. Raporu iş bitmese de MUTLAKA yaz: `agy-tasks/done/012-belgeleri-toparla.report.md`.
