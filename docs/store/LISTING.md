# Google Play mağaza girişi (kopyala-yapıştır)

## Uygulama bilgileri
- **Uygulama adı (30):** `UniPet: Kampüs Pet Oyunu`
- **Paket adı:** `io.github.talha24052050.unipet` (ilk yüklemeden sonra DEĞİŞTİRİLEMEZ)
- **Kategori:** Oyun → Simülasyon (alternatif: Gündelik)
- **Etiketler:** Sanal evcil hayvan, Çok oyunculu, Sosyal
- **Uygulama mı oyun mu:** Oyun · **Ücretsiz** · Reklam **yok**

## Kısa açıklama (80 karakter)
```
YTÜ Davutpaşa kampüsünde petinle gez, arkadaşlarınla buluş, Ring'e bin!
```

## Tam açıklama (4000 karakter)
```
UniPet, Yıldız Teknik Üniversitesi Davutpaşa kampüsünün 3D kopyasında geçen, çok oyunculu sosyal bir pet oyunu.

🐾 PETİNİ SEÇ
Sevimli petlerden birini seç, şapka, gözlük, atkı, pelerin gibi aksesuarlarla giydir. Petini besle, dinlendir, onunla oyna.

🗺 KAMPÜSÜ KEŞFET
Gerçek kampüs yerleşimiyle Ortabahçe, Yemekhane, Hokka, Tarihi Hamam, Stadyum ve daha fazlası. 47 noktayı yürüyerek keşfet, kampüsün kedileriyle tanış.

🚌 RING'E BİN
Mavi Ring ve 41AT kampüsün içinde dolaşıyor. Durakta bekle, bin, camdan kampüsü izle.

👋 ARKADAŞLARINLA BULUŞ
Herkes aynı kampüste. Hazır cümleler ve emojilerle selamlaş, arkadaş ekle, kafelerde ve gruplarda sohbet et.

⭐ YILDIZ TOZU TOPLA
Her gün kampüse dağılan yıldız tozlarını topla, yeni aksesuarlar al. Stadyumda frizbi oyna, koşu yarışına katıl.

🛡 GÜVENLİ SOHBET
Sohbette argo filtresi var. Rahatsız eden oyuncuyu tek dokunuşla engelleyebilir ya da şikayet edebilirsin.

UniPet bağımsız bir öğrenci projesidir; Yıldız Teknik Üniversitesi'nin resmî uygulaması değildir.
Harita verisi © OpenStreetMap katkıcıları.
```

## Grafikler (`docs/store/`)
| Öğe | Dosya | Not |
|---|---|---|
| Uygulama simgesi 512×512 | `icon_512.png` | |
| Öne çıkan grafik 1024×500 | `feature_graphic_1024x500.png` | |
| Telefon ekran görüntüleri (2–8 adet, 9:16) | `screenshots/01..05_*.png` (1080×1920) | `tools/store/screenshots.gd` üretir. Telefondan çekilmiş gerçek oyun görüntüleri daha iyi olur. |

## İletişim / bağlantılar
- **Gizlilik politikası:** https://talha24052050.github.io/unipet/gizlilik.html
- **Hesap silme adresi:** https://talha24052050.github.io/unipet/hesap-silme.html
- **Web sitesi:** https://talha24052050.github.io/unipet/
- **E-posta:** (Play Console'daki geliştirici e-postası — mağazada herkese görünür)

---

## Veri güvenliği formu (Data safety) — cevaplar
- Uygulama kullanıcı verisi topluyor veya paylaşıyor mu? **Evet**
- Aktarım sırasında şifreleniyor mu? **Evet** (HTTPS/WSS)
- Kullanıcılar verilerinin silinmesini isteyebilir mi? **Evet** → uygulama içi + yukarıdaki hesap silme adresi
- Veriler üçüncü taraflarla **paylaşılıyor mu? Hayır** (Supabase ve sunucu sağlayıcısı "hizmet sağlayıcı" sayılır, paylaşım değildir)

| Veri türü (Play kategorisi) | Toplanıyor | Zorunlu mu | Amaç |
|---|---|---|---|
| Kişisel bilgi → **E-posta adresi** | Evet | Zorunlu | Hesap yönetimi, uygulama işlevselliği |
| Kişisel bilgi → **Kullanıcı kimlikleri** (hesap kimliği) | Evet | Zorunlu | Hesap yönetimi, uygulama işlevselliği |
| Kişisel bilgi → **Ad** (kullanıcı adı / takma ad) | Evet | İsteğe bağlı | Uygulama işlevselliği |
| Mesajlar → **Diğer uygulama içi mesajlar** (sohbet) | Evet (saklanmaz, iletilir; şikayette kanıt) | İsteğe bağlı | Uygulama işlevselliği, dolandırıcılığı önleme/güvenlik |
| Uygulama etkinliği → **Uygulama içi etkileşimler** (arkadaşlar, ilerleme) | Evet | Zorunlu | Uygulama işlevselliği |
| Uygulama etkinliği → **Kullanıcı tarafından oluşturulan diğer içerikler** (profil yazısı, geri bildirim) | Evet | İsteğe bağlı | Uygulama işlevselliği, analiz (hata düzeltme) |
| Konum (yaklaşık/kesin) | **Hayır** (oyun içi sanal konum gerçek konum değildir) | | |
| Cihaz kimlikleri, reklam kimliği, fotoğraf, ses, rehber, finans, sağlık | **Hayır** | | |

## İçerik derecelendirme (IARC anketi) — cevaplar
- Kategori: **Oyun**
- Şiddet, korku, cinsellik, kumar, uyuşturucu, küfür (geliştiricinin içeriğinde): **Hayır**
- **Kullanıcılar birbiriyle etkileşebiliyor mu / iletişim kurabiliyor mu?** **Evet** (sohbet, arkadaşlık)
- Kullanıcılar içerik paylaşabiliyor mu? **Evet** (yazılı sohbet, filtreli; engelle/şikayet var)
- Kullanıcının konumunu diğer kullanıcılarla paylaşıyor mu? **Hayır** (gerçek konum yok)
- Dijital satın alma: **Hayır** (şimdilik)
- Beklenen sonuç: PEGI 12 / ESRB Teen civarı ("Kullanıcılar etkileşir" ibaresiyle)

## Hedef kitle
- Yaş grupları: **16-17, 18+** (13-15 de seçilebilir; 13 altı SEÇME → aile politikası devreye girer)
- Çocuklara hitap ediyor mu? **Hayır**

## Diğer beyanlar
- **Reklam içeriyor mu:** Hayır
- **Uygulama erişimi (incelemeci için):** Giriş e-posta koduyla. İnceleme için bir test hesabı ver:
  Play Console → Uygulama içeriği → Uygulama erişimi → talimat: "E-posta: <test maili>, kod e-postaya gelir" —
  ya da Supabase'de inceleme için sabit kodlu bir hesap aç (docs/PLAY_STORE.md, adım 7).
- **Haber uygulaması / COVID / finans / sağlık / devlet:** Hayır
- **Kullanıcı tarafından oluşturulan içerik (UGC):** Evet — koşullar girişte kabul ediliyor, uygulama içi engelle +
  şikayet var, sohbet filtreli, şikayetler sunucuda kanıtla saklanıyor.
