<#
.SYNOPSIS
  Arkadaşlarla oynamak için sunucuyu başlatır ve telefonlara girilecek adresi yazar.

.EXAMPLE
  # Aynı Wi-Fi'deyseniz
  powershell -ExecutionPolicy Bypass -File server/play-with-friends.ps1

.EXAMPLE
  # Farklı yerlerdeyseniz (Cloudflare geçici tüneli, hesap gerekmez)
  powershell -ExecutionPolicy Bypass -File server/play-with-friends.ps1 -Internet

.NOTES
  Durdurmak: Ctrl+C (tünel kapanır), sonra server/stop.ps1. Windows PowerShell 5.1 uyumlu.
#>
param([switch]$Internet)

$ErrorActionPreference = "Stop"
$ServerDir = $PSScriptRoot
$Cloudflared = "C:\Tools\cloudflared.exe"

# .env yoksa örnekten oluştur (geliştirme girişi açık: herkes mail + 000000 ile girer)
$envFile = Join-Path $ServerDir ".env"
if (-not (Test-Path $envFile)) { Copy-Item (Join-Path $ServerDir ".env.example") $envFile }

# Docker varsa onu, yoksa Docker'sız yerel kurulumu kullan (yönetici izni gerekmez).
if (Get-Command docker -ErrorAction SilentlyContinue) {
    & (Join-Path $ServerDir "start.ps1")
} else {
    Write-Host "Docker yok; Docker'sız yerel sunucu kullanılıyor."
    & (Join-Path $ServerDir "local-nakama.ps1")
}
if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) { exit $LASTEXITCODE }

if (-not $Internet) {
    $ips = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*" -and $_.InterfaceAlias -notmatch "vEthernet|WSL|Loopback|Docker" } |
        Select-Object -ExpandProperty IPAddress
    Write-Host ""
    Write-Host "Sunucu hazır. Telefonlar AYNI Wi-Fi'de olmalı." -ForegroundColor Green
    Write-Host "Giriş ekranındaki 'Sunucu' alanına şunu yazın:" -ForegroundColor Green
    foreach ($ip in $ips) { Write-Host "    $ip" -ForegroundColor Yellow }
    Write-Host "Bağlanamazsanız: Windows Güvenlik Duvarı 7350 portunu engelliyor olabilir. Yönetici PowerShell'de:"
    Write-Host '    New-NetFirewallRule -DisplayName "UniPet Nakama" -Direction Inbound -Protocol TCP -LocalPort 7350 -Action Allow'
    Write-Host "ya da -Internet ile çalıştırın."
    exit 0
}

if (-not (Test-Path $Cloudflared)) {
    Write-Host "cloudflared indiriliyor (~60 MB, bir kez)..."
    New-Item -ItemType Directory -Force (Split-Path $Cloudflared) | Out-Null
    Invoke-WebRequest -UseBasicParsing -OutFile $Cloudflared `
        -Uri "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe"
}

$log = Join-Path $env:TEMP "unipet-tunnel.log"
if (Test-Path $log) { Remove-Item $log }
$proc = Start-Process -FilePath $Cloudflared -ArgumentList "tunnel --no-autoupdate --url http://localhost:7350" `
    -RedirectStandardError $log -NoNewWindow -PassThru
$url = $null
for ($i = 0; $i -lt 60 -and -not $url; $i++) {
    Start-Sleep -Seconds 1
    if (Test-Path $log) {
        $m = Select-String -Path $log -Pattern "https://[a-z0-9-]+\.trycloudflare\.com" | Select-Object -First 1
        if ($m) { $url = $m.Matches[0].Value }
    }
}
if (-not $url) {
    Write-Host "Tünel adresi alınamadı. Log: $log" -ForegroundColor Red
    Stop-Process -Id $proc.Id -ErrorAction SilentlyContinue
    exit 1
}
Write-Host ""
Write-Host "Sunucu internete açık. Giriş ekranındaki 'Sunucu' alanına şunu yazın:" -ForegroundColor Green
Write-Host "    $url" -ForegroundColor Yellow
Write-Host "Bu pencere açık kaldıkça çalışır. Kapatmak için Ctrl+C, sonra server/stop.ps1 (Docker) ya da server/local-nakama.ps1 -Stop."
try { Wait-Process -Id $proc.Id } finally { Stop-Process -Id $proc.Id -ErrorAction SilentlyContinue }
