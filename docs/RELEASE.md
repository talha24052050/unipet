# Yayın: sunucu (6.1) + imzalı APK (6.2)

Geliştirme APK'sı (her push, `android-debug`) sahte giriş + tek oyunculu/girilen sunucu ile çalışır.
Yayın APK'sı (`v*` etiketi) **Supabase girişi + gömülü sunucu** ile çalışır (`Config.IS_RELEASE`).

## 1. Sunucu (bir kez, ~15 dk)
1. Bir Ubuntu 22.04/24.04 VPS aç (1 vCPU / 1-2 GB RAM yeter). Ücretsiz seçenek: Oracle Cloud "Always Free"
   (kart doğrulaması ister). Ucuz seçenek: Hetzner CX22 (~4 €/ay).
2. VPS'te:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/talha24052050/unipet/main/server/deploy/setup-vps.sh | sudo bash
   ```
   Sonunda `https://<ip>.sslip.io` adresini ve `server_key`'i yazar. Alan adı gerekmez (sslip.io + Caddy HTTPS).
3. `/opt/unipet/server/.env` içine `SUPABASE_URL` ve `SUPABASE_ANON_KEY` yaz (docs/SUPABASE.md), sonra
   `sudo /opt/unipet/server/deploy/restart.sh`.
   Yayında `UNIPET_DEV_AUTH=false` (script ayarlar): sadece Supabase oturumu kabul edilir.

## 2. İmza anahtarı (bir kez)
Bilgisayarında (Java kurulu):
```powershell
keytool -genkeypair -v -keystore unipet-release.keystore -alias unipet -keyalg RSA -keysize 2048 -validity 10000
```
Şifreyi ve dosyayı GÜVENLİ sakla (kaybolursa aynı uygulamaya güncelleme çıkarılamaz). Repo'ya KOYMA.
Base64'e çevir: `[Convert]::ToBase64String([IO.File]::ReadAllBytes("unipet-release.keystore")) | Set-Clipboard`

## 3. GitHub secret'ları
Repo → Settings → Secrets and variables → Actions:

| Secret | Değer |
|---|---|
| `RELEASE_KEYSTORE_B64` | 2. adımdaki base64 |
| `RELEASE_KEYSTORE_USER` | `unipet` (alias) |
| `RELEASE_KEYSTORE_PASSWORD` | keystore şifresi |
| `SUPABASE_URL`, `SUPABASE_ANON_KEY` | Supabase → Project Settings → API |
| `NAKAMA_HOST` | `<ip>.sslip.io` (1. adım) |
| `NAKAMA_SERVER_KEY` | 1. adımın yazdığı server_key |

## 4. Sürüm çıkar
```bash
git tag v0.1.0 && git push origin v0.1.0
```
GitHub Actions → `release` → bitince Releases'ta `unipet-v0.1.0.apk`. Eksik secret varsa iş en başta hangisi olduğunu yazıp durur.
