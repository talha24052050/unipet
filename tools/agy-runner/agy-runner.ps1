<#
.SYNOPSIS
  UniPet görev kutusu: agy-tasks/inbox/*.md görevlerini Antigravity CLI (agy) ile çalıştırır,
  sonucu commit'leyip push'lar.

.EXAMPLE
  # Tek görev (Claude Code bunu çağırır)
  powershell -ExecutionPolicy Bypass -File tools/agy-runner/agy-runner.ps1 -Task agy-tasks/inbox/001-ornek.md

.EXAMPLE
  # Sürekli dinle (bulut oturumlarından gelen görevler için); Ctrl+C ile durur
  powershell -ExecutionPolicy Bypass -File tools/agy-runner/agy-runner.ps1 -Watch

.NOTES
  agy ayrı bir konsol penceresinde çalışır: agy -p modu Windows'ta çıktısı yönlendirildiğinde
  takılabildiği/boş döndüğü için stdout yakalanmaz. Sonuç repo'daki değişiklik + rapor dosyasıdır.
  Windows PowerShell 5.1 ile uyumludur.
#>
param(
    [string]$Task,
    [switch]$Watch,
    [int]$IntervalSec = 120,
    [int]$TimeoutMin = 30,
    # agy'nin onay sormadan dosya düzenleyip komut çalıştırabilmesi için. Sadece bu repo içinde çalışır.
    [string]$AgyArgs = "--dangerously-skip-permissions",
    [switch]$NoPush
)

$ErrorActionPreference = "Stop"
$Repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$Inbox = Join-Path $Repo "agy-tasks\inbox"
$Done = Join-Path $Repo "agy-tasks\done"
$Lock = Join-Path $Repo "agy-tasks\.runner.lock"

function Write-Log($msg) { Write-Host ("[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $msg) }

function Git([string[]]$GitArgs) {
    & git.exe -C $Repo @GitArgs
    if ($LASTEXITCODE -ne 0) { throw "git $($GitArgs -join ' ') başarısız ($LASTEXITCODE)" }
}

function Get-Agy {
    $cmd = Get-Command agy -ErrorAction SilentlyContinue
    if (-not $cmd) { throw "agy bulunamadı. Antigravity CLI kurulu ve PATH'te olmalı (bir kez 'agy' çalıştırıp giriş yap)." }
    return $cmd.Source
}

function Invoke-AgyTask([string]$TaskPath) {
    $full = (Resolve-Path (Join-Path $Repo $TaskPath) -ErrorAction SilentlyContinue)
    if (-not $full) { $full = Resolve-Path $TaskPath }
    $full = $full.Path
    $name = [IO.Path]::GetFileNameWithoutExtension($full)
    $rel = $full.Substring($Repo.Length + 1).Replace('\', '/')
    $reportRel = "agy-tasks/done/$name.report.md"
    $report = Join-Path $Repo $reportRel

    $prompt = "Bu repodaki $rel dosyasindaki gorevi yap. CLAUDE.md ve docs/DECISIONS.md kurallarina uy. " +
              "Sadece gorevde izin verilen dosyalara dokun. git commit veya push YAPMA. " +
              "Bitince raporu $reportRel dosyasina Turkce yaz: ne yaptin, hangi dosyalar, test sonucu, belirsiz kalanlar."

    Write-Log "Görev başlıyor: $name"
    $agy = Get-Agy
    $argLine = "-p `"$prompt`" $AgyArgs"
    $proc = Start-Process -FilePath $agy -ArgumentList $argLine -WorkingDirectory $Repo -PassThru
    $finished = $proc.WaitForExit($TimeoutMin * 60 * 1000)
    if (-not $finished) {
        Write-Log "Zaman aşımı ($TimeoutMin dk), agy durduruluyor."
        try { Stop-Process -Id $proc.Id -Force } catch {}
        Add-Content -Path $report -Encoding UTF8 -Value "`n## RUNNER: zaman aşımı ($TimeoutMin dk). Görev yarım kalmış olabilir."
    }
    if (-not (Test-Path $report)) {
        Set-Content -Path $report -Encoding UTF8 -Value "# $name`n`nRUNNER: agy rapor yazmadı (çıkış kodu: $($proc.ExitCode)). Diff'i kontrol et."
    }

    $allowed = Get-AllowedPaths $full
    Git @("mv", $rel, "agy-tasks/done/$name.md")
    # Sadece görevde izin verilen yollar + görev çıktıları commit'lenir; Claude'un aynı anda
    # çalıştığı (henüz commit'lenmemiş) dosyalar agy'nin commit'ine karışmaz.
    $paths = @("agy-tasks/done") + $allowed
    # git'in stderr uyarıları (CRLF vb.) PowerShell 5.1'de durdurucu hata olmasın.
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    foreach ($p in $paths) {
        & git.exe -C $Repo add -A -- $p 2>&1 | Out-Null
        if (Test-Path (Join-Path $Repo "$p.uid")) { & git.exe -C $Repo add -- "$p.uid" 2>&1 | Out-Null }
    }
    $ErrorActionPreference = $prevEap
    & git.exe -C $Repo diff --cached --quiet
    if ($LASTEXITCODE -ne 0) {
        Git @("commit", "-m", "agy: $name")
        if (-not $NoPush) {
            Git @("pull", "--rebase", "--autostash")
            Git @("push")
        }
        Write-Log "Commit'lendi: agy: $name"
    }
}

## Görev dosyasındaki "## Dokunabileceğin dosyalar" bölümünden repo içi yolları çıkarır.
function Get-AllowedPaths([string]$TaskFile) {
    $out = @()
    $inSection = $false
    foreach ($line in Get-Content -Path $TaskFile -Encoding UTF8) {
        if ($line -match '^##\s') { $inSection = $line -match 'Dokunabilece'; continue }
        if (-not $inSection -or $line -notmatch '^\s*-\s') { continue }
        # Satırdaki TÜM `yol` öğeleri (ör. "- `a.gd`, `a.tscn` (yeni)").
        $ms = [regex]::Matches($line, '`([^`]+)`')
        $cands = if ($ms.Count -gt 0) { $ms | ForEach-Object { $_.Groups[1].Value } } else { @(($line -replace '^\s*-\s*', '').Split(' ')[0]) }
        foreach ($c in $cands) {
            $p = $c.Trim().Replace('\', '/')
            if ($p -eq '' -or $p -match '^[A-Za-z]:' -or $p.StartsWith('%') -or $p -notmatch '[/.]') { continue }
            $out += $p
        }
    }
    return $out
}

function Get-InboxTasks {
    Get-ChildItem -Path $Inbox -Filter "*.md" -File | Sort-Object Name |
        ForEach-Object { $_.FullName.Substring($Repo.Length + 1) }
}

if (Test-Path $Lock) { throw "Başka bir runner çalışıyor ($Lock). Emin değilsen dosyayı sil." }
New-Item -ItemType File -Path $Lock | Out-Null
try {
    if ($Task) {
        Invoke-AgyTask $Task
    } elseif ($Watch) {
        Write-Log "Görev kutusu dinleniyor ($IntervalSec sn aralıkla). Durdurmak için Ctrl+C."
        while ($true) {
            try {
                Git @("pull", "--rebase", "--quiet")
                foreach ($t in Get-InboxTasks) { Invoke-AgyTask $t }
            } catch { Write-Log "HATA: $_" }
            Start-Sleep -Seconds $IntervalSec
        }
    } else {
        $pending = @(Get-InboxTasks)
        if ($pending.Count -eq 0) { Write-Log "Inbox boş." }
        foreach ($t in $pending) { Invoke-AgyTask $t }
    }
} finally {
    Remove-Item $Lock -ErrorAction SilentlyContinue
}
