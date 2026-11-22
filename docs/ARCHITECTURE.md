# Mimari

```
unipet/
├─ game/                           Godot 4 projesi (res://)
│  ├─ src/
│  │  ├─ auth/                     Kimlik doğrulama arayüzü (AuthService) + Mock ve Supabase uygulamaları
│  │  ├─ care/                     Pet bakım kuralları (açlık/mutluluk/enerji, saatlik düşüş, eylemler)
│  │  ├─ characters/               Karakter ve aksesuar tanımları (.tres), kayıt kütükleri ve PetVisual
│  │  ├─ core/                     Autoload servisleri (Config, Services) ve yerel profil/ayarlar
│  │  ├─ net/                      Ağ arayüzü (NetworkService), Offline ve Nakama istemcileri, mesajlaşma ve senkronizasyon
│  │  ├─ player/                   Karakter kontrolü (joystick + dokun-yürü), kamera, yerel ve uzak oyuncular
│  │  ├─ ui/                       Kullanıcı arayüzü sahneleri (giriş, pet seçimi, harita, chat ve bakım HUD)
│  │  └─ world/                    Dünya inşası (GreyboxBuilder), bina stilleri, gece-gündüz, navmesh ve proplar
│  ├─ scenes/                      Oyun sahneleri (main.tscn, player.tscn, remote_player.tscn, ui/*.tscn)
│  ├─ data/                        Karakterler, aksesuarlar, sohbet şablonları ve kampüs verileri (zones/)
│  ├─ assets/                      Modeller (.glb), dokular, materyaller, ses ve arayüz ögeleri
│  └─ tests/                       Test runner (run_tests.gd) ve test_*.gd birim/entegrasyon testleri
├─ server/                         Nakama ve Supabase arka uç bileşenleri
│  ├─ nakama/modules/              Nakama JavaScript sunucu modülü (index.js: auth, eşleştirme, hareket, bakım)
│  ├─ nakama/test/                 Nakama sunucu mantığı testleri (module.test.js)
│  ├─ supabase/                    Supabase veritabanı şeması ve RLS kuralları (001_schema.sql)
│  ├─ deploy/                      VPS yayın dağıtım dosyaları (Caddyfile, docker-compose.prod.yml, setup-vps.sh)
│  ├─ local-nakama.ps1             Docker gerektirmeden yerel Nakama ve Postgres başlatan PowerShell scripti
│  └─ play-with-friends.ps1        Yerel Wi-Fi veya Cloudflare tüneliyle arkadaşlarla oynamayı sağlayan script
├─ tools/                          Geliştirme, üretim, test ve CI araçları
│  ├─ agy-runner/                  Antigravity görev kutusu çalıştırıcısı (agy-runner.ps1)
│  ├─ assets/                      Pet ve prop indirme/dönüştürme ve .tres üretme scriptleri
│  ├─ ci/                          CI ve ihracat yapılandırmaları (export_presets.cfg)
│  ├─ e2e/                         Gerçek Nakama sunucusuna karşı iki oyunculu uçtan uca test (nakama_two_players.gd)
│  ├─ nav/                         Kampüs navmesh'ini önceden pişiren araç (bake_zone_navmeshes.gd)
│  ├─ osm/                         OpenStreetMap verisinden binalar, yollar, proplar ve yer listesi üretimi
│  └─ deploy-phone.ps1             USB ile bağlı Android telefona derleyip kuran ve log/ekran görüntüsü alan script
├─ art/                            Referans materyalleri, harita verileri ve Blender scriptleri
├─ agy-tasks/                      Antigravity görev kutusu (inbox → done)
└─ docs/                           Mimari, durum, kurulum, yol haritası ve kararlar
```

## Kampüs (tek bölge)
Tüm kampüs tek bölge olarak modellenmiştir (`game/data/zones/zones.json` ve `ZoneCatalog` içinde `"kampus"` tanımı: 140 bina, 141 alan, 309 yol; doğuş noktası Ortabahçe). Tek hazır yürüme haritası (`game/data/zones/kampus_navmesh.res`, hücre 0.5 m, 7053 poligon, ~70 KB) kullanılır; sha256 kaynak özeti uyuşursa doğrudan yüklenir, uyuşmazsa `RuntimeNavRegion` arka planda ~2-3 saniyede yeniden pişirir (`tools/nav/bake_zone_navmeshes.gd` önceden pişirme aracıdır).

**Işınlanma akışı:**
Oyuncu harita ekranında (`CampusMap`) 38 resmî yer adından birine dokunup "Git" dediğinde odadan ayrılır (`Services.net.leave_zone()`). Hedef koordinat `Services.pending_teleport`'a atanarak ana oyun sahnesi (`main.tscn`) yeniden yüklenir. Oyuncu hedef koordinata yerleştirilir ve yer bina ortasına denk gelse bile navmesh hazır olduğunda `player.gd` (`_try_snap_to_navmesh`) tarafından yürünebilir en yakın noktaya oturtulur; ardından odaya yeniden bağlanılır.

