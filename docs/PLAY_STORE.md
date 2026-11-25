# Google Play'e çıkış

Kod tarafı hazır: imzalı AAB, hesap silme, engelle/şikayet, yasal sayfalar, mağaza metinleri ve görselleri.
Aşağıdakiler **Talha'nın** yapacakları (sıralı). Mağaza metinleri ve form cevapları: [`docs/store/LISTING.md`](store/LISTING.md).

## 0. Şimdiden bilinmesi gerekenler
- **Kişisel geliştirici hesabı** (13 Kasım 2023'ten sonra açılan) üretime çıkmadan önce **en az 12 test kullanıcısıyla
  14 gün kesintisiz kapalı test** yapmak zorunda. 12 kişi testi 14 gün boyunca bırakmamalı. Kurum (şirket) hesabında bu
  şart yok ama D-U-N-S numarası gerekir. → SKY LAB / arkadaşlarla kapalı test zaten planlı (ROADMAP 6.3); ona bağla.
- **Hedef SDK:** 31 Ağustos 2026'dan beri yeni uygulamalar Android 16 (API 36) hedeflemeli. Godot 4.7 varsayılanı 36 — tamam.
- **Paket adı** `io.github.talha24052050.unipet` ilk yüklemeden sonra **asla değişmez**. Değiştirmek istiyorsan şimdi söyle.
- Play App Signing: Google kendi imza anahtarını tutar; bizim `unipet-release.keystore` **yükleme anahtarı** olur.
  Keystore kaybolursa Play Console'dan yükleme anahtarı sıfırlanabilir (APK'daki gibi felaket değil) ama yine de sakla.

## 1. Bekleyen altyapı (bir kez)
1. **Supabase hesap silme fonksiyonu**: Supabase → SQL Editor → `server/supabase/003_account_delete.sql` içeriğini
   yapıştır → Run. (Ben uygulamayı denedim, izin sistemi üretim veritabanına yazmamı engelledi.)
   Bu olmadan "Hesabı sil" sunucu kısmını siler ama Supabase kısmında hata verir.
2. **Kalıcı sunucu** (docs/RELEASE.md adım 1). Kurulumda oturum anahtarları artık otomatik rastgele üretiliyor.
3. **GitHub Pages**: repo → Settings → Pages → Source: **GitHub Actions**. Sonra Actions → `pages` → Run workflow.
   Adresler: `https://talha24052050.github.io/unipet/gizlilik.html`, `.../kosullar.html`, `.../hesap-silme.html`
4. GitHub secret'ları (docs/RELEASE.md adım 3) — `NAKAMA_HOST` ve `NAKAMA_SERVER_KEY` sunucudan sonra.

## 2. Play Console hesabı
1. https://play.google.com/console → geliştirici hesabı aç (**25 $**, tek sefer). Kişisel hesap seç.
2. Kimlik doğrulama (kimlik kartı) + telefon doğrulama. Birkaç gün sürebilir.
3. Geliştirici e-postası: mağazada herkese görünür — ayrı bir destek adresi (ör. yeni bir Gmail) açman önerilir.

## 3. Uygulamayı oluştur
1. **Uygulama oluştur** → ad: `UniPet: Kampüs Pet Oyunu`, dil: Türkçe, **Oyun**, **Ücretsiz**.
2. Beyanlar: geliştirici politikaları + ABD ihracat yasaları → onayla.

## 4. Uygulama içeriği (Policy → App content) — cevaplar LISTING.md'de
- Gizlilik politikası URL'si
- Uygulama erişimi → inceleme hesabı (adım 7)
- Reklamlar → **Hayır**
- İçerik derecelendirmesi (IARC anketi)
- Hedef kitle → 13 altını seçme
- Veri güvenliği formu
- **Hesap silme** → URL: `.../hesap-silme.html`
- Haber / sağlık / finans / devlet uygulaması → Hayır

## 5. Mağaza girişi (Grow → Store presence → Main store listing)
LISTING.md'deki kısa/tam açıklama + `docs/store/icon_512.png`, `feature_graphic_1024x500.png`, `screenshots/*.png`.
Ekran görüntülerini telefondan gerçek oyunda çekersen daha iyi olur (en az 2, en fazla 8; dikey).

## 6. İlk sürüm
1. `git tag v0.2.0 && git push origin v0.2.0` → Actions → `release` → bitince GitHub Releases'ta
   `unipet-v0.2.0.aab` (ve telefona doğrudan kurulacak `.apk`).
2. Play Console → Test → **Dahili test** → Yeni sürüm → AAB'yi yükle → kendini test kullanıcısı ekle → yayınla.
   (İlk yükleme elle olmalı; Play API uygulama oluşturamaz.)
3. Telefonda dahili test bağlantısından kur, giriş + hesap silme + engelle/şikayet dene.
4. **Kapalı test** → 12+ test kullanıcısının Gmail adreslerini ekle → 14 gün bekle (testçiler arada oyunu açsın).
5. 14 gün sonra Dashboard → **Üretime erişim başvurusu** (birkaç soru sorar: test nasıl geçti, ne düzeltildi).
6. Onaydan sonra Üretim → yeni sürüm → AAB → incelemeye gönder (ilk inceleme birkaç gün sürebilir).

İsteğe bağlı otomatik yükleme: Play Console → Kurulum → API erişimi → hizmet hesabı oluştur (Sürüm yöneticisi yetkisi)
→ JSON anahtarını `PLAY_SERVICE_ACCOUNT_JSON` GitHub secret'ı yap. Sonraki her `v*` etiketi AAB'yi dahili teste yükler.

## 7. İnceleme hesabı (Google incelemecisi e-postana erişemez)
1. Supabase → Authentication → Users → **Add user** → e-posta: ör. `unipet.review@gmail.com`, **şifre: 10 haneli bir
   sayı** (ör. `4815162342`), "Auto confirm" açık.
2. Play Console → Uygulama erişimi → talimat:
   "E-posta alanına `unipet.review@gmail.com` yazıp Kod iste'ye basın, kod alanına `4815162342` yazın."
   (Oyun, e-posta kodu tutmazsa kod alanındaki sayıyı o hesabın şifresi olarak dener. Şifresi olmayan normal hesaplar
   bundan etkilenmez.)

## 8. Moderasyon (yayından sonra düzenli)
- Şikayetler: Nakama konsolu (SSH tüneli, docs/RELEASE.md) → Storage → `reports` koleksiyonu. Her kayıtta şikayet eden,
  edilen, neden ve son mesajlar var.
- Bir hesabı kapatmak: Nakama konsolu → Accounts → kullanıcı → **Ban**. (İleride oyun içi yönetim ekranı yapılabilir.)
- Şikayet kayıtları politikada "en fazla 1 yıl" saklanır diye yazdı: yılda bir eskileri sil.
