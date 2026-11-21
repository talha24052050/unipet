# UniPet Sunucu Altyapısı (Nakama + PostgreSQL)

Multiplayer backend servisi olarak Heroic Labs Nakama ve PostgreSQL kullanılmaktadır.

## Gereksinimler
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (veya Docker Engine + Docker Compose v2)

## Kurulum ve Yapılandırma (.env)
Sunucu gizli anahtarları ve veritabanı şifreleri ortam değişkenleri üzerinden yönetilir.
İlk çalıştırmada `server/.env.example` dosyasını `server/.env` olarak kopyalayın:

```powershell
cp .env.example .env
```
*(Not: `start.ps1` çalıştırıldığında `.env` yoksa otomatik olarak `.env.example`'dan kopyalanır.)*

`.env` dosyasındaki temel parametreler:
- `POSTGRES_DB`: PostgreSQL veritabanı adı (`nakama`)
- `POSTGRES_USER`: PostgreSQL kullanıcı adı (`postgres`)
- `POSTGRES_PASSWORD`: PostgreSQL şifresi (`localdb`)
- `NAKAMA_SERVER_KEY`: Nakama client soket bağlantı anahtarı (`unipet-dev-server-key`)
- `NAKAMA_CONSOLE_USER`: Nakama konsol kullanıcı adı (`admin`)
- `NAKAMA_CONSOLE_PASS`: Nakama konsol şifresi (`password`)

## Servisleri Başlatma ve Durdurma

PowerShell üzerinden:
```powershell
# Servisleri başlat ve sağlık kontrolünü bekle (HTTP 200)
.\start.ps1

# Servisleri durdur
.\stop.ps1
```

Veya doğrudan Docker Compose ile:
```powershell
docker compose up -d
docker compose down
```

## Servis Adresleri ve Portlar
- **Geliştirici Konsolu (Dashboard):** [http://127.0.0.1:7351](http://127.0.0.1:7351)
  - Varsayılan Giriş: `admin` / `password` (veya `.env` dosyasında belirlediğiniz değerler)
- **HTTP API / WebSocket / Sağlık Kontrolü:** [http://127.0.0.1:7350](http://127.0.0.1:7350)
  - Sağlık kontrolü: `http://127.0.0.1:7350/healthcheck`
- **gRPC API:** `127.0.0.1:7349`
- **PostgreSQL:** `127.0.0.1:5432`
