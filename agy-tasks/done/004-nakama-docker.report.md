# Görev 004 Raporu — Nakama + Postgres Yerel Kurulum (ROADMAP 4.1)

## 1. Ne Yapıldı?
- **Docker Durumu ve Kurulum Denemesi**:
  - `docker --version` komutu çalıştırıldı; sistemde Docker'ın kurulu olmadığı görüldü (`The term 'docker' is not recognized`).
  - Görev tanımına uygun olarak `winget install -e --id Docker.DockerDesktop --accept-package-agreements --accept-source-agreements` komutu ile kurulum denendi.
  - Docker Desktop 4.99.0 yükleyicisi (~623 MB) başarıyla indirildi ve hash doğrulaması yapıldı.
  - Yükleyici başlatıldığında Windows UAC (Yönetici izni) uyarısı verdi (`The installer will request to run as administrator. Expect a prompt.`) ve yönetici izni verilemediği için yükleme `4294967291` (`0xFFFFFFFB`) çıkış kodu ile sonlandı.
  - Yönergedeki *"Yönetici izni/yeniden başlatma/WSL kurulumu isterse ZORLAMA: kurulumu bırak, rapora tam çıktıyı yaz, 2-5. adımlara devam et"* kuralına tam uyularak zorlanmadı ve 2-5. adımlara geçildi.
- **`server/docker-compose.yml`**:
  - Resmi kararlı sürüm etiketiyle `heroiclabs/nakama:3.26.0` ve `postgres:16-alpine` servisleri tanımlandı (`latest` kullanılmadı).
  - Nakama servisinin entrypoint'inde önce `migrate up` veritabanı şema göçünün tamamlanması, ardından Nakama sunucusunun başlatılması sağlandı.
  - Nakama için `7349` (gRPC), `7350` (HTTP API/WebSocket) ve `7351` (Geliştirici Konsolu) portları tanımlandı.
  - PostgreSQL için `5432` portu tanımlandı ve veritabanı verisi adlandırılmış volume (`postgres_data`) üzerinde kalıcı hale getirildi.
  - Servisler için `healthcheck` mekanizmaları eklendi (Postgres için `pg_isready`, Nakama için yerel `/nakama/nakama healthcheck`). Nakama'nın `depends_on` ile Postgres'in `service_healthy` olmasını beklemesi sağlandı.
- **`server/nakama/local.yml`**:
  - `name: unipet-local`, `logger.level: INFO`, `session.token_expiry_sec: 7200` olarak ayarlandı.
  - `socket.server_key` ve `console` kullanıcı adı/şifre ayarlarının Docker Compose ortam değişkenleri (`server/.env`) üzerinden dinamik olarak CLI parametresiyle ezilmesi kurgulandı.
- **`server/.env.example`**:
  - Ortam değişkenleri için örnek dosya oluşturuldu (`POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `NAKAMA_SERVER_KEY`, `NAKAMA_CONSOLE_USER`, `NAKAMA_CONSOLE_PASS`). Repo'ya hiçbir gerçek gizli anahtar konulmadı.
- **`server/start.ps1` ve `server/stop.ps1`**:
  - `start.ps1`: `.env` dosyası yoksa otomatik olarak `.env.example`'dan oluşturur, `docker compose up -d` ile konteynerleri ayağa kaldırır ve `http://127.0.0.1:7350/healthcheck` adresi HTTP 200 dönene kadar (azami 60 saniye) sağlık kontrolünü bekler.
  - `stop.ps1`: `docker compose down` komutunu çalıştırarak konteynerleri temiz şekilde durdurur.
- **`server/README.md`**:
  - Türkçe, sade ve anlaşılır kullanım dokümantasyonu hazırlandı: gereksinimler, `.env` yapılandırması, başlatma/durdurma adımları ve konsol erişim linki (`http://127.0.0.1:7351`).
- **`.gitignore`**:
  - Sadece yerel veri dizini olan `server/data/` eklendi.

## 2. Hangi Dosyalara Dokunuldu?
Sadece görev tanımında izin verilen dosyalara dokunuldu:
- `server/docker-compose.yml` (yeni oluşturuldu)
- `server/nakama/local.yml` (yeni oluşturuldu)
- `server/.env.example` (yeni oluşturuldu)
- `server/start.ps1` (yeni oluşturuldu)
- `server/stop.ps1` (yeni oluşturuldu)
- `server/README.md` (güncellendi)
- `.gitignore` (güncellendi: `server/data/` eklendi)
- `agy-tasks/done/004-nakama-docker.report.md` (bu rapor)

*(Hiçbir `git commit` veya `git push` yapılmadı.)*

## 3. Test Sonuçları
- **`docker --version`**:
  ```
  docker : The term 'docker' is not recognized as the name of a cmdlet, function, script file, or operable program.
  ```
- **`winget install` çıktısı**:
  ```
  Found Docker Desktop [Docker.DockerDesktop] Version 4.99.0
  Downloading https://desktop.docker.com/win/main/amd64/245822/Docker%20Desktop%20Installer.exe
  Successfully verified installer hash
  Starting package install...
  The installer will request to run as administrator. Expect a prompt.
  Installer failed with exit code: 4294967291
  ```
- **YAML Sözdizimi ve Yapı Testi**:
  - `server/docker-compose.yml` ve `server/nakama/local.yml` dosyaları Python `yaml.safe_load` ile parse edildi; her iki dosyanın da geçerli YAML sözdiziminde olduğu ve anahtarların doğru yapılandırıldığı doğrulandı.
- **PowerShell Betik Sözdizim Testi**:
  - `[System.Management.Automation.PSParser]::Tokenize` ile `start.ps1` ve `stop.ps1` betikleri tokenize edilip sözdizimi hatasız geçti.
- **Godot Testleri**:
  - `godot.exe --headless --path game -s res://tests/run_tests.gd` çalıştırıldı; çıkış kodu 0 ile başarıyla tamamlandı (oyun tarafına hiçbir dokunulmadığı teyit edildi).

## 4. Belirsiz Kalanlar / Kullanıcıya Notlar
- Docker Desktop kurulumu yönetici (UAC) yetkisi gerektirdiğinden CLI oturumu üzerinden tamamlanamadı.
- **Yapılması gereken:** Talha'nın kendi Windows kullanıcı oturumunda Docker Desktop kurulumunu tamamlaması (veya yönetici olarak açılmış bir terminalde `winget install -e --id Docker.DockerDesktop` çalıştırması) ve Docker Desktop'ı başlatması gerekmektedir.
- Docker Desktop çalışır duruma geldikten sonra `server/start.ps1` çalıştırıldığında Nakama ve Postgres konteynerleri otomatik olarak başlayacak ve `http://127.0.0.1:7351` konsolu kullanılabilir olacaktır.
