<#
.SYNOPSIS
  Cloudflare geçici tünelini açar ve izler; ev interneti kopup tünel toparlanamazsa yeniden açar.

.DESCRIPTION
  Sunucunun (Nakama, 127.0.0.1:7350) zaten çalıştığını varsayar (server/local-nakama.ps1).
  Her 30 sn'de tünel adresine sağlık isteği atar; 3 kez üst üste başarısızsa cloudflared'ı yeniden başlatır.
  Geçici tünelin adresi her açılışta DEĞİŞİR: güncel adres C:\Tools\nakama-local\tunnel-url.txt dosyasına yazılır
  ve ekrana basılır (arkadaşlara yeni adres verilmeli: oyunda Ayarlar → Sunucu adresi → Bağlan).

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File server/tunnel-watchdog.ps1
#>
$ErrorActionPreference = "Continue"
$Cloudflared = "C:\Tools\cloudflared.exe"
$UrlFile = "C:\Tools\nakama-local\tunnel-url.txt"
$Log = Join-Path $env:TEMP "unipet-tunnel-watchdog.log"
$CheckEvery = 30
$FailLimit = 3

function Start-Tunnel {
    Get-Process cloudflared -ErrorAction SilentlyContinue | Stop-Process -Force
    if (Test-Path $Log) { Remove-Item $Log -ErrorAction SilentlyContinue }
    Start-Process -FilePath $Cloudflared -ArgumentList "tunnel --no-autoupdate --protocol http2 --metrics 127.0.0.1:20241 --url http://localhost:7350" `
        -RedirectStandardError $Log -WindowStyle Hidden | Out-Null
    for ($i = 0; $i -lt 60; $i++) {
        Start-Sleep -Seconds 1
        $m = Select-String -Path $Log -Pattern "https://(?!api\.)[a-z0-9-]+\.trycloudflare\.com" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($m) {
            $url = $m.Matches[0].Value  # cloudflared hata mesajındaki api.trycloudflare.com adresi tünel sayılmamalı (2026-11-23 hatası)
            Set-Content -Path $UrlFile -Value $url -Encoding ascii
            Write-Host ("[{0:HH:mm:ss}] Tünel açık: {1}" -f (Get-Date), $url) -ForegroundColor Green
            return $url
        }
    }
    Write-Host ("[{0:HH:mm:ss}] Tünel adresi alınamadı (internet yok mu?), tekrar denenecek." -f (Get-Date)) -ForegroundColor Yellow
    return $null
}

# Sağlık: cloudflared'ın kendi /ready ucu (Cloudflare'a bağlı mı) + yerel Nakama. Eskiden tünel adresine
# istek atılıyordu; yerel DNS yeni trycloudflare adını dakikalarca çözemeyince sağlam tünel boşuna yenileniyordu.
function Test-Url([string]$url) {
    if (-not $url) { return $false }
    try {
        $ready = (Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:20241/ready" -TimeoutSec 10).StatusCode -eq 200
        $nakama = (Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:7350/healthcheck" -TimeoutSec 10).StatusCode -eq 200
        return $ready -and $nakama
    } catch { return $false }
}

$url = $null
if (Test-Path $UrlFile) { $url = (Get-Content $UrlFile -ErrorAction SilentlyContinue | Select-Object -First 1) }
if (-not (Test-Url $url)) { $url = Start-Tunnel }
$fails = 0
while ($true) {
    Start-Sleep -Seconds $CheckEvery
    if (Test-Url $url) { $fails = 0; continue }
    $fails++
    Write-Host ("[{0:HH:mm:ss}] Tünel yanıt vermiyor ({1}/{2})" -f (Get-Date), $fails, $FailLimit)
    if ($fails -ge $FailLimit) {
        $new = Start-Tunnel
        if ($new) { $url = $new; $fails = 0 }
    }
}
