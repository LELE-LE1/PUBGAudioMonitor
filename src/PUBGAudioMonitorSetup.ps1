param(
    [switch]$Test
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$payloadRoot = Join-Path $env:TEMP 'PUBGAudioMonitorSetup'
$eapoInstallerPath = Join-Path $payloadRoot 'EqualizerAPO-x64-1.4.2.exe'
$monitorPayloadPath = Join-Path $payloadRoot 'PUBGAudioMonitor.exe'
$profilesPath = Join-Path $payloadRoot 'profiles'
$installRoot = Join-Path $env:LOCALAPPDATA 'PUBGAudioMonitor'
$installedMonitorPath = Join-Path $installRoot 'PUBGAudioMonitor.exe'

function Show-Notice {
    param(
        [string]$Text,
        [string]$Title = 'PUBG Audio Monitor Setup',
        [System.Windows.Forms.MessageBoxButtons]$Buttons = [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]$Icon = [System.Windows.Forms.MessageBoxIcon]::Information
    )

    return [System.Windows.Forms.MessageBox]::Show($Text, $Title, $Buttons, $Icon)
}

function Find-EqualizerApoConfigDir {
    $candidateDirs = @(
        $(if (-not [string]::IsNullOrWhiteSpace($env:ProgramFiles)) {
            Join-Path $env:ProgramFiles 'EqualizerAPO\config'
        }),
        $(if (-not [string]::IsNullOrWhiteSpace(${env:ProgramFiles(x86)})) {
            Join-Path ${env:ProgramFiles(x86)} 'EqualizerAPO\config'
        }),
        'D:\游戏\声音调节\config'
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique

    foreach ($candidateDir in $candidateDirs) {
        if (Test-Path -LiteralPath (Join-Path $candidateDir 'config.txt')) {
            return $candidateDir
        }
    }

    foreach ($candidateDir in $candidateDirs) {
        if (Test-Path -LiteralPath $candidateDir -PathType Container) {
            return $candidateDir
        }
    }

    return $null
}

function Find-EqualizerApoConfigurator {
    $candidates = @(
        $(if (-not [string]::IsNullOrWhiteSpace($env:ProgramFiles)) {
            Join-Path $env:ProgramFiles 'EqualizerAPO\Configurator.exe'
        }),
        $(if (-not [string]::IsNullOrWhiteSpace(${env:ProgramFiles(x86)})) {
            Join-Path ${env:ProgramFiles(x86)} 'EqualizerAPO\Configurator.exe'
        })
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    return $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}

if ($Test) {
    $testPath = Join-Path $env:TEMP 'PUBGAudioMonitorSetup-test.log'
    @(
        "EapoInstallerExists=$(Test-Path -LiteralPath $eapoInstallerPath)"
        "MonitorPayloadExists=$(Test-Path -LiteralPath $monitorPayloadPath)"
        "OriginalProfileExists=$(Test-Path -LiteralPath (Join-Path $profilesPath 'config_pubg_original_sound_lock.txt'))"
        "V2ProfileExists=$(Test-Path -LiteralPath (Join-Path $profilesPath 'config_pubg_v2.txt'))"
        "OffProfileExists=$(Test-Path -LiteralPath (Join-Path $profilesPath 'off.txt'))"
        "DefaultConfigExists=$(Test-Path -LiteralPath (Join-Path $profilesPath 'config.txt'))"
    ) | Set-Content -LiteralPath $testPath -Encoding UTF8
    exit 0
}

if (-not (Test-Path -LiteralPath $eapoInstallerPath)) {
    Show-Notice 'The embedded Equalizer APO installer is missing.' 'PUBG Audio Monitor Setup' ([System.Windows.Forms.MessageBoxButtons]::OK) ([System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    exit 1
}

if (-not (Test-Path -LiteralPath $monitorPayloadPath)) {
    Show-Notice 'The embedded monitor executable is missing.' 'PUBG Audio Monitor Setup' ([System.Windows.Forms.MessageBoxButtons]::OK) ([System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    exit 1
}

$configDir = Find-EqualizerApoConfigDir
if ([string]::IsNullOrWhiteSpace($configDir)) {
    $choice = Show-Notice 'Equalizer APO was not found. Install the embedded Equalizer APO package now? Administrator permission is required.' 'PUBG Audio Monitor Setup' ([System.Windows.Forms.MessageBoxButtons]::YesNo) ([System.Windows.Forms.MessageBoxIcon]::Question)
    if ($choice -ne [System.Windows.Forms.DialogResult]::Yes) {
        exit 0
    }

    try {
        Start-Process -FilePath $eapoInstallerPath -Verb RunAs -Wait
    } catch {
        Show-Notice "Equalizer APO installation could not be started.`r`n$($_.Exception.Message)" 'PUBG Audio Monitor Setup' ([System.Windows.Forms.MessageBoxButtons]::OK) ([System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        exit 1
    }

    $configDir = Find-EqualizerApoConfigDir
}

if ([string]::IsNullOrWhiteSpace($configDir)) {
    $configurator = Find-EqualizerApoConfigurator
    if ($configurator) {
        Show-Notice 'Equalizer APO is installed. In the Configurator, select your playback device, apply the change, then close the Configurator. The setup will continue afterwards.' | Out-Null
        Start-Process -FilePath $configurator -Verb RunAs -Wait
        $configDir = Find-EqualizerApoConfigDir
    }
}

if ([string]::IsNullOrWhiteSpace($configDir)) {
    Show-Notice 'Equalizer APO configuration was not found. Run its Configurator, select the playback device, and run this setup again.' 'PUBG Audio Monitor Setup' ([System.Windows.Forms.MessageBoxButtons]::OK) ([System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
    exit 1
}

New-Item -ItemType Directory -Path $installRoot -Force | Out-Null
Copy-Item -LiteralPath $monitorPayloadPath -Destination $installedMonitorPath -Force
Copy-Item -LiteralPath (Join-Path $profilesPath 'config_pubg_original_sound_lock.txt') -Destination (Join-Path $configDir 'config_pubg_original_sound_lock.txt') -Force
Copy-Item -LiteralPath (Join-Path $profilesPath 'config_pubg_v2.txt') -Destination (Join-Path $configDir 'config_pubg_v2.txt') -Force
Copy-Item -LiteralPath (Join-Path $profilesPath 'off.txt') -Destination (Join-Path $configDir 'off.txt') -Force
$defaultConfigPath = Join-Path $configDir 'config.txt'
if (-not (Test-Path -LiteralPath $defaultConfigPath)) {
    Copy-Item -LiteralPath (Join-Path $profilesPath 'config.txt') -Destination $defaultConfigPath -Force
}

$loudMaxPath = Join-Path $configDir '..\Plugins\Loudmax\LoudMax64.dll'
if (-not (Test-Path -LiteralPath $loudMaxPath)) {
    Show-Notice 'The PUBG profiles reference LoudMax64.dll, but it was not found. Install LoudMax VST2 from its official source before using the limiter profiles.' 'PUBG Audio Monitor Setup' ([System.Windows.Forms.MessageBoxButtons]::OK) ([System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
}

Start-Process -FilePath $installedMonitorPath
Show-Notice "Setup complete.`r`nMonitor: $installedMonitorPath`r`nEqualizer APO config: $configDir" | Out-Null
