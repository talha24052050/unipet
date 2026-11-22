# UniPet — güncel durum

Son güncelleme: 2026-11-22 06:40 (Antigravity). Ayrıntılı iş listesi: `docs/ROADMAP.md`, kararlar: `docs/DECISIONS.md`.

## Telefonda dene
APK (her push'ta otomatik): https://github.com/talha24052050/unipet/releases/download/android-debug/unipet-debug.apk

1. **Giriş:** mail alanına `000` → direkt giriş (geliştirme modu). Bir kez girince sonraki açılışlarda giriş ekranı atlanır.
   Normal yol: herhangi bir mail → kod `000000`. Takma ad ve sunucu adresi de burada.
2. **Pet seçimi:** 6 pet, 4 aksesuar slotu (kepi, gözlük, atkı, sırt çantası). Sol üst "Çıkış" → giriş ekranı.
3. **Oyun:** Ortabahçe (ağaçlar, banklar, lambalar; Kışla'da geçitler var, dışarı çıkılabilir).
   - Sol alt joystick, zemine dokun-yürü, tek parmak kamera döndür, iki parmak yakınlaştır.
   - Sağ alt sohbet: hazır cümleler + emote'lar (petin üstünde baloncuk). Sağ üst "Pet" → seçim ekranı.
   - Sağ üst "Harita" butonu → kampüs haritası (tür renkli yer adları) → yer adına dokunup ışınlanma ("buraya ışınlan?").
   - Üst kısımda bakım HUD'u: tokluk, mutluluk, enerji çubukları + Ye, Dinlen, Oyna butonları.
   - Cihaz saatine göre gerçekçi gece-gündüz döngüsü (altın saat, ay ışığı).
   - Boşta kalan pet arada kendi kendine dans eder/zıplar.

## Arkadaşlarla oyna
`docs/ARKADASLARLA_OYNA.md` — Docker gerekmez. `server/play-with-friends.ps1` (aynı Wi-Fi) ya da `-Internet` (Cloudflare tüneli).
Gerçek Nakama sunucusuna karşı iki oyunculu uçtan uca test hem yerelde hem CI'da çalışıyor (`tools/e2e/nakama_two_players.gd`).

## Çalışan sistemler (kod + test)
| Alan | Durum |
|---|---|
| Hareket, kamera, dokun-yürü, hazır yürüme haritası (tüm kampüs tek navmesh, 0.5 m hücre) ve haritadan ışınlanma | ✅ |
| 6 pet, animasyon, 4 aksesuar (yüzeye göre yerleşim, boşta emote) | ✅ |
| Giriş (geliştirme: sahte `000` ile tek tıkla şifresiz/kodsuz + oturum hatırlama; yayın: Supabase mail kodu) | ✅ kod — Supabase projesi Talha'da |
| Profil senkronu (Supabase `profiles`, RLS, girişte çekilir, pet seçiminde yazılır) | ✅ kod — Supabase bekliyor |
| Çok oyunculu: oda eşleştirme, durum/profil/isim/chat, uzak oyuncular, interpolasyon | ✅ |
| Sunucu güvenliği: oturum doğrulama, hız/ışınlanma koruması (15 m/s), takma ad küfür filtresi, chat hız sınırı, serbest chat kapalı | ✅ |
| Pet bakımı: tokluk/mutluluk/enerji kuralları, saatlik düşüş, sunucu saklama, bakım HUD çubukları ve Ye/Dinlen/Oyna butonları (009) | ✅ |
| Kampüs: Tek bölge (tüm kampüs: 140 bina, 141 alan, 309 yol), OSM yerleşimi, 38 resmi yer (`game/data/places.json`), kampüs görsel stili (kiremit çatı, pencere shader'ı, bina renkleri), haritadan ışınlanma | ✅ |
| Gece-gündüz döngüsü: Cihaz saatine göre dinamik güneş açısı, ışık rengi (altın saat, ay ışığı) ve gökyüzü renkleri | ✅ |
| Test ve CI: run_tests.gd hata sayacı, 117 birim test, Nakama modül testi, CI üzerinde gerçek Nakama ile E2E testi | ✅ |
| Dağıtım ve geliştirme araçları: USB ile telefona derleme/kurma (`tools/deploy-phone.ps1`), Docker'sız yerel Nakama (`server/local-nakama.ps1`), tek komut VPS kurulumu ve imzalı APK CI işi | ✅ |

## Agy'de (Antigravity)
- 009 bakım ekranı (çubuklar + Ye/Dinlen/Oyna) — tamamlandı
- 010 kampüs yer listesi (resmi haritadaki 38 yer) — tamamlandı
- 011 kampüs görsel stili (kiremit çatılar, pencere shader'ı, renkler) — tamamlandı
- 012 belgeleri toparla — tamamlandı
- 013 kampüs gece lambaları — tamamlandı
- 014 yeni aksesuarlar (10 yeni aksesuar) — tamamlandı
- 015 belgeleri tek bölgeye göre güncelle — tamamlandı (bu görev)
- 016 kampüs propları — kutuda bekliyor (`agy-tasks/inbox/016-kampus-proplari.md`)

## Talha'yı bekleyenler
1. **Telefonda deneme** + arkadaşlarla ilk oyun
2. **Supabase projesi** (`docs/SUPABASE.md`, ~10 dk) — gerçek mail girişi için
3. **VPS + imza anahtarı** (`docs/RELEASE.md`) — kalıcı sunucu ve dağıtılabilir sürüm için

## Bilinen eksikler / sıradakiler
- Simge binalar için özel low-poly modeller (5.2)
- Tüm kampüs prop yerleşimi (016)
- Gerçek kullanıcıyla performans ölçümü (telefon testi gerekli)
