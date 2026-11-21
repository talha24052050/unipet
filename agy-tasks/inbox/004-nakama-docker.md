# 004 — Nakama + Postgres yerel kurulum (ROADMAP 4.1)

## Amaç
Multiplayer sunucusu Nakama'yı bu bilgisayarda Docker ile çalıştırılabilir hale getirmek. Oyun tarafına dokunma.

## Dokunabileceğin dosyalar
- `server/docker-compose.yml` (yeni)
- `server/nakama/local.yml` (yeni, Nakama config)
- `server/start.ps1`, `server/stop.ps1` (yeni)
- `server/README.md` (güncelle)
- `.gitignore` (sadece `server/data/` gibi yerel veri klasörü eklemek için)
- `agy-tasks/done/004-nakama-docker.report.md`
Başka dosyaya dokunma.

## Yapılacaklar
1. `docker --version` dene. Docker yoksa `winget install -e --id Docker.DockerDesktop --accept-package-agreements --accept-source-agreements`
   ile kurmayı dene. Yönetici izni/yeniden başlatma/WSL kurulumu isterse ZORLAMA: kurulumu bırak, rapora tam çıktıyı yaz, 2-5. adımlara devam et.
2. `server/docker-compose.yml`: resmi `heroiclabs/nakama` imajı (sabit sürüm etiketi, `latest` değil; güncel kararlı 3.x) + `postgres:16-alpine`.
   Nakama başlarken `migrate up` sonra sunucu (Heroic Labs'in resmi docker-compose örneğindeki entrypoint düzeni).
   Portlar: 7349, 7350, 7351. Postgres verisi adlandırılmış volume'da. `healthcheck`ler olsun.
3. `server/nakama/local.yml`: `name: unipet-local`, `logger.level: INFO`, `session.token_expiry_sec: 7200`,
   `socket.server_key` ve `console` kullanıcı/şifre ORTAM DEĞİŞKENİNDEN gelsin (`server/.env`, gitignore'da zaten `.env` var);
   `server/.env.example` dosyasında örnek değerler olsun (`.env.example` repo'ya girebilir — bunu da oluştur, dokunabileceğin dosyalara dahil).
4. `start.ps1` / `stop.ps1`: `docker compose up -d` / `down`; start sonunda `http://127.0.0.1:7350/healthcheck` 200 dönene kadar (en çok 60 sn) bekle.
5. `server/README.md`: Türkçe, kısa: gereksinim, `.env` oluşturma, başlat/durdur, konsol adresi (`http://127.0.0.1:7351`).
6. Docker çalışıyorsa `start.ps1`'i çalıştır, healthcheck sonucunu ve `docker compose ps` çıktısını rapora koy, sonra `stop.ps1`.

## Kabul kriterleri
- [ ] `docker compose -f server/docker-compose.yml config` hatasız (Docker varsa)
- [ ] Gizli değer repo'da yok (sadece `.env.example`)
- [ ] Docker kurulamadıysa sebebi rapordа net

## Kurallar
- CLAUDE.md'ye uy. git commit/push YAPMA (runner yapar).
- Rapor: `agy-tasks/done/004-nakama-docker.report.md`, Türkçe: ne yaptın, çıktılar, belirsiz kalanlar.
