# UniPet — güncel durum

Son güncelleme: 2026-11-22 03:10 (Claude). Ayrıntılı iş listesi: `docs/ROADMAP.md`, kararlar: `docs/DECISIONS.md`.

## Telefonda dene
APK (her push'ta otomatik): https://github.com/talha24052050/unipet/releases/download/android-debug/unipet-debug.apk

1. **Giriş:** mail alanına `000` → direkt giriş (geliştirme modu). Bir kez girince sonraki açılışlarda giriş ekranı atlanır.
   Normal yol: herhangi bir mail → kod `000000`. Takma ad ve sunucu adresi de burada.
2. **Pet seçimi:** 6 pet, 4 aksesuar slotu (kepi, gözlük, atkı, sırt çantası). Sol üst "Çıkış" → giriş ekranı.
3. **Oyun:** Ortabahçe (ağaçlar, banklar, lambalar; Kışla'da geçitler var, dışarı çıkılabilir).
   Sol alt joystick, zemine dokun-yürü, tek parmak kamera döndür, iki parmak yakınlaştır.
   Sağ alt sohbet: hazır cümleler + emote'lar (petin üstünde baloncuk). Sağ üst "Pet" → seçim ekranı.
   Boşta kalan pet arada kendi kendine dans eder/zıplar.

## Arkadaşlarla oyna
`docs/ARKADASLARLA_OYNA.md` — Docker gerekmez. `server/play-with-friends.ps1` (aynı Wi-Fi) ya da `-Internet` (Cloudflare tüneli).
Gerçek Nakama sunucusuna karşı iki oyunculu uçtan uca test hem yerelde hem CI'da çalışıyor (`tools/e2e/nakama_two_players.gd`).

## Çalışan sistemler (kod + test)
| Alan | Durum |
|---|---|
| Hareket, kamera, dokun-yürü, hazır yürüme haritaları | ✅ |
| 6 pet, animasyon, 4 aksesuar (yüzeye göre yerleşim) | ✅ |
| Giriş (geliştirme: sahte; yayın: Supabase mail kodu) | ✅ kod — Supabase projesi Talha'da |
| Profil senkronu (Supabase `profiles`, RLS) | ✅ kod — Supabase bekliyor |
| Çok oyunculu: oda eşleştirme, durum/profil/isim/chat, uzak oyuncular | ✅ |
| Sunucu güvenliği: oturum doğrulama, hız koruması, isim küfür filtresi, chat hız sınırı, serbest chat kapalı | ✅ |
| Pet bakımı (tokluk/mutluluk/enerji, sunucuda) | ✅ mantık — ekranı agy 009'da |
| Kampüs: 7 bölge (krokiye göre), harita ekranı, bölge yükleme | ✅ — ana sahneye "Harita" butonu bekliyor |
| Yayın: tek komut VPS + imzalı APK (`v*` etiketi) | ✅ kod — adımlar `docs/RELEASE.md` |

## Agy'de (Antigravity)
- 009 bakım ekranı (çubuklar + Ye/Dinlen/Oyna) — çalışıyor
- 010 kampüs yer listesi (resmi haritadaki 38 yer)
- 011 kampüs görsel stili (kiremit çatılar, pencere shader'ı, renkler)

## Talha'yı bekleyenler
1. **Telefonda deneme** + arkadaşlarla ilk oyun
2. **Supabase projesi** (`docs/SUPABASE.md`, ~10 dk) — gerçek mail girişi için
3. **VPS + imza anahtarı** (`docs/RELEASE.md`) — kalıcı sunucu ve dağıtılabilir sürüm için

## Bilinen eksikler / sıradakiler
- Bölgeler arası geçiş sadece harita ekranından (yürüyerek sınırdan geçiş yok)
- Binalar greybox (011 ile stil gelecek; simge binalar için özel modeller 5.2)
- Gerçek kullanıcıyla performans ölçümü yok (telefon testi gerekli)
