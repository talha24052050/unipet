# Yol haritası

Her task = bir commit. Her parça sonu = Talha kontrolü (`checkpoint`).
## Talha'yı bekleyenler (Claude bunlar olmadan ilerleyemez)
- [x] **Supabase** (3.1): proje+şema+mail+GitHub secret'ları tamam (CI APK'sında secrets.cfg doğrulandı, 2026-11-22)
- [x] ~~Docker Desktop kurulumu~~ → gerek kalmadı: `server/local-nakama.ps1` Docker'sız çalışıyor (yerelde uçtan uca test geçti)
- [ ] **Telefonda test**: pet seçimi/aksesuar, giriş (kod 000000), chat/emote, bakım
- [ ] **Arkadaşlarla ilk oyun**: `docs/ARKADASLARLA_OYNA.md`
- [ ] **Kalıcı sunucu + imzalı sürüm** (6.1/6.2): kod hazır, adımlar `docs/RELEASE.md` (VPS, keystore, GitHub secret'ları)

Durum: `[ ]` bekliyor · `[~]` devam · `[x]` bitti · `(agy)` Antigravity'ye verilecek

## Parça 0 — Altyapı ✅
- [x] 0.1 Repo iskeleti, Godot 4.7 projesi (mobile renderer, dikey)
- [x] 0.2 Servis katmanı: NetworkService/AuthService arayüzleri + Offline/Mock implementasyonları
- [x] 0.3 CharacterDef + CharacterRegistry, ChatMessage
- [x] 0.4 Mini test runner + ilk testler, GitHub Actions'ta otomatik test
- [x] 0.5 CLAUDE.md, kararlar, mimari, skill'ler
- [x] 0.6 agy görev kutusu scripti + kurulum talimatı
- [x] 0.7 (Talha) Godot 4.7.2 kur, projeyi aç, ana sahneyi çalıştır, ekran görüntüsünü onayla

## Parça 1 — Tek oyunculu prototip ✅
- [x] 1.1 Oyuncu sahnesi: CharacterBody3D + yerçekimi + yer takibi (placeholder kapsül)
- [x] 1.2 Sanal joystick (sol alt, dokunmatik, çoklu dokunma güvenli)
- [x] 1.3 Dokun-yürü: zemine dokun → NavigationAgent3D ile hedefe yürü; joystick dokunuşu iptal eder
- [x] 1.4 Takip kamerası: üçüncü şahıs, iki parmakla döndürme/yakınlaştırma, duvara girmeme
- [x] 1.5 Greybox Ortabahçe: düz kutularla yerleşim (ölçek testi), navigation mesh
- [x] 1.6 Android test build'i (GitHub Actions'ta APK üret — Talha'nın internetini harcamamak için)
- [x] 1.7 Checkpoint: Talha telefonda yürüme hissini test eder

## Parça 2 — Karakter sistemi
- [x] 2.1 Quaternius Ultimate Monsters'tan 3-5 pet seçimi (Talha seçer, önizleme sayfası hazırlanır)
- [x] 2.2 Pet glb'lerini indirme scripti (poly.pizza, Blender gerekmedi) + inceleme scripti: boyut, yön, animasyon/kemik listesi (`art/pets_inspect.json`)
- [x] 2.3 Her pet için `.tres` (animation_map, accessory_bones)
- [x] 2.4 PetVisual düğümü: CharacterDef'ten model yükle, mantıksal animasyon oynat
- [x] 2.5 Aksesuar sistemi: slot'a BoneAttachment3D ile takma, 3-4 basit aksesuar (şapka, gözlük, atkı, çanta)
- [x] 2.6 Pet seçme + aksesuar giydirme ekranı
- [ ] 2.7 Checkpoint

## Parça 3 — Giriş (Supabase)
- [x] 3.1 Supabase projesi (xcltkhaupzmihadzqwjz), şema+RLS uygulandı, Gmail SMTP (465) + kodlu şablonlar; mail→kod→giriş ve RLS gerçek hesapla doğrulandı (2026-11-22). Okul maili hook'u hazır ama kapalı.
- [x] 3.2 SupabaseAuthService (HTTPRequest ile REST), oturumu güvenli saklama, yenileme
- [x] 3.3 Giriş ekranı: mail → kod → pet seçimi
- [x] 3.4 Profil tablosu (kullanıcı adı, pet, aksesuarlar) + RLS kuralları
- [ ] 3.5 Checkpoint

## Parça 4 — Multiplayer (Nakama)
- [x] 4.1 `server/docker-compose.yml` (Nakama + Postgres), lokal çalıştırma talimatı
- [x] 4.2 Supabase token → Nakama custom auth köprüsü (sunucu modülü)
- [x] 4.3 Bölge/kanal eşleştirme (zone → oda, kapasite)
- [x] 4.4 NakamaNetworkService: katıl/ayrıl, state gönder/al, interpolasyon
- [x] 4.5 Hazır cümleler + emote UI, baloncuk gösterimi
- [~] 4.6 İki cihazla test, Checkpoint — yerel gerçek Nakama'ya karşı iki istemcili uçtan uca test GEÇTİ (`tools/e2e/nakama_two_players.gd`); telefonlarla deneme Talha'da

## Parça 5 — Kampüs + pet döngüsü
- [x] 5.1 OSM'den Davutpaşa bina yerleşimi çekme scripti
- [x] 5.2 Simge binalar: cephe tabelaları (61 bina), Kışla geçit çerçevesi, script ile üretilen low-poly süs modelleri (Kışla, Mescit kubbe+minare, Yemekhane, EEF, Hokka) — `tools/assets/make_landmarks.py` (Blender Smart App Control yüzünden çalışmadı; GLB doğrudan yazılıyor)
- [x] 5.3 Ortabahçe + kampüs detaylı (Street View/drone/Google fotoğrafları): ~1770 ağaç (çınar/fıstık çamı/servi), pembe beton avlu yolları, parke + tuğla kenar, tarhlar, büfe, stadyum pisti, havuz; Kışla taş dış cephe + giriş bölümleri; Yemekhane tuğla; Büyük Ev; OSM etiketleriyle yükseklik/sundurma/köprü/çatı
- [x] 5.4 Bölgeler arası geçiş (yapıldı, sonra kaldırılacak)
- [x] 5.4b **Tek bölge: tüm kampüs** (Talha kararı 2026-11-22) — tek greybox + tek navmesh + mobil performans (görünürlük mesafeleri), tek oda ailesi, harita ekranı "buradasın" + yere dokun → ışınlan (Talha)
- [x] 5.5 Pet bakımı: açlık/mutluluk/enerji, sunucuda saklama
- [x] 5.7 Kampüs keşfi: 47 yere yürüyerek yaklaşınca (22 m) keşif bildirimi, harita "Keşif: n/47" + altın halkalar; ışınlanma sayılmaz (önce 30 m yürümek gerekir). Şimdilik cihazda saklanıyor
- [x] 5.8 Pet etkileşimi: kendi petine dokun → kalpler + sevinç hareketi; başka pete dokun → dönüp el sallar, "Selam!" der
- [x] 5.9 Yıldız tozu + dükkan: her gün 40 toplanabilir yıldız (yaya yollarında, sunucu konumla doğrular), sayaç; pet ekranında 3 yeni ücretli aksesuar (Çiçek tacı 15, Yıldız taç 30, Pelerin 40) denenir/satın alınır; alınmamış ürün takılamaz (sunucu da reddeder)
- [x] 5.10 Mini oyun: Stadyumda Frizbi — 45 sn, ortadan atılan frizbileri halkaya koşup yakala, 5'li seri bonusu, en iyi skor; skor → yıldız tozu (oyun başına ≤5, günde ≤15, sunucu sınırlar)
- [x] 5.11 Koşu yarışı (çok oyunculu): Stadyum pistinde yarım tur (~214 m, 6 kapı); başlangıçta "Koşu yarışına katıl" → 10 sn lobi (odadaki herkes katılabilir) → 3-2-1 → koşu; sunucu kapıları konum + süreyle doğrular; sıra/süre, sonuç tablosu; ödül: 1. (2+ koşucu) 3, 2. (3+) 2, bitiren 1 yıldız tozu (mini oyun günlük tavanıyla)
- [x] 5.12 Canlı kampüs 1: Davutpaşa kedileri — 14 kedi (Yemekhane önü, Hokka, Ortabahçe, Kütüphane, Büyük Ev, Kız yurdu, Eskafe, B Girişi); gezer, oturur, uyur, yanında durunca etrafında dolanır, dokununca miyavlar (sentez ses) + kalpler; kedi başına 3 çizim, uzaktakiler durur
- [x] 5.13 UI/HUD ince ayar + iOS ön hazırlık: ortak tema (`unipet_theme.tres`), kompakt bakım HUD, çakışmayan yıldız tozu, Safe Area (çentik/alt çubuk), `AppLifecycle`, şeffaflıksız iOS ikon seti + export preset + `docs/IOS.md`
- [x] 5.14 Gerçek yer şekilleri + görsel gerçekçilik: Davutpaşa 12.5 m DEM arazi (`kampus_terrain.json`), Taşbina/Stadyum/sahalar düzleştirilmiş, eğimli 3D navmesh, bordürlü asfalt yollar, atmosferik derinlik sisi, Teknopark cam stili, piste hizalı Stadyum çizgi/kale/projektör/doğu tribün (2 çizim çağrısı)
- [ ] 5.6 Checkpoint

## Parça 6 — Kapalı test
- [~] 6.1 Ücretsiz VPS'e Nakama kurulumu
- [~] 6.2 İmzalı release APK — keystore + GitHub secret'ları hazır (CI'da doğrulandı); kalıcı sunucu adresi (NAKAMA_HOST) bekleniyor
- [~] 6.3 SKY LAB kapalı testi — oyun içi geri bildirim (Ayarlar → Supabase `feedback`) hazır; test turu kalıcı sunucudan sonra
