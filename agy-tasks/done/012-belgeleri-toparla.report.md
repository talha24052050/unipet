# 012 — Belgeleri güncelle ve toparla Raporu

**Tarih:** 2026-11-22 03:53  
**Görev:** `agy-tasks/inbox/012-belgeleri-toparla.md`  
**Durum:** Tamamlandı  

---

## 1. Ne Yapıldı?

1. **`docs/ARCHITECTURE.md`:**
   - Klasör ağacı gerçek yapıyla tam olarak senkronize edildi:
     - `game/src/` altındaki 8 klasör (`auth`, `care`, `characters`, `core`, `net`, `player`, `ui`, `world`) ve tek satırlık açıklamaları.
     - `tools/` altı (`agy-runner`, `assets`, `ci`, `e2e`, `nav`, `osm`, `deploy-phone.ps1`) ve açıklamaları.
     - `server/` altı (`nakama/modules`, `nakama/test`, `supabase`, `deploy`, `local-nakama.ps1`, `play-with-friends.ps1`) ve açıklamaları.
   - Yeni bölümler eklendi (kısa, öz ve doğru):
     - **Bölgeler:** 7 bölge (`game/data/zones/zones.json`, `ZoneCatalog`), `Services.current_zone`, bölgeye duyarlı builder'lar, önceden pişirilen `.navmesh.res` ve sha256 hash denetimi.
     - **Pet bakımı:** Açlık, mutluluk ve enerji kuralları, saatlik düşüş, sunucu yetkisi (Nakama storage), `OP_CARE` eylemleri ve bekleme süreleri/yemek mekan kısıtları.
     - **Ağ protokolü:** `server/nakama/modules/index.js` kaynaklı Opcode tablosu (1: `OP_STATE`, 2: `OP_CHAT`, 3: `OP_SNAPSHOT`, 4: `OP_PROFILE`, 5: `OP_CARE`) yönleri ve veri alanları.
     - **Yayın ve geliştirme ayrımı:** `Config.IS_RELEASE` bayrağı, mock/offline (`000` hızlı geliştirici girişi) ile Supabase OTP / Nakama JWT yayın akışı farkları.
     - **Testler:** `game/tests/run_tests.gd` hata sayacı ve çıkış kodu mantığı, birim testler, Nakama modül testi, `tools/e2e/nakama_two_players.gd` uçtan uca testi ve GitHub Actions CI işleri.

2. **`docs/DURUM.md`:**
   - Son güncelleme tarihi 2026-11-22 03:50 olarak güncellendi.
   - Çalışan sistemler tablosu son 40 commit incelenerek güncellendi (009 bakım ekranı ve HUD, 010 resmi haritadaki 38 yer ve `places.json`, 011 kampüs görsel stili/kiremit çatı/pencere shader'ı, harita ekranı renkli yer adları ve ana sahne Harita butonu, cihaz saatine bağlı gece-gündüz döngüsü, 15 m/s hız/ışınlanma koruması, takma ad küfür filtresi, CI üzerinde iki oyunculu E2E testi, USB ile tek tıkla telefon kurulumu `tools/deploy-phone.ps1`, Docker'sız yerel Nakama `server/local-nakama.ps1`).
   - "Agy'de" bölümü güncellendi: 009, 010, 011 bitti; 012 bu görev; 013 kampüs gece lambaları inbox'ta bekliyor.

3. **`docs/SETUP.md`:**
   - `tools/deploy-phone.ps1` ile telefona USB üzerinden tek komutla Android debug APK'sı derleyip kurma ve açma bölümü eklendi (`-Shot` ve `-LogSeconds` parametreleri açıklandı).
   - `server/local-nakama.ps1` ile Docker gerektirmeden yerel Nakama ve PostgreSQL çalıştırma, portlar (5433, 7350, 7351) ve başlatma/durdurma komutları eklendi.

4. **`README.md`:**
   - Oyunun ne olduğu 3-4 cümleyle net ve kısa şekilde ifade edildi.
   - "Nasıl denenir" bölümüne güncel GitHub Actions Android debug APK bağlantısı ve `000` hızlı geliştirme girişi talimatları konuldu.
   - Dokümantasyon rehber bağlantıları düzenlendi.

