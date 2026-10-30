param(
    [string]$EqualizerApoInstaller = 'D:\游戏\声音调节\EqualizerAPO-x64-1.4.2.exe',
    [string]$ConfigDir = 'D:\游戏\声音调节\config'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$releaseDir = Join-Path $projectRoot 'release'
$setupSource = Join-Path $projectRoot 'src\PUBGAudioMonitorSetup.ps1'
$monitorPath = Join-Path $releaseDir 'PUBGAudioMonitor.exe'
$setupPath = Join-Path $releaseDir 'PUBGAudioMonitorSetup.exe'

if (-not (Get-Command Invoke-PS2EXE -ErrorAction SilentlyContinue)) {
    throw 'PS2EXE is required. Install it with: Install-Module ps2exe -Scope CurrentUser'
}

foreach ($requiredPath in @(
    $EqualizerApoInstaller,
    $ConfigDir,
    (Join-Path $ConfigDir 'config_pubg_original_sound_lock.txt'),
    (Join-Path $ConfigDir 'config_pubg_v2.txt'),
    (Join-Path $ConfigDir 'off.txt'),
    (Join-Path $ConfigDir 'config.txt')
)) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        throw "Required bundle input not found: $requiredPath"
    }
}

& (Join-Path $PSScriptRoot 'build.ps1')

$embedFiles = @{
    '%TEMP%\PUBGAudioMonitorSetup\EqualizerAPO-x64-1.4.2.exe' = $EqualizerApoInstaller
    '%TEMP%\PUBGAudioMonitorSetup\PUBGAudioMonitor.exe' = $monitorPath
    '%TEMP%\PUBGAudioMonitorSetup\profiles\config_pubg_original_sound_lock.txt' = (Join-Path $ConfigDir 'config_pubg_original_sound_lock.txt')
    '%TEMP%\PUBGAudioMonitorSetup\profiles\config_pubg_v2.txt' = (Join-Path $ConfigDir 'config_pubg_v2.txt')
    '%TEMP%\PUBGAudioMonitorSetup\profiles\off.txt' = (Join-Path $ConfigDir 'off.txt')
    '%TEMP%\PUBGAudioMonitorSetup\profiles\config.txt' = (Join-Path $ConfigDir 'config.txt')
}

Invoke-PS2EXE `
    -inputFile $setupSource `
    -outputFile $setupPath `
    -noConsole `
    -x64 `
    -STA `
    -DPIAware `
    -embedFiles $embedFiles `
    -title 'PUBG Audio Monitor Setup' `
    -description 'Self-extracting setup for PUBG Audio Monitor and Equalizer APO' `
    -product 'PUBG Audio Monitor Setup' `
    -version '1.0.0.0'

Write-Host "Built: $setupPath"
