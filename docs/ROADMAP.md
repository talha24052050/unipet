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
- [~] 5.3 Ortabahçe detaylı: ağaçlar, banklar, yollar
- [x] 5.4 Bölgeler arası geçiş (yapıldı, sonra kaldırılacak)
- [x] 5.4b **Tek bölge: tüm kampüs** (Talha kararı 2026-11-22) — tek greybox + tek navmesh + mobil performans (görünürlük mesafeleri), tek oda ailesi, harita ekranı "buradasın" + yere dokun → ışınlan (Talha)
- [x] 5.5 Pet bakımı: açlık/mutluluk/enerji, sunucuda saklama
- [ ] 5.6 Checkpoint

## Parça 6 — Kapalı test
- [~] 6.1 Ücretsiz VPS'e Nakama kurulumu
- [~] 6.2 İmzalı release APK
- [ ] 6.3 SKY LAB kapalı testi, geri bildirim formu
