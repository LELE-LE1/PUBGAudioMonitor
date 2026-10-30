$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$sourcePath = Join-Path $projectRoot 'src\PUBGAudioMonitor.ps1'
$releaseDir = Join-Path $projectRoot 'release'
$outputPath = Join-Path $releaseDir 'PUBGAudioMonitor.exe'

if (-not (Get-Command Invoke-PS2EXE -ErrorAction SilentlyContinue)) {
    throw 'PS2EXE is required. Install it with: Install-Module ps2exe -Scope CurrentUser'
}

if (-not (Test-Path -LiteralPath $sourcePath)) {
    throw "Source file not found: $sourcePath"
}

New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null
Invoke-PS2EXE `
    -inputFile $sourcePath `
    -outputFile $outputPath `
    -noConsole `
    -x64 `
    -STA `
    -DPIAware `
    -title 'PUBG Audio Monitor' `
    -description 'PUBG audio profile monitor for Equalizer APO' `
    -product 'PUBG Audio Monitor' `
    -version '1.0.0.0'

Write-Host "Built: $outputPath"
