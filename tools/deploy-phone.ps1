<#
.SYNOPSIS
  USB ile bağlı telefona oyunu derleyip kurar ve açar (Godot editörü gerekmez).
  Godot editöründen anlık deneme için: sağ üstteki Android ikonu (Remote Debug ile, script değişiklikleri canlı yansır).

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools/deploy-phone.ps1          # derle + kur + aç + 10 sn log
  powershell -ExecutionPolicy Bypass -File tools/deploy-phone.ps1 -Shot    # sonunda ekran görüntüsü (C:\Tools\downloads\phone.png)
#>
param([switch]$Shot, [int]$LogSeconds = 10)

$ErrorActionPreference = "Stop"
$Repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$Godot = "C:\Tools\Godot\godot_console.exe"
$Adb = Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools\adb.exe"
$Apk = "C:\Tools\downloads\unipet-local.apk"
$Package = "io.github.talha24052050.unipet"

# adb sunucusu ayrı başlatılır: ilk adb çağrısı onu başlatırsa çıktı kanalını açık tutar, script kapanmaz.
Start-Process -FilePath $Adb -ArgumentList "start-server" -WindowStyle Hidden -Wait -RedirectStandardOutput "$env:TEMP\adb-start.out" -RedirectStandardError "$env:TEMP\adb-start.err"
$devices = (& $Adb devices) | Select-String "\tdevice$"
if (-not $devices) { Write-Host "Telefon bulunamadı: USB hata ayıklama açık mı, 'Bu bilgisayara izin ver' onaylandı mı?" -ForegroundColor Red; exit 1 }

Copy-Item (Join-Path $Repo "tools\ci\export_presets.cfg") (Join-Path $Repo "game\export_presets.cfg") -Force
Write-Host "Derleniyor..."
# Not: godot_console alt süreç açar; çıktısını pipe ile okumak süreci asılı bırakıyor → dosyaya yönlendir.
if (Test-Path $Apk) { Remove-Item $Apk }
$log = Join-Path $env:TEMP "unipet-export.log"
$p = Start-Process -FilePath $Godot -ArgumentList '--headless', '--path', (Join-Path $Repo "game"), '--export-debug', 'Android', $Apk `
    -NoNewWindow -PassThru -RedirectStandardOutput $log -RedirectStandardError "$log.err"
if (-not $p.WaitForExit(300000)) { Stop-Process -Id $p.Id -Force; Write-Host "Derleme zaman aşımı." -ForegroundColor Red; exit 1 }
Get-Content "$log.err", $log -ErrorAction SilentlyContinue | Select-String -Pattern "ERROR" | Select-Object -First 5
if (-not (Test-Path $Apk)) { Write-Host "APK üretilemedi. Log: $log" -ForegroundColor Red; exit 1 }

Write-Host "Kuruluyor..."
$ErrorActionPreference = "Continue"
$out = (& $Adb install -r $Apk 2>&1) -join " "
if ($out -match "INSTALL_FAILED_UPDATE_INCOMPATIBLE") {
    Write-Host "Telefondaki sürüm farklı anahtarla imzalı (GitHub APK'sı). Kaldırılıp yeniden kuruluyor (yerel profil sıfırlanır)." -ForegroundColor Yellow
    & $Adb uninstall $Package | Out-Null
    $out = (& $Adb install $Apk 2>&1) -join " "
}
if ($out -notmatch "Success") { Write-Host "Kurulum başarısız: $out" -ForegroundColor Red; exit 1 }

& $Adb logcat -c
& $Adb shell monkey -p $Package -c android.intent.category.LAUNCHER 1 | Out-Null
Write-Host "Açıldı. $LogSeconds sn log:" -ForegroundColor Green
Start-Sleep -Seconds $LogSeconds
& $Adb logcat -d -s godot:* | Select-String -NotMatch "^-----" | Select-Object -Last 25
if ($Shot) {
    & $Adb shell screencap -p /sdcard/unipet.png | Out-Null
    & $Adb pull /sdcard/unipet.png "C:\Tools\downloads\phone.png" | Out-Null
    Write-Host "Ekran görüntüsü: C:\Tools\downloads\phone.png"
}
