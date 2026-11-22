# Kararlar

Talha'nın verdiği kararlar. Değişiklik = Talha'nın onayı + bu dosyaya tarihli satır.

## Ürün
| Konu | Karar | Tarih |
|---|---|---|
| Kapsam | Önce YTÜ Davutpaşa. Diğer üniversiteler sonra. | 2026-11-21 |
| Konsept | 3D sanal kampüs + pet + sosyal (İTÜPet benzeri). Fark: gerçek kampüs hayatına bağlanma, YTÜ-İTÜ rekabeti | 2026-11-21 |
| Ana figür | YTÜ yıldızından esinlenen **özgün** yıldız karakteri (başka oyunun karakterinin kopyası değil). Şimdilik Quaternius petleri | 2026-11-21 |
| Petler | MVP'de 3-5 seçilebilir pet (Quaternius Ultimate Monsters, CC0). Sonra genişler | 2026-11-21 |
| MVP pet listesi | 6 pet: Köpekbalığı, Mavi kuş (Birb), Mantar (Mushnub), Yeti, Ninja, Tavuk — `art/pets.json` (3-5 yerine 6) | 2026-11-21 |
| Aksesuar | Çekirdek özellik, baştan desteklenir | 2026-11-21 |
| Çekirdek döngü | Şimdilik temel bakım (açlık/mutluluk/enerji). Detaylar sonra | 2026-11-21 |
| Harita | Sadece bina **dışları**: tam Ortabahçe, tüm Davutpaşa fakülteleri, Büyükev, Hokka, fakülte kafeleri, yemekhane, büyük saha | 2026-11-21 |
| Hareket | Joystick **ve** dokun-yürü birlikte | 2026-11-21 |
| Kampüs içi hızlı ulaşım | Haritadan bir yere dokununca **ışınlanma** | 2026-11-22 |
| Chat | Başlangıç: hazır cümleler + emote. Serbest chat altyapısı hazır, sonra açılacak | 2026-11-21 |

## Teknik
| Konu | Karar | Tarih |
|---|---|---|
| Motor | Godot 4 (4.7.x), GDScript | 2026-11-21 |
| Platform | Önce Android. iOS'a kolay geçiş korunur | 2026-11-21 |
| Auth | Supabase Auth, mail + tek kullanımlık kod | 2026-11-21 |
| Okul maili | **Şimdilik zorunlu değil**: her geçerli mail girer. Altyapı hazır, tek ayarla açılır (`Config.REQUIRE_SCHOOL_EMAIL` + sunucu env + Supabase hook) | 2026-11-21 |
| Multiplayer | Nakama. Geliştirmede lokal Docker (ücretsiz), test için ücretsiz VPS. Ağ kodu arayüz arkasında | 2026-11-21 |
| Dünya | ~~Bölgeler (zone)~~ → **Tek bölge: tüm kampüs** (Talha, 2026-11-22). Kapasite dolunca yeni kanal (oda) kalır | 2026-11-22 |
| Geliştirme | Talha Claude Code ile devam ediyor. Lokal işler Antigravity CLI (`agy`) ile | 2026-11-21 |
| Repo | github.com/talha24052050/unipet — her task commit, her parça sonunda kontrol | 2026-11-21 |

## Claude'un varsayılanları (Talha değiştirebilir)
- Ekran: dikey (portrait). İTÜPet de dikey.
- Harita yerleşimi OpenStreetMap verisinden üretilir, binalar low-poly stilize.
