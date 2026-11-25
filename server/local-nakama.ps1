<#
.SYNOPSIS
  Docker OLMADAN yerel Nakama + Postgres (yönetici izni gerekmez). İlk çalıştırmada ~320 MB indirir.
  Kurulum: C:\Tools\nakama-local (repo dışında). Postgres 5433, Nakama 7350/7351.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File server/local-nakama.ps1          # başlat (arka planda)
  powershell -ExecutionPolicy Bypass -File server/local-nakama.ps1 -Stop    # durdur
#>
param([switch]$Stop)

$ErrorActionPreference = "Stop"
$Root = "C:\Tools\nakama-local"
$NakamaVersion = "3.26.0"
$PgUrl = "https://get.enterprisedb.com/postgresql/postgresql-16.6-1-windows-x64-binaries.zip"
$ServerDir = $PSScriptRoot
$PgCtl = Join-Path $Root "pgsql\bin\pg_ctl.exe"
$Db = "postgres@127.0.0.1:5433/nakama?sslmode=disable"

if ($Stop) {
    Get-Process nakama -ErrorAction SilentlyContinue | Stop-Process -Force
    if (Test-Path $PgCtl) { & $PgCtl stop -D (Join-Path $Root "pgdata") -m fast | Out-Null }
    Write-Host "Durduruldu."
    exit 0
}

New-Item -ItemType Directory -Force $Root | Out-Null
$nakamaExe = Join-Path $Root "nakama.exe"
if (-not (Test-Path $nakamaExe)) {
    Write-Host "Nakama indiriliyor (~15 MB)..."
    $tgz = Join-Path $Root "nakama.tar.gz"
    Invoke-WebRequest -UseBasicParsing -OutFile $tgz -Uri "https://github.com/heroiclabs/nakama/releases/download/v$NakamaVersion/nakama-$NakamaVersion-windows-amd64.tar.gz"
    tar -xzf $tgz -C $Root
    Remove-Item $tgz
}
if (-not (Test-Path $PgCtl)) {
    Write-Host "Postgres indiriliyor (~300 MB, bir kez)..."
    $zip = Join-Path $Root "pg.zip"
    Invoke-WebRequest -UseBasicParsing -OutFile $zip -Uri $PgUrl
    Expand-Archive -Path $zip -DestinationPath $Root -Force
    Remove-Item $zip
}
$pgData = Join-Path $Root "pgdata"
if (-not (Test-Path $pgData)) {
    & (Join-Path $Root "pgsql\bin\initdb.exe") -D $pgData -U postgres -A trust --encoding=UTF8 --locale=C | Out-Null
}
& $PgCtl status -D $pgData *> $null
if ($LASTEXITCODE -ne 0) {
    # postgres.exe kendi (gizli) konsoluyla bağımsız başlatılır. pg_ctl ile bu scriptin konsoluna bağlı başlatınca,
    # script penceresi kapandıktan sonra Postgres'in açtığı alt işlemler 0xC0000142 (DLL başlatma) ile çöküyor ve
    # veritabanı kapanıyordu (2026-11-22 arkadaşlarla testte 2 kez).
    $pgExe = Join-Path $Root "pgsql\bin\postgres.exe"
    Start-Process -FilePath $pgExe -ArgumentList @("-D", "`"$pgData`"", "-p", "5433") -WindowStyle Hidden `
        -RedirectStandardError (Join-Path $Root "pg.log") | Out-Null
    # pg_isready.exe Smart App Control tarafından engelleniyor: portu doğrudan yokla
    for ($i = 0; $i -lt 30; $i++) {
        $c = New-Object System.Net.Sockets.TcpClient
        try { $c.Connect("127.0.0.1", 5433); $c.Close(); break } catch { Start-Sleep -Seconds 1 }
    }
}
# Yerel programların stderr'ı (ör. "veritabanı zaten var") PowerShell 5.1'de durdurucu hata olmasın.
$ErrorActionPreference = "Continue"
& (Join-Path $Root "pgsql\bin\createdb.exe") -h 127.0.0.1 -p 5433 -U postgres nakama 2>&1 | Out-Null
& $nakamaExe migrate up --database.address $Db 2>&1 | Out-Null
$ErrorActionPreference = "Stop"

Get-Process nakama -ErrorAction SilentlyContinue | Stop-Process -Force
$envVars = @{ UNIPET_DEV_AUTH = "true"; UNIPET_ROOM_CAPACITY = "40"; UNIPET_FREE_CHAT = "true"; UNIPET_REQUIRE_SCHOOL_EMAIL = "false" }
$envFile = Join-Path $ServerDir ".env"
if (Test-Path $envFile) {
    foreach ($line in Get-Content $envFile) {
        if ($line -match '^\s*(UNIPET_[A-Z_]+|SUPABASE_[A-Z_]+)\s*=\s*(.*)$') { $envVars[$Matches[1]] = $Matches[2].Trim() }
    }
}
# Ortam değişkenleri ayrı YAML ile verilir: birden çok --runtime.env parametresinde Nakama sadece birini tutuyor.
$envYml = Join-Path $Root "runtime-env.yml"
$lines = @("runtime:", "  env:")
foreach ($k in $envVars.Keys) { if ($envVars[$k] -ne "") { $lines += "    - `"$k=$($envVars[$k])`"" } }
[IO.File]::WriteAllLines($envYml, $lines)
$nkArgs = @("--config", (Join-Path $ServerDir "nakama\local.yml"), "--config", $envYml, "--database.address", $Db,
    "--runtime.path", (Join-Path $ServerDir "nakama\modules"), "--socket.server_key", "unipet-dev-server-key",
    "--logger.file", (Join-Path $Root "nakama.log"), "--logger.stdout", "false")
# Postgres zorla kapatıldıysa açılışta kurtarma yapar ("database system is starting up"); port açık olsa da Nakama
# bağlanamayıp kapanır. Nakama düşerse birkaç kez yeniden dene (2026-11-23).
for ($try = 0; $try -lt 4; $try++) {
    $proc = Start-Process -FilePath $nakamaExe -ArgumentList $nkArgs -WindowStyle Hidden -PassThru
    for ($i = 0; $i -lt 30; $i++) {
        Start-Sleep -Seconds 1
        try { if ((Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:7350/healthcheck" -TimeoutSec 2).StatusCode -eq 200) { Write-Host "Nakama hazır: http://127.0.0.1:7350 (konsol: http://127.0.0.1:7351, admin/password)" -ForegroundColor Green; exit 0 } } catch {}
        if ($proc.HasExited) { break }
    }
    Start-Sleep -Seconds 3
}
Write-Host "Nakama başlamadı. Log: $Root\nakama.log" -ForegroundColor Red
exit 1
