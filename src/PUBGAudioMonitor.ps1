param(
    [switch]$Background
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[System.Windows.Forms.Application]::EnableVisualStyles()

$mutexName = 'Global\PUBGAudioMonitorOriginalSoundLockVisible'
$createdNew = $false
$mutex = New-Object System.Threading.Mutex($true, $mutexName, [ref]$createdNew)

if (-not $createdNew) {
    [System.Windows.Forms.MessageBox]::Show(
        'PUBG audio monitor is already running.',
        'PUBG Audio Monitor',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
    exit 0
}

$scriptPath = $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($scriptPath)) {
    $scriptPath = [Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
}
$scriptRoot = Split-Path -Parent $scriptPath
$logPath = Join-Path $scriptRoot 'pubg_original_sound_lock_monitor.log'
$startupFolder = [Environment]::GetFolderPath('Startup')
$startupShortcutPath = Join-Path $startupFolder 'PUBG Original Sound Lock Monitor.lnk'
$backgroundLauncherPath = Join-Path $scriptRoot 'start_pubg_original_sound_lock_monitor_background.vbs'
$compiledMonitor = [IO.Path]::GetExtension($scriptPath) -ieq '.exe'
$startupTargetPath = if ($compiledMonitor) { $scriptPath } else { $backgroundLauncherPath }
$startupArguments = if ($compiledMonitor) { '-end -Background' } else { '' }

function Write-Log {
    param([string]$Message)
    $line = '{0} {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -LiteralPath $logPath -Value $line -Encoding UTF8
}

function Set-StartupEnabled {
    param([bool]$Enabled)

    try {
        if ($Enabled) {
            if (-not (Test-Path -LiteralPath $startupTargetPath)) {
                throw "Missing startup launcher: $startupTargetPath"
            }

            New-Item -ItemType Directory -Path $startupFolder -Force | Out-Null
            $shell = New-Object -ComObject WScript.Shell
            $shortcut = $shell.CreateShortcut($startupShortcutPath)
            $shortcut.TargetPath = $startupTargetPath
            $shortcut.Arguments = $startupArguments
            $shortcut.WorkingDirectory = $scriptRoot
            $shortcut.WindowStyle = 1
            $shortcut.IconLocation = "$env:SystemRoot\System32\SHELL32.dll,22"
            $shortcut.Save()
            Write-Log 'Startup with Windows enabled.'
        } elseif (Test-Path -LiteralPath $startupShortcutPath) {
            Remove-Item -LiteralPath $startupShortcutPath -Force
            Write-Log 'Startup with Windows disabled.'
        }

        return $true
    } catch {
        [System.Windows.Forms.MessageBox]::Show(
            $_.Exception.Message,
            'PUBG Audio Monitor',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
        Write-Log "ERROR updating startup setting: $($_.Exception.Message)"
        return $false
    }
}

function Find-ConfigDir {
    $candidateDirs = @(
        $scriptRoot,
        $(if (-not [string]::IsNullOrWhiteSpace($env:ProgramFiles)) {
            Join-Path $env:ProgramFiles 'EqualizerAPO\config'
        }),
        $(if (-not [string]::IsNullOrWhiteSpace(${env:ProgramFiles(x86)})) {
            Join-Path ${env:ProgramFiles(x86)} 'EqualizerAPO\config'
        }),
        'D:\游戏\声音调节\config'
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique

    foreach ($candidateDir in $candidateDirs) {
        if (
            (Test-Path -LiteralPath (Join-Path $candidateDir 'config_pubg_original_sound_lock.txt')) -and
            (Test-Path -LiteralPath (Join-Path $candidateDir 'config.txt')) -and
            (Test-Path -LiteralPath (Join-Path $candidateDir 'off.txt'))
        ) {
            return $candidateDir
        }
    }

    $profile = Get-ChildItem -Path 'D:\' -Filter 'config_pubg_original_sound_lock.txt' -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object {
            $dir = $_.DirectoryName
            (Test-Path -LiteralPath (Join-Path $dir 'config.txt')) -and
            (Test-Path -LiteralPath (Join-Path $dir 'off.txt'))
        } |
        Select-Object -First 1

    if ($null -eq $profile) {
        return $null
    }

    return $profile.DirectoryName
}

$configDir = Find-ConfigDir
if ([string]::IsNullOrWhiteSpace($configDir)) {
    [System.Windows.Forms.MessageBox]::Show(
        'Could not find a valid config folder on D: for config_pubg_original_sound_lock.txt.',
        'PUBG Audio Monitor',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
    try { $mutex.ReleaseMutex() } catch {}
    $mutex.Dispose()
    exit 1
}

$configPath = Join-Path $configDir 'config.txt'
$profilePath = Join-Path $configDir 'config_pubg_original_sound_lock.txt'
$v2ProfilePath = Join-Path $configDir 'config_pubg_v2.txt'
$backupPath = Join-Path $configDir 'config_auto_restore.txt'
$offPath = Join-Path $configDir 'off.txt'

if (-not (Test-Path -LiteralPath $profilePath)) {
    [System.Windows.Forms.MessageBox]::Show(
        'Missing config_pubg_original_sound_lock.txt.',
        'PUBG Audio Monitor',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
    try { $mutex.ReleaseMutex() } catch {}
    $mutex.Dispose()
    exit 1
}

if (-not (Test-Path -LiteralPath $v2ProfilePath)) {
    [System.Windows.Forms.MessageBox]::Show(
        'Missing config_pubg_v2.txt.',
        'PUBG Audio Monitor',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
    try { $mutex.ReleaseMutex() } catch {}
    $mutex.Dispose()
    exit 1
}

$notifyIcon = New-Object System.Windows.Forms.NotifyIcon
$notifyIcon.Icon = [System.Drawing.SystemIcons]::Information
$notifyIcon.Text = 'PUBG Audio Monitor'
$notifyIcon.Visible = $true

$form = New-Object System.Windows.Forms.Form
$form.Text = 'PUBG Audio Monitor'
$form.Size = New-Object System.Drawing.Size(460, 320)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.MinimizeBox = $true
$form.TopMost = $false

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Location = New-Object System.Drawing.Point(20, 15)
$titleLabel.Size = New-Object System.Drawing.Size(400, 24)
$titleLabel.Font = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Bold)
$titleLabel.Text = 'PUBG original sound lock'

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Location = New-Object System.Drawing.Point(20, 52)
$statusLabel.Size = New-Object System.Drawing.Size(410, 26)
$statusLabel.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Regular)
$statusLabel.Text = 'Status: starting...'

$detailLabel = New-Object System.Windows.Forms.Label
$detailLabel.Location = New-Object System.Drawing.Point(20, 82)
$detailLabel.Size = New-Object System.Drawing.Size(410, 42)
$detailLabel.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Regular)
$detailLabel.Text = 'Waiting for PUBG. When TslGame starts, audio will switch to original sound lock and restore after exit.'

$profileGroup = New-Object System.Windows.Forms.GroupBox
$profileGroup.Location = New-Object System.Drawing.Point(16, 130)
$profileGroup.Size = New-Object System.Drawing.Size(424, 78)
$profileGroup.Text = 'Audio profile'

$restoreButton = New-Object System.Windows.Forms.Button
$restoreButton.Location = New-Object System.Drawing.Point(12, 26)
$restoreButton.Size = New-Object System.Drawing.Size(124, 32)
$restoreButton.Text = 'Original audio'

$originalButton = New-Object System.Windows.Forms.Button
$originalButton.Location = New-Object System.Drawing.Point(150, 26)
$originalButton.Size = New-Object System.Drawing.Size(124, 32)
$originalButton.Text = 'Original lock'

$v2Button = New-Object System.Windows.Forms.Button
$v2Button.Location = New-Object System.Drawing.Point(288, 26)
$v2Button.Size = New-Object System.Drawing.Size(124, 32)
$v2Button.Text = 'Switch to V2'

$trayButton = New-Object System.Windows.Forms.Button
$trayButton.Location = New-Object System.Drawing.Point(20, 224)
$trayButton.Size = New-Object System.Drawing.Size(124, 32)
$trayButton.Text = 'Hide to tray'

$startupCheckBox = New-Object System.Windows.Forms.CheckBox
$startupCheckBox.Location = New-Object System.Drawing.Point(160, 228)
$startupCheckBox.Size = New-Object System.Drawing.Size(180, 24)
$startupCheckBox.Text = 'Start with Windows'
$startupCheckBox.AutoSize = $true
$startupCheckBox.Checked = Test-Path -LiteralPath $startupShortcutPath

$footerLabel = New-Object System.Windows.Forms.Label
$footerLabel.Location = New-Object System.Drawing.Point(20, 268)
$footerLabel.Size = New-Object System.Drawing.Size(400, 20)
$footerLabel.Font = New-Object System.Drawing.Font('Segoe UI', 8, [System.Drawing.FontStyle]::Italic)
$footerLabel.Text = 'The monitor stays active in the tray when the window is hidden.'

$profileGroup.Controls.AddRange(@(
    $restoreButton,
    $originalButton,
    $v2Button
))

$form.Controls.AddRange(@(
    $titleLabel,
    $statusLabel,
    $detailLabel,
    $profileGroup,
    $trayButton,
    $startupCheckBox,
    $footerLabel
))

$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip
$statusItem = New-Object System.Windows.Forms.ToolStripMenuItem
$statusItem.Text = 'Waiting for PUBG'
$statusItem.Enabled = $false

$showItem = New-Object System.Windows.Forms.ToolStripMenuItem
$showItem.Text = 'Show window'

$originalItem = New-Object System.Windows.Forms.ToolStripMenuItem
$originalItem.Text = 'Switch to original sound lock'

$restoreItem = New-Object System.Windows.Forms.ToolStripMenuItem
$restoreItem.Text = 'Computer original audio'

$v2Item = New-Object System.Windows.Forms.ToolStripMenuItem
$v2Item.Text = 'Switch to V2'

$exitItem = New-Object System.Windows.Forms.ToolStripMenuItem
$exitItem.Text = 'Exit'

[void]$contextMenu.Items.Add($statusItem)
[void]$contextMenu.Items.Add($showItem)
[void]$contextMenu.Items.Add($originalItem)
[void]$contextMenu.Items.Add($v2Item)
[void]$contextMenu.Items.Add($restoreItem)
[void]$contextMenu.Items.Add($exitItem)
$notifyIcon.ContextMenuStrip = $contextMenu

$appContext = New-Object System.Windows.Forms.ApplicationContext
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 2000

$script:profileApplied = $false
$script:activeProfile = ''
$script:lastRunning = $false
$script:allowClose = $false

function Show-Balloon {
    param(
        [string]$Title,
        [string]$Text,
        [System.Windows.Forms.ToolTipIcon]$Icon = [System.Windows.Forms.ToolTipIcon]::Info
    )

    Write-Log $Text
    $notifyIcon.BalloonTipTitle = $Title
    $notifyIcon.BalloonTipText = $Text
    $notifyIcon.BalloonTipIcon = $Icon
    $notifyIcon.ShowBalloonTip(2500)
}

function Update-UiState {
    param(
        [string]$Status,
        [string]$Detail
    )

    $statusLabel.Text = "Status: $Status"
    $detailLabel.Text = $Detail
    $statusItem.Text = $Status
}

function Apply-Profile {
    param(
        [ValidateSet('OriginalSoundLock', 'V2')]
        [string]$Profile = 'OriginalSoundLock',
        [bool]$Notify = $true
    )

    if ($script:profileApplied -and $script:activeProfile -eq $Profile) {
        return
    }

    if (-not $script:profileApplied -and (Test-Path -LiteralPath $configPath)) {
        Copy-Item -LiteralPath $configPath -Destination $backupPath -Force
    } elseif (-not $script:profileApplied -and (Test-Path -LiteralPath $backupPath)) {
        Remove-Item -LiteralPath $backupPath -Force -ErrorAction SilentlyContinue
    }

    $targetPath = if ($Profile -eq 'V2') { $v2ProfilePath } else { $profilePath }
    Copy-Item -LiteralPath $targetPath -Destination $configPath -Force
    $script:profileApplied = $true
    $script:activeProfile = $Profile

    if ($Profile -eq 'V2') {
        Update-UiState 'PUBG running, V2 active' 'V2 is active. Automatic original sound lock is paused until PUBG closes.'
        if ($Notify) {
            Show-Balloon 'PUBG Audio Monitor' 'Audio switched to V2.'
        }
    } else {
        Update-UiState 'PUBG running, sound lock active' 'PUBG detected. Audio has been switched to config_pubg_original_sound_lock.txt.'
        if ($Notify) {
            Show-Balloon 'PUBG Audio Monitor' 'PUBG detected. Original sound lock enabled.'
        }
    }
}

function Restore-Profile {
    param([bool]$Notify = $true)

    if (Test-Path -LiteralPath $offPath) {
        Copy-Item -LiteralPath $offPath -Destination $configPath -Force
    } else {
        Set-Content -LiteralPath $configPath -Value @() -Encoding ASCII
    }

    if (Test-Path -LiteralPath $backupPath) {
        Remove-Item -LiteralPath $backupPath -Force -ErrorAction SilentlyContinue
    }

    $script:profileApplied = $false
    $script:activeProfile = ''
    Update-UiState 'Computer original audio (no EQ)' 'All Equalizer APO tuning is off. The monitor is still ready for PUBG.'

    if ($Notify) {
        Show-Balloon 'PUBG Audio Monitor' 'EQ is off. Computer original audio is active.'
    }
}

function Switch-ManualProfile {
    param(
        [ValidateSet('OriginalSoundLock', 'V2')]
        [string]$Profile
    )

    if (-not $script:lastRunning) {
        [System.Windows.Forms.MessageBox]::Show(
            'PUBG is not running. Start PUBG first, then choose the audio profile.',
            'PUBG Audio Monitor',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
        return
    }

    Apply-Profile -Profile $Profile
}

function Show-MonitorWindow {
    $form.Show()
    $form.WindowState = 'Normal'
    $form.ShowInTaskbar = $true
    $form.Activate()
}

function Hide-ToTray {
    $form.Hide()
    $form.ShowInTaskbar = $false
    Show-Balloon 'PUBG Audio Monitor' 'Monitor is still running in the tray.'
}

$notifyIcon.Add_DoubleClick({
    Show-MonitorWindow
})

$showItem.Add_Click({
    Show-MonitorWindow
})

$restoreItem.Add_Click({
    Restore-Profile
})

$originalItem.Add_Click({
    Switch-ManualProfile -Profile 'OriginalSoundLock'
})

$v2Item.Add_Click({
    Switch-ManualProfile -Profile 'V2'
})

$exitItem.Add_Click({
    Restore-Profile -Notify:$false
    $script:allowClose = $true
    $timer.Stop()
    $notifyIcon.Visible = $false
    $appContext.ExitThread()
})

$restoreButton.Add_Click({
    Restore-Profile
})

$originalButton.Add_Click({
    Switch-ManualProfile -Profile 'OriginalSoundLock'
})

$v2Button.Add_Click({
    Switch-ManualProfile -Profile 'V2'
})

$trayButton.Add_Click({
    Hide-ToTray
})

$script:updatingStartupCheckbox = $false
$startupCheckBox.Add_CheckedChanged({
    if ($script:updatingStartupCheckbox) {
        return
    }

    $desiredState = $startupCheckBox.Checked
    if (-not (Set-StartupEnabled -Enabled $desiredState)) {
        $script:updatingStartupCheckbox = $true
        $startupCheckBox.Checked = -not $desiredState
        $script:updatingStartupCheckbox = $false
    }
})

$form.Add_Resize({
    if ($form.WindowState -eq 'Minimized') {
        Hide-ToTray
    }
})

$form.Add_FormClosing({
    param($sender, $e)
    if (-not $script:allowClose) {
        $e.Cancel = $true
        Hide-ToTray
    }
})

$timer.Add_Tick({
    $running = $null -ne (Get-Process -Name 'TslGame' -ErrorAction SilentlyContinue)

    if ($running -and -not $script:lastRunning) {
        Apply-Profile -Profile 'OriginalSoundLock'
    } elseif (-not $running -and $script:lastRunning) {
        Restore-Profile
    } elseif (-not $running -and -not $script:profileApplied) {
        Update-UiState 'Waiting for PUBG' 'PUBG is not running. Monitor is waiting and ready.'
    }

    $script:lastRunning = $running
})

try {
    Write-Log "Monitor started. Config dir: $configDir"
    $runningNow = $null -ne (Get-Process -Name 'TslGame' -ErrorAction SilentlyContinue)
    $script:lastRunning = $runningNow

    if ($runningNow) {
        Apply-Profile
    } else {
        Update-UiState 'Waiting for PUBG' 'PUBG is not running. Monitor is waiting and ready.'
        Show-Balloon 'PUBG Audio Monitor' 'Visible monitor started. Waiting for PUBG.'
    }

    $timer.Start()
    if (-not $Background) {
        [void]$form.Show()
    }
    [System.Windows.Forms.Application]::Run($appContext)
} catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    [System.Windows.Forms.MessageBox]::Show(
        $_.Exception.Message,
        'PUBG Audio Monitor',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
} finally {
    if ($timer) {
        $timer.Stop()
        $timer.Dispose()
    }

    if ($notifyIcon) {
        $notifyIcon.Visible = $false
        $notifyIcon.Dispose()
    }

    if ($contextMenu) {
        $contextMenu.Dispose()
    }

    if ($form) {
        $form.Dispose()
    }

    if ($mutex) {
        try {
            $mutex.ReleaseMutex()
        } catch {
        }
        $mutex.Dispose()
    }
}
