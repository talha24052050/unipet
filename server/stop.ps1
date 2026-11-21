# UniPet Nakama + Postgres durdurma betigi
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $ScriptDir

Write-Host "[UniPet] Docker servisleri durduruluyor..." -ForegroundColor Cyan
docker compose -f "$ScriptDir\docker-compose.yml" down
Write-Host "[UniPet] Tum servisler durduruldu." -ForegroundColor Green
