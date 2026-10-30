# PUBG Audio Monitor

PUBG Audio Monitor watches `TslGame.exe` and switches Equalizer APO between the selected PUBG profile and the computer's original audio profile.

## Requirements

- Windows 10 or Windows 11
- Equalizer APO installed and configured for the playback device
- PowerShell 5.1 or later for the source version
- These files in the Equalizer APO `config` folder:
  - `config_pubg_original_sound_lock.txt`
  - `config_pubg_v2.txt`
  - `off.txt`
  - the normal Equalizer APO `config.txt`

The monitor checks standard Equalizer APO locations under `Program Files`, the EXE directory, and the existing `D:\游戏\声音调节\config` location. It does not contain or install the Equalizer APO audio driver.

## Build the monitor

Install PS2EXE once:

```powershell
Install-Module ps2exe -Scope CurrentUser
```

Then build the GUI EXE:

```powershell
.\build\build.ps1
```

The output is `release\PUBGAudioMonitor.exe`. The compiled EXE can create its own Windows startup shortcut and does not need the VBS launcher.

## Build the self-extracting setup

The setup build embeds the official Equalizer APO installer, the monitor EXE, the three PUBG profile files, and the default `config.txt` from the local paths below. The default file is only copied when Equalizer APO did not create one, so an existing setup is preserved:

- `D:\游戏\声音调节\EqualizerAPO-x64-1.4.2.exe`
- `D:\游戏\声音调节\config`

Run:

```powershell
.\build\build-bundle.ps1
```

The output is `release\PUBGAudioMonitorSetup.exe`. You can upload that file as a GitHub Release asset. On another computer it extracts its payload to a temporary directory, installs Equalizer APO if needed, copies the profiles, and starts the monitor.

## Equalizer APO distribution

Equalizer APO is a separate third-party system audio driver. The setup can launch its embedded installer, but Windows may request administrator permission and the user must select the playback device in Equalizer APO's Configurator. The setup cannot guarantee a fully portable, restart-free installation.

The profiles reference LoudMax VST2. LoudMax is not embedded because its own documentation prohibits redistribution without the author's permission. The setup checks for `LoudMax64.dll` and warns if it is missing. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Running

1. Run `release\PUBGAudioMonitorSetup.exe`.
2. If prompted, allow the embedded Equalizer APO installer to run as administrator and select the playback device in its Configurator.
3. The setup copies the bundled profiles, installs the monitor under `%LOCALAPPDATA%\PUBGAudioMonitor`, and starts it.
4. Use **Start with Windows** in the monitor window to enable or disable startup.

The monitor changes only Equalizer APO's `config.txt` while PUBG is running and restores `off.txt` after PUBG exits.