## Pet bakımı
Pet bakım kuralları istemcide (`game/src/care/pet_care_rules.gd`) ve sunucuda (`server/nakama/modules/index.js`) birebir aynıdır; sunucu yetkilidir (durum Nakama storage'da saklanır, çevrimdışı modda yerelde hesaplanır). Açlık (food), mutluluk (joy) ve enerji (energy) değerleri 0-100 aralığındadır ve saatlik düşüşe tabidir (en fazla 12 saat). Oyuncu `OP_CARE` opcode'u ile eylem (`eat`, `rest`, `play`, `social`) gönderir; bekleme süreleri ve konum gereksinimleri (ör. yemek sadece Yemekhane, Hokka veya Kayıntı'da) sunucuda denetlenir.

## Ağ protokolü
Nakama yetkili maç odasında (`server/nakama/modules/index.js`) ikili JSON mesajları üzerinden çalışır:

| Opcode | İsim | Yön | Alanlar / Açıklama |
|---|---|---|---|
| 1 | `OP_STATE` | c→s<br>s→c | **c→s:** `{p: [x,y,z], y: yaw, a: anim}` — Hareket girişi (15 m/s hız/ışınlanma denetimi).<br>**s→c:** `{id, p, y, a}` — Odadaki diğer oyunculara konum ve animasyon yayını. |
| 2 | `OP_CHAT` | c→s<br>s→c | **c→s:** `{k: 0\|1\|2, p: payload}` — 0: Hazır cümle, 1: Emote, 2: Serbest metin.<br>**s→c:** `{s: senderId, k, p}` — Tüm odaya yayın; başkası varken konuşmak 'social' bakımını tetikler. |
| 3 | `OP_SNAPSHOT` | s→c | `{players: [{id, p, y, a, pet, acc, name}]}` — Yeni katılan oyuncuya mevcut odanın anlık durumu. |
| 4 | `OP_PROFILE` | c→s<br>s→c | **c→s:** `{pet, acc: {slot: id}, name}` — Pet, aksesuar ve takma ad.<br>**s→c:** `{id, pet, acc, name}` — Diğer oyunculara yayın (sunucu isimde küfür filtresi uygular). |
| 5 | `OP_CARE` | c→s<br>s→c | **c→s:** `{act}` — Bakım eylemi isteği (`eat`, `rest`, `play`).<br>**s→c:** `{ok, reason, state: {food, joy, energy, t}}` — Sadece ilgili oyuncuya güncel durum (girişte de yollanır). |

## Yayın ve geliştirme ayrımı
`Config.IS_RELEASE` bayrağı Godot ihraç özelliğine (`OS.has_feature("unipet_release")`) göre belirlenir.
- **Geliştirme (`IS_RELEASE = false`):** `MockAuthService` ("mock") kullanılır; e-posta kutusuna `000` yazılarak şifresiz/kodsuz hızlı giriş yapılır ve oturum yerelde hatırlanır. Ağ varsayılan olarak `OfflineNetworkService` ("offline", tek oyunculu) başlar; sunucu adresi verilirse `UNIPET_DEV_AUTH=true` olan yerel Nakama'ya bağlanır.
- **Yayın (`IS_RELEASE = true`):** `SupabaseAuthService` ("supabase") ile gerçek tek kullanımlık e-posta kodu (OTP) doğrulanır. Ağ servisi olarak `NakamaNetworkService` ("nakama") açılır ve Supabase oturum belirteci (JWT) sunucuya doğrulatılarak bağlanılır.

## Testler
- **Godot test koşucusu (`game/tests/run_tests.gd`):** Başsız (headless) modda `res://tests/test_*.gd` dosyalarını bulur ve çalıştırır. Assertion ve çalışma zamanı çökmelerini hata sayacında toplar; hata varsa 1, yoksa 0 koduyla çıkar.
- **Birim ve entegrasyon testleri:** `test_*.gd` dosyaları çekirdek sistemleri (auth, controls, core, net, pet, ui, greybox, building_style, campus_map, care, care_hud, places, props, zones, day_night) bağımsız test eder.
- **Nakama modül testleri (`server/nakama/test/module.test.js`):** Node.js ortamında bakım kurallarını, küfür filtresini, kampüs oda eşleşmelerini ve sunucu veri yapılarını doğrular.
- **Uçtan uca test (`tools/e2e/nakama_two_players.gd`):** Gerçek Nakama sunucusuna iki oyuncu bağlayarak eşleştirme, hareket senkronu, hız koruması, chat ve bakım akışını test eder.
- **Sürekli Entegrasyon (CI):** GitHub Actions üzerinde `.github/workflows/test.yml` (Godot birim testleri + Nakama modül testi + gerçek Nakama E2E), `.github/workflows/android.yml` (Android debug APK) ve `.github/workflows/release.yml` (imzalı yayın APK) otomatik koşar.

## Değiştirilebilirlik ilkeleri
1. **Servis katmanı:** `Services.net/auth/characters/accessories/zones`. Backend değişimi oyun kodunu etkilemez.
2. **Veri odaklı karakter:** model, animasyon adları, aksesuar kemikleri `.tres` içinde.
   Mantıksal animasyonlar (zorunlu): `idle, walk, run, emote_wave, emote_jump`; isteğe bağlı: `emote_yes, emote_no, emote_dance`.
   `animation_speed` ile hız çarpanı (ör. koşusu olmayan blob'larda run = 1.6× walk).
   `.tres`'ler elle değil `tools/assets/make_pet_defs.py` ile üretilir.
   Aksesuar slotları: `head, face, neck, back`. Aksesuarlar `game/data/accessories/*.tres` (AccessoryDef) →
   `Services.accessories`; PetVisual slot kemiğine BoneAttachment3D ile takar, yeri modelin yüzeyinden hesaplanır,
   pet başına ince ayar `make_pet_defs.py` → `accessory_offsets`.
3. **Tek mesaj formatı:** `ChatMessage{kind, payload, sender_id, t}`.
4. **Ağ durumu:** `{pos: Vector3, yaw: float, anim: String}`; saniyede `Config.NET_TICK_RATE` kez,
   karşı tarafta interpolasyon. Hareket girişi (joystick/dokun) yerel karakteri yürütür, ağ sadece sonucu taşır.
5. **Kampüs/oda:** Tek bölge (`kampus`) üzerinden sunucu `kampus-1`, `kampus-2` kanallarına dağıtır (oda kapasitesi: `Config.ROOM_CAPACITY = 40` oyuncu).
