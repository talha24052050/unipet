# Arkadaşlarla oynama (test sürümü)

Sunucu senin bilgisayarında çalışır; arkadaşların telefondan bağlanır. Supabase gerekmez:
herkes kendi mailini yazar, kod olarak **000000** girer (geliştirme modu).

## Bir kez: Docker
1. Yönetici PowerShell: `winget install -e --id Docker.DockerDesktop`
2. Bilgisayarı yeniden başlat, **Docker Desktop**'ı bir kez aç (WSL kurmak isterse kabul et).

## Her oyunda
1. Repo klasöründe PowerShell:
   - Aynı Wi-Fi'deyseniz: `powershell -ExecutionPolicy Bypass -File server/play-with-friends.ps1`
   - Farklı yerlerdeyseniz: `powershell -ExecutionPolicy Bypass -File server/play-with-friends.ps1 -Internet`
2. Script ekrana bir **adres** yazar (ör. `192.168.1.5` ya da `https://xxx.trycloudflare.com`).
3. Herkes APK'yı kurar: https://github.com/talha24052050/unipet/releases/download/android-debug/unipet-debug.apk
4. Giriş ekranında: mail → **Sunucu** alanına adres → Kod gönder → `000000` → pet seç → Başla.
5. Hepiniz Ortabahçe'de aynı odaya düşersiniz (oda 40 kişi).

## Sorunlar
- **Bağlanamıyor (aynı Wi-Fi):** Windows Güvenlik Duvarı. Yönetici PowerShell'de
  `New-NetFirewallRule -DisplayName "UniPet Nakama" -Direction Inbound -Protocol TCP -LocalPort 7350 -Action Allow`
  ya da `-Internet` ile dene. Okul/yurt Wi-Fi'leri cihazların birbirini görmesini engelleyebilir → `-Internet`.
- **-Internet adresi değişti:** Cloudflare geçici tüneli her açılışta yeni adres verir; yeni adresi tekrar paylaş.
- **Sunucu durdurma:** `powershell -ExecutionPolicy Bypass -File server/stop.ps1`
- Sunucu konsolu (oyuncular, odalar): http://127.0.0.1:7351 (kullanıcı/şifre `server/.env`'de)

## Güvenlik notu
Geliştirme modunda (`UNIPET_DEV_AUTH=true`) mail doğrulanmaz; adresi bilen herkes girebilir. Sadece güvendiğin
kişilerle paylaş. Kalıcı kullanım için Supabase girişi + kiralık sunucu (Parça 6).