5. **`agy-tasks/README.md`:**
   - Runner'ın (`tools/agy-runner/agy-runner.ps1`) çalışma mantığı açıklandı:
     - Görev dosyasındaki `## Dokunabileceğin dosyalar` bölümündeki satırlardan tüm backtick içi dosya yollarının (`Get-AllowedPaths`) toplandığı,
     - Sadece izin verilen dosyaların ve görev çıktılarının commit edildiği, geliştiricinin diğer dosyalarına dokunulmadığı,
     - Görev tamamlansa da, yarım kalsa da veya zaman aşımına uğrasa da rapor dosyasının her durumda zorunlu olduğu belirtildi.

---

## 2. Değiştirilen Dosyalar

Sadece görevde izin verilen 6 dosya değiştirildi/oluşturuldu:
- `docs/ARCHITECTURE.md`
- `docs/DURUM.md`
- `docs/SETUP.md`
- `README.md`
- `agy-tasks/README.md`
- `agy-tasks/done/012-belgeleri-toparla.report.md` (bu rapor)

Hiçbir kod dosyasına dokunulmadı. `git commit` veya `git push` yapılmadı.

---

## 3. Test Sonuçları

1. **Nakama Sunucu Modülü Testleri:**
   ```powershell
   node server/nakama/test/module.test.js
   ```
   **Sonuç:** `nakama modül testleri: OK` (0 hata)

2. **Godot Test Koşucusu:**
   ```powershell
   godot_console.exe --headless --path game -s res://tests/run_tests.gd
   ```
   **Sonuç:** `117 geçti, 0 başarısız` (çıkış kodu 0)

---

## 4. Belgelerdeki Dosya Yolları Kontrol Listesi

Belgelerde adı geçen repo içi dosya ve klasör yollarının tümü doğrulanmıştır:

| Yol | Durum |
|---|---|
| `game/src/auth` | Mevcut |
| `game/src/care` | Mevcut |
| `game/src/characters` | Mevcut |
| `game/src/core` | Mevcut |
| `game/src/net` | Mevcut |
| `game/src/player` | Mevcut |
| `game/src/ui` | Mevcut |
| `game/src/world` | Mevcut |
| `game/src/care/pet_care_rules.gd` | Mevcut |
| `game/src/core/config.gd` | Mevcut |
| `game/src/core/services.gd` | Mevcut |
| `game/data/zones/zones.json` | Mevcut |
| `game/data/zones/ortabahce.navmesh.res` | Mevcut |
| `game/data/care_spots.json` | Mevcut |
| `game/data/places.json` | Mevcut |
| `game/tests/run_tests.gd` | Mevcut |
| `tools/agy-runner/agy-runner.ps1` | Mevcut |
| `tools/assets/make_pet_defs.py` | Mevcut |
| `tools/ci/export_presets.cfg` | Mevcut |
| `tools/e2e/nakama_two_players.gd` | Mevcut |
| `tools/nav/bake_zone_navmeshes.gd` | Mevcut |
| `tools/deploy-phone.ps1` | Mevcut |
| `server/nakama/modules/index.js` | Mevcut |
| `server/nakama/test/module.test.js` | Mevcut |
| `server/supabase/001_schema.sql` | Mevcut |
| `server/deploy/setup-vps.sh` | Mevcut |
| `server/deploy/Caddyfile` | Mevcut |
| `server/deploy/docker-compose.prod.yml` | Mevcut |
| `server/local-nakama.ps1` | Mevcut |
| `server/play-with-friends.ps1` | Mevcut |
| `docs/ARCHITECTURE.md` | Mevcut |
| `docs/DURUM.md` | Mevcut |
| `docs/SETUP.md` | Mevcut |
| `docs/ROADMAP.md` | Mevcut |
| `docs/DECISIONS.md` | Mevcut |
| `docs/ARKADASLARLA_OYNA.md` | Mevcut |
| `docs/RELEASE.md` | Mevcut |
| `docs/SUPABASE.md` | Mevcut |
| `agy-tasks/README.md` | Mevcut |
| `agy-tasks/inbox/012-belgeleri-toparla.md` | Mevcut |
| `agy-tasks/inbox/013-gece-lambalari.md` | Mevcut |

---

## 5. Belirsiz Kalanlar

Belirsiz veya eksik kalan hiçbir nokta yoktur. Tüm dokümantasyon, kod tabanının ve testlerin güncel durumuyla tam uyumlu hale getirilmiştir.
