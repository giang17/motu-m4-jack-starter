# Audio Interface JACK Starter (ai-jack-starter)

Automatic JACK audio server management for USB audio interfaces. Starts and stops JACK based on hardware detection and user login status. Works with any JACK-compatible audio interface.

![License](https://img.shields.io/badge/license-GPL--3.0-blue.svg)
![Ubuntu Studio](https://img.shields.io/badge/Ubuntu%20Studio-24.04+-orange.svg)
![Version](https://img.shields.io/badge/version-3.0.0-green.svg)

## Features

- **Automatic JACK start/stop** when audio interface is connected/disconnected
- **Hot-plug support** - connect your interface anytime, JACK starts automatically
- **Boot detection** - JACK starts after login if interface is already connected
- **Device auto-detection** - GUI detects all connected audio devices
- **Flexible JACK configuration** - customize sample rate, buffer size, and periods
- **Optional A2J MIDI bridge** - control ALSA-to-JACK MIDI bridge (disabled by default for modern DAWs)
- **GTK3 GUI** for easy configuration with live latency calculation
- **Quick presets** - Low, Medium, and Ultra-Low latency with one click
- **Passwordless operation** via polkit for audio group members

## Supported Audio Interfaces

Works with any JACK-compatible USB audio interface, including:

| Interface | AUDIO_DEVICE | DEVICE_PATTERN |
|-----------|--------------|----------------|
| MOTU M4 | `hw:M4,0` | `M4` |
| Focusrite Scarlett Solo/2i2 | `hw:USB,0` | `Scarlett` |
| Steinberg UR242 | `hw:UR242,0` | `UR242` |
| RME Babyface Pro | `hw:Babyface,0` | `Babyface` |
| Native Instruments | `hw:Audio,0` | `Komplete` |
| Generic USB Audio | `hw:0,0` | *(leave empty)* |

## Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/giang17/ai-jack-starter.git
cd ai-jack-starter

# 2. Run the installer (installs everything)
sudo ./install.sh

# 3. Configure your device (installer prompts for this)
#    Or configure manually:
sudo ai-jack-setting-system.sh --device=hw:M4,0 --pattern=M4 --restart
```

The installer automatically:
- Detects connected audio devices
- Prompts for device configuration
- Installs all scripts, UDEV rules, GUI, polkit rules, and systemd services

For manual installation, see [INSTALL.md](INSTALL.md).

## Device Configuration

### Finding Your Device

```bash
# List all audio devices
aplay -l
```

Example output:
```
card 0: PCH [HDA Intel PCH], device 0: ALC892 Analog [ALC892 Analog]
card 2: M4 [M4], device 0: USB Audio [USB Audio]
```

From this output:
- `AUDIO_DEVICE=hw:M4,0` (card name "M4", device 0)
- `DEVICE_PATTERN=M4` (unique identifier for detection)

### Configuration File

Edit `/etc/ai-jack/jack-setting.conf`:

```bash
# Device Settings
AUDIO_DEVICE=hw:M4,0
DEVICE_PATTERN=M4

# JACK Settings
JACK_RATE=48000
JACK_PERIOD=256
JACK_NPERIODS=2

# Optional
A2J_ENABLE=false
DBUS_TIMEOUT=30
```

See [jack-setting.conf.example](system/jack-setting.conf.example) for detailed documentation.

## JACK Configuration

### Flexible Configuration (v3.0)

Configure any combination of sample rate, buffer size, and periods:

```bash
# Custom configuration
sudo ai-jack-setting-system.sh --rate=96000 --period=128 --nperiods=2 --restart

# Change device
sudo ai-jack-setting-system.sh --device=hw:Scarlett,0 --pattern=Scarlett --restart

# Show current configuration
sudo ai-jack-setting-system.sh current

# Show all options
sudo ai-jack-setting-system.sh help
```

### Valid Values

| Parameter | Valid Values |
|-----------|--------------|
| Sample Rate | 22050, 44100, 48000, 88200, 96000, 176400, 192000 Hz |
| Buffer Size | 16, 32, 64, 128, 256, 512, 1024, 2048, 4096 frames |
| Periods | 2 - 8 |

### Quick Presets

For convenience, presets are still available:

| Preset | Sample Rate | Buffer | Periods | Latency | Use Case |
|--------|-------------|--------|---------|---------|----------|
| 1 - Low | 48 kHz | 128 | 2 | ~5.3 ms | General audio work |
| 2 - Medium | 48 kHz | 256 | 2 | ~10.7 ms | Stable, recommended |
| 3 - Ultra-Low | 48 kHz | 64 | 2 | ~2.7 ms | Optimized systems only |

```bash
# Use preset (legacy syntax still works)
sudo ai-jack-setting-system.sh 2 --restart
```

### Latency Calculation

```
Latency (ms) = (Buffer Size × Periods) / Sample Rate × 1000
```

## ALSA-to-JACK MIDI Bridge

The GUI includes a toggle for the ALSA-to-JACK MIDI bridge (`a2jmidid`):

**Default: disabled** - Recommended for modern DAWs like Bitwig Studio and Reaper, which access ALSA MIDI directly and may show "device busy" errors when a2jmidid is running.

**Enable it if you:**
- Use hardware MIDI controllers that only appear in ALSA
- Need MIDI routing within JACK (visible in Patchance/Carla)
- Use older software that expects JACK MIDI ports

**How to use:**
1. Open the GUI (`ai-jack-gui.py`)
2. Check/uncheck "Enable ALSA-to-JACK MIDI Bridge"
3. Click "Apply"

When enabled, the bridge uses `--export-hw` flag to keep hardware ports available for both JACK and ALSA applications.

## GUI

Start the GUI via terminal or application menu:

```bash
ai-jack-gui.py
```

Or find it in: **Audio/Video → Audio Interface JACK Settings**

![Audio Interface JACK Settings GUI](gui.png)

### GUI Features

- **Device dropdown** - Select from detected audio interfaces
- **Sample Rate dropdown** - Select from 22050 Hz to 192000 Hz
- **Buffer Size dropdown** - Select from 16 to 4096 frames
- **Periods spinner** - Adjust from 2 to 8 periods
- **Live latency calculation** - See latency update as you change settings
- **Quick preset buttons** - One-click Low, Medium, Ultra-Low latency
- **Status monitoring** - JACK server and hardware connection status
- **Auto-restart option** - Apply changes and restart JACK immediately

## Documentation

See [INSTALL.md](INSTALL.md) for:
- Detailed installation instructions
- Configuration options
- Troubleshooting guide
- Technical details

## Requirements

- Ubuntu Studio 24.04+ (or any Linux with JACK support)
- USB Audio Interface (any JACK-compatible device)
- JACK2 with DBus support (or Pipewire with JACK compatibility)
- Python 3 + GTK3 (for GUI)

## Migration from motu-m4-jack-starter

If you have an existing motu-m4-jack-starter installation, the installer will:
1. Detect old installation files
2. Offer to remove them
3. Optionally migrate your configuration

Your JACK settings will be preserved during migration.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for detailed version history.

For release notes with download links, see [GitHub Releases](https://github.com/giang17/ai-jack-starter/releases).

## License

GPL-3.0-or-later - See [LICENSE](LICENSE)

---

**Status**: Production Ready
