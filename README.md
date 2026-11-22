<p align="center">
  <img src="game/icon.svg" width="120" alt="UniPet">
</p>

<h1 align="center">UniPet</h1>

<p align="center">
  <b>Davutpaşa'yı petinle keşfet.</b><br>
  YTÜ'lüler için 3D, çok oyunculu, mobil sanal kampüs oyunu.
</p>

<p align="center">
  <img alt="durum" src="https://img.shields.io/badge/durum-geliştirme%20aşamasında-orange">
  <img alt="platform" src="https://img.shields.io/badge/platform-Android-3DDC84">
  <img alt="motor" src="https://img.shields.io/badge/Godot-4.7-478CBF">
</p>

---

## Nedir?

UniPet, Yıldız Teknik Üniversitesi Davutpaşa Kampüsü'nün 3D kopyasında geçen sosyal ve çok oyunculu bir pet oyunudur.
Oyuncular kendi sevimli petlerini seçip aksesuarlarla özelleştirir, gerçek harita verileriyle inşa edilmiş kampüs sokaklarında dolaşır.
Ortabahçe'de, yemekhanede veya fakülteler önünde diğer YTÜ'lülerle karşılaşabilir, hazır mesajlar ve animasyonlarla sosyalleşip petlerinin bakımını yapabilirler.

## Nasıl denenir?

1. **Android APK'sını indirin:**  
   Her commit'te otomatik derlenen güncel sürüm: [unipet-debug.apk](https://github.com/talha24052050/unipet/releases/download/android-debug/unipet-debug.apk)
2. **Giriş yapın:**  
   Giriş ekranında e-posta kutusuna `000` yazarak tek tıkla şifresiz geliştirme modunda girebilirsiniz (oturumunuz hatırlanır). Normal test için herhangi bir e-posta adresi yazıp kod alanına `000000` girebilirsiniz.
3. **Petini giydir ve keşfe başla:**  
   6 farklı petten birini seçip kepi, gözlük, atkı veya çanta takın. Joystick veya dokun-yürü ile gezinebilir, sağ üstteki "Harita" butonuyla Davutpaşa'nın 7 bölgesi arasında geçiş yapabilirsiniz. Bakım HUD'undaki butonlarla petinizi besleyebilir, dinlendirebilir ve oynatabilirsiniz.

## Belgeler

- [docs/DURUM.md](docs/DURUM.md) — Güncel durum, çalışan sistemler ve son yenilikler
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — Klasör yapısı, servis katmanı, ağ protokolü ve bakım mimarisi
- [docs/SETUP.md](docs/SETUP.md) — Geliştirme ortamı kurulumu, USB ile telefona dağıtım ve yerel sunucu
- [docs/ROADMAP.md](docs/ROADMAP.md) — Parça ve görev bazlı yol haritası
- [docs/DECISIONS.md](docs/DECISIONS.md) — Proje hakkında alınmış kararlar
- [docs/ARKADASLARLA_OYNA.md](docs/ARKADASLARLA_OYNA.md) — Aynı Wi-Fi'da veya tünelle arkadaşlarla çok oyunculu deneme
- [docs/RELEASE.md](docs/RELEASE.md) — Sunucu kurulumu ve imzalı Android sürümü hazırlığı

## Katkı ve Teknoloji

- **Oyun Motoru:** [Godot 4.7](https://godotengine.org) (GDScript, mobil renderer)
- **Sunucu & Veritabanı:** [Nakama](https://heroiclabs.com/nakama/) (çok oyunculu maç ve durum) · [Supabase](https://supabase.com) (kimlik ve profil)
- **Modeller:** [Quaternius](https://quaternius.com) (CC0 Ultimate Monsters & Props). Detaylar: [game/assets/CREDITS.md](game/assets/CREDITS.md).

---

<sub>UniPet bağımsız bir öğrenci projesidir; Yıldız Teknik Üniversitesi'nin resmî bir ürünü değildir.</sub>
