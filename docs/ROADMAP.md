# Yol haritası

Her task = bir commit. Her parça sonu = Talha kontrolü (`checkpoint`).
Durum: `[ ]` bekliyor · `[~]` devam · `[x]` bitti · `(agy)` Antigravity'ye verilecek

## Parça 0 — Altyapı ✅
- [x] 0.1 Repo iskeleti, Godot 4.7 projesi (mobile renderer, dikey)
- [x] 0.2 Servis katmanı: NetworkService/AuthService arayüzleri + Offline/Mock implementasyonları
- [x] 0.3 CharacterDef + CharacterRegistry, ChatMessage
- [x] 0.4 Mini test runner + ilk testler, GitHub Actions'ta otomatik test
- [x] 0.5 CLAUDE.md, kararlar, mimari, skill'ler
- [x] 0.6 agy görev kutusu scripti + kurulum talimatı
- [x] 0.7 (Talha) Godot 4.7.2 kur, projeyi aç, ana sahneyi çalıştır, ekran görüntüsünü onayla

## Parça 1 — Tek oyunculu prototip
- [x] 1.1 Oyuncu sahnesi: CharacterBody3D + yerçekimi + yer takibi (placeholder kapsül)
- [ ] 1.2 Sanal joystick (sol alt, dokunmatik, çoklu dokunma güvenli)
- [ ] 1.3 Dokun-yürü: zemine dokun → NavigationAgent3D ile hedefe yürü; joystick dokunuşu iptal eder
- [ ] 1.4 Takip kamerası: üçüncü şahıs, iki parmakla döndürme/yakınlaştırma, duvara girmeme
- [ ] 1.5 Greybox Ortabahçe: düz kutularla yerleşim (ölçek testi), navigation mesh
- [ ] 1.6 Android test build'i (GitHub Actions'ta APK üret — Talha'nın internetini harcamamak için)
- [ ] 1.7 Checkpoint: Talha telefonda yürüme hissini test eder

## Parça 2 — Karakter sistemi
- [ ] 2.1 Quaternius Ultimate Monsters'tan 3-5 pet seçimi (Talha seçer, önizleme sayfası hazırlanır)
- [ ] 2.2 Blender scripti: FBX → glb, ölçek/eksen düzeltme, animasyon adlarını listeleme
- [ ] 2.3 Her pet için `.tres` (animation_map, accessory_bones)
- [ ] 2.4 PetVisual düğümü: CharacterDef'ten model yükle, mantıksal animasyon oynat
- [ ] 2.5 Aksesuar sistemi: slot'a BoneAttachment3D ile takma, 3-4 basit aksesuar (şapka, gözlük, atkı, çanta)
- [ ] 2.6 Pet seçme + aksesuar giydirme ekranı
- [ ] 2.7 Checkpoint

## Parça 3 — Giriş (Supabase)
- [ ] 3.1 Supabase projesi (Talha açar, ücretsiz katman) + domain kısıtlı OTP mail ayarı
- [ ] 3.2 SupabaseAuthService (HTTPRequest ile REST), oturumu güvenli saklama, yenileme
- [ ] 3.3 Giriş ekranı: mail → kod → pet seçimi
- [ ] 3.4 Profil tablosu (kullanıcı adı, pet, aksesuarlar) + RLS kuralları
- [ ] 3.5 Checkpoint

## Parça 4 — Multiplayer (Nakama)
- [ ] 4.1 `server/docker-compose.yml` (Nakama + Postgres), lokal çalıştırma talimatı
- [ ] 4.2 Supabase token → Nakama custom auth köprüsü (sunucu modülü)
- [ ] 4.3 Bölge/kanal eşleştirme (zone → oda, kapasite)
- [ ] 4.4 NakamaNetworkService: katıl/ayrıl, state gönder/al, interpolasyon
- [ ] 4.5 Hazır cümleler + emote UI, baloncuk gösterimi
- [ ] 4.6 İki cihazla test, Checkpoint

## Parça 5 — Kampüs + pet döngüsü
- [ ] 5.1 OSM'den Davutpaşa bina yerleşimi çekme scripti
- [ ] 5.2 Blender scriptiyle low-poly binalar (fotoğraf referanslı): fakülteler, Büyükev, Hokka, kafeler, yemekhane, büyük saha
- [ ] 5.3 Ortabahçe detaylı: ağaçlar, banklar, yollar
- [ ] 5.4 Bölgeler arası geçiş
- [ ] 5.5 Pet bakımı: açlık/mutluluk/enerji, sunucuda saklama
- [ ] 5.6 Checkpoint

## Parça 6 — Kapalı test
- [ ] 6.1 Ücretsiz VPS'e Nakama kurulumu
- [ ] 6.2 İmzalı release APK
- [ ] 6.3 SKY LAB kapalı testi, geri bildirim formu
