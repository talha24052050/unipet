# UniPet Nakama + Postgres baslatma betigi
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $ScriptDir

# .env kontrolu: yoksa .env.example'dan olustur
if (-not (Test-Path "$ScriptDir\.env")) {
    if (Test-Path "$ScriptDir\.env.example") {
        Write-Host "[UniPet] .env bulunamadi, .env.example dosyasindan olusturuluyor..." -ForegroundColor Cyan
        Copy-Item "$ScriptDir\.env.example" "$ScriptDir\.env"
    } else {
        Write-Warning "[UniPet] .env ve .env.example bulunamadi."
    }
}

Write-Host "[UniPet] Docker servisleri baslatiliyor..." -ForegroundColor Cyan
docker compose -f "$ScriptDir\docker-compose.yml" up -d

Write-Host "[UniPet] Nakama saglik kontrolu bekleniyor (http://127.0.0.1:7350/healthcheck)..." -ForegroundColor Cyan
$timeoutSeconds = 60
$elapsed = 0
$healthy = $false

while ($elapsed -lt $timeoutSeconds) {
    try {
        $response = Invoke-WebRequest -Uri "http://127.0.0.1:7350/healthcheck" -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            $healthy = $true
            break
        }
    } catch {
        # Baglanti henuz hazir degil, donguye devam et
    }
    Start-Sleep -Seconds 2
    $elapsed += 2
    Write-Host "Bekleniyor... ($elapsed/$timeoutSeconds sn)"
}

if ($healthy) {
    Write-Host "[UniPet] Nakama basariyla ayakta ve saglikli! (HTTP 200 OK)" -ForegroundColor Green
    Write-Host "[UniPet] Gelistirici Konsolu: http://127.0.0.1:7351" -ForegroundColor Green
    Write-Host "[UniPet] API Endpoint: http://127.0.0.1:7350" -ForegroundColor Green
    docker compose -f "$ScriptDir\docker-compose.yml" ps
} else {
    Write-Error "[UniPet] Hata: Nakama $timeoutSeconds saniye icinde saglikli duruma gecemedi."
    docker compose -f "$ScriptDir\docker-compose.yml" ps
    docker compose -f "$ScriptDir\docker-compose.yml" logs --tail 30
    exit 1
}
