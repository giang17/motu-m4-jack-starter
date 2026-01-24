# Installation & Configuration Guide

Complete installation, configuration, and troubleshooting guide for the Audio Interface JACK Starter (ai-jack-starter).

## Table of Contents

- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Device Configuration](#device-configuration)
- [JACK Configuration Options](#jack-configuration-options)
- [System Components](#system-components)
- [Troubleshooting](#troubleshooting)
- [Advanced Configuration](#advanced-configuration)

---

## Prerequisites

### System Requirements

- **OS**: Ubuntu Studio 24.04 or later (or any Linux with JACK support)
- **Audio Stack**: JACK2 with DBus support, or Pipewire with JACK compatibility
- **Hardware**: Any JACK-compatible USB audio interface

### Required Packages

```bash
# Core dependencies (usually pre-installed on Ubuntu Studio)
sudo apt install jackd2 a2jmidid bc

# GUI dependencies
sudo apt install python3-gi python3-gi-cairo gir1.2-gtk-3.0
```

### User Groups

Ensure your user is in the `audio` group:

```bash
# Check current groups
groups

# Add to audio group if needed
sudo usermod -aG audio $USER

# Logout and login for changes to take effect
```

---

## Installation

### Quick Installation (Recommended)

The easiest way to install everything is using the automated installer:

```bash
# Clone repository
git clone https://github.com/giang17/ai-jack-starter.git
cd ai-jack-starter

# Run installer
sudo ./install.sh
```

The installer automatically:
- Detects connected audio devices
- Prompts for device configuration (AUDIO_DEVICE and DEVICE_PATTERN)
- Checks dependencies
- Installs all scripts to `/usr/local/bin/`
- Installs the GUI with desktop entry and icon
- Configures UDEV rules
- Sets up Polkit for passwordless operation
- Enables the systemd user service
- Verifies audio group membership
- Offers cleanup of old motu-m4-jack-starter installation (if present)

### Manual Installation

If you prefer manual installation or need more control:

#### Step 1: Clone Repository

```bash
git clone https://github.com/giang17/ai-jack-starter.git
cd ai-jack-starter
```

#### Step 2: Install Scripts

```bash
sudo cp scripts/*.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/ai-*.sh
sudo chmod +x /usr/local/bin/debug-config.sh /usr/local/bin/detect-display.sh
```

#### Step 3: Install UDEV Rule

```bash
sudo cp system/99-ai-jack.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules
sudo udevadm trigger
```

#### Step 4: Enable Login Check Service

```bash
mkdir -p ~/.config/systemd/user/
cp system/ai-login-check.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable ai-login-check.service
```

#### Step 5: Install GUI (Optional)

```bash
sudo cp gui/ai-jack-gui.py /usr/local/bin/
sudo chmod +x /usr/local/bin/ai-jack-gui.py
sudo cp system/ai-jack-settings.desktop /usr/share/applications/
sudo mkdir -p /usr/share/icons/hicolor/scalable/apps/
sudo cp gui/ai-jack-settings.svg /usr/share/icons/hicolor/scalable/apps/
sudo gtk-update-icon-cache /usr/share/icons/hicolor/
```

#### Step 6: Install Polkit Rule (Passwordless Operation)

```bash
sudo cp system/50-ai-jack-settings.rules /etc/polkit-1/rules.d/
```

This allows audio group members to change JACK settings without password prompts.

#### Step 7: Create Configuration

```bash
sudo mkdir -p /etc/ai-jack
sudo cp system/jack-setting.conf.example /etc/ai-jack/jack-setting.conf

# Edit with your device settings
sudo nano /etc/ai-jack/jack-setting.conf
```

---

## Device Configuration

### Finding Your Audio Device

```bash
# List all audio devices
aplay -l
```

Example output:
```
card 0: PCH [HDA Intel PCH], device 0: ALC892 Analog [ALC892 Analog]
card 2: M4 [M4], device 0: USB Audio [USB Audio]
card 3: USB [Scarlett 2i2 USB], device 0: USB Audio [USB Audio]
```

From this output:
- MOTU M4: `AUDIO_DEVICE=hw:M4,0` and `DEVICE_PATTERN=M4`
- Focusrite Scarlett: `AUDIO_DEVICE=hw:USB,0` and `DEVICE_PATTERN=Scarlett`

### Configuration Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `AUDIO_DEVICE` | ALSA device ID for JACK | `hw:M4,0`, `hw:USB,0`, `hw:0,0` |
| `DEVICE_PATTERN` | String to search in `aplay -l` for hardware detection | `M4`, `Scarlett`, `Babyface` |

### Example Configurations

**MOTU M4:**
```bash
AUDIO_DEVICE=hw:M4,0
DEVICE_PATTERN=M4
```

**Focusrite Scarlett 2i2:**
```bash
AUDIO_DEVICE=hw:USB,0
DEVICE_PATTERN=Scarlett
```

**RME Babyface Pro:**
```bash
AUDIO_DEVICE=hw:Babyface,0
DEVICE_PATTERN=Babyface
```

**Generic USB Audio (no auto-detection):**
```bash
AUDIO_DEVICE=hw:0,0
DEVICE_PATTERN=
```

### Configuration Files

The system uses configuration files to store settings:

**System-wide**: `/etc/ai-jack/jack-setting.conf`
**User-specific**: `~/.config/ai-jack/jack-setting.conf`

Complete configuration example:

```bash
# Device Settings
AUDIO_DEVICE=hw:M4,0
DEVICE_PATTERN=M4

# JACK Settings
JACK_RATE=48000
JACK_PERIOD=256
JACK_NPERIODS=2

# ALSA-to-JACK MIDI Bridge
A2J_ENABLE=false

# DBus timeout (seconds)
DBUS_TIMEOUT=30
```

See `system/jack-setting.conf.example` for a complete documented example.

### Using the GUI

```bash
# Start from terminal
ai-jack-gui.py

# Or find in application menu:
# Audio/Video → Audio Interface JACK Settings
```

The GUI provides:
- Device selection dropdown (auto-detects all connected audio devices)
- Dropdown menus for sample rate and buffer size
- Spin button for periods
- Live latency calculation
- Quick preset buttons
- Automatic JACK restart option

### Configuration Priority

The system uses this priority hierarchy:

1. **Environment variables** `JACK_RATE`, `JACK_PERIOD`, `JACK_NPERIODS`, `AUDIO_DEVICE`, `DEVICE_PATTERN` (highest)
2. **User config** `~/.config/ai-jack/jack-setting.conf`
3. **System config** `/etc/ai-jack/jack-setting.conf`
4. **Defaults** (hw:0,0, no pattern, 48000 Hz, 256 frames, 2 periods)

> **Note**: User config overrides system config. Remove user config if unexpected behavior occurs:
> ```bash
> rm ~/.config/ai-jack/jack-setting.conf
> ```

---

## JACK Configuration Options

### ALSA-to-JACK MIDI Bridge (A2J)

The `A2J_ENABLE` setting controls whether the ALSA-to-JACK MIDI bridge (`a2jmidid`) starts automatically.

#### When to Enable (A2J_ENABLE=true)

- You use hardware MIDI controllers that only appear in ALSA
- You need MIDI routing within JACK (e.g., JACK patchbays)
- You use older software that expects JACK MIDI ports

#### When to Disable (A2J_ENABLE=false) - **Recommended for Modern DAWs**

- You use Bitwig Studio or Reaper (they access ALSA MIDI directly)
- You get "MIDI device busy" errors in your DAW
- You don't need MIDI routing in JACK

**How it works when enabled:**

The bridge is started with `--export-hw` flag, which:
- Makes ALSA MIDI devices appear in JACK
- Keeps hardware ports available for ALSA applications
- Reduces "device busy" conflicts

**To change the setting:**

```bash
# Edit system config
sudo nano /etc/ai-jack/jack-setting.conf

# Add or change this line:
A2J_ENABLE=false

# Or for user config:
mkdir -p ~/.config/ai-jack
nano ~/.config/ai-jack/jack-setting.conf
```

Then restart JACK:

```bash
sudo ai-jack-setting-system.sh current --restart
```

**Manual control (for testing):**

```bash
# Start a2jmidid manually
a2j_control --start

# Stop a2jmidid
a2j_control --stop

# Check status
a2j_control --status
```

---

## JACK Audio Settings

### Flexible Configuration (v3.0)

Configure any combination of sample rate, buffer size, periods, and device:

```bash
# Full syntax
sudo ai-jack-setting-system.sh --device=<hw:X,Y> --pattern=<pattern> --rate=<Hz> --period=<frames> --nperiods=<n> [--restart]

# Examples
sudo ai-jack-setting-system.sh --device=hw:M4,0 --pattern=M4 --rate=48000 --period=256 --nperiods=2 --restart
sudo ai-jack-setting-system.sh --rate=96000 --period=128 --nperiods=2 --restart
sudo ai-jack-setting-system.sh --device=hw:Scarlett,0 --pattern=Scarlett --restart
```

### Valid Values

| Parameter | Valid Values | Description |
|-----------|--------------|-------------|
| `--device` | `hw:X,Y` format | ALSA device identifier |
| `--pattern` | any string | Hardware detection pattern |
| `--rate` | 22050, 44100, 48000, 88200, 96000, 176400, 192000 | Sample rate in Hz |
| `--period` | 16, 32, 64, 128, 256, 512, 1024, 2048, 4096 | Buffer size in frames |
| `--nperiods` | 2, 3, 4, 5, 6, 7, 8 | Number of periods |

### Quick Presets

For convenience, presets are still available:

| Preset | Sample Rate | Buffer | Periods | Latency | Use Case |
|--------|-------------|--------|---------|---------|----------|
| 1 | 48,000 Hz | 128 | 2 | ~5.3 ms | General audio work |
| 2 | 48,000 Hz | 256 | 2 | ~10.7 ms | Stable, recommended |
| 3 | 48,000 Hz | 64 | 2 | ~2.7 ms | Optimized systems only |

```bash
# Use preset
sudo ai-jack-setting-system.sh 1 --restart
sudo ai-jack-setting-system.sh 2 --restart
sudo ai-jack-setting-system.sh 3 --restart
```

### Latency Calculation

The formula for calculating audio latency:

```
Latency (ms) = (Buffer Size × Periods) / Sample Rate × 1000
```

Examples:
- 256 × 2 / 48000 × 1000 = **10.7 ms**
- 128 × 2 / 48000 × 1000 = **5.3 ms**
- 64 × 2 / 48000 × 1000 = **2.7 ms**
- 128 × 2 / 96000 × 1000 = **2.7 ms** (higher sample rate, same latency)

### Latency Recommendations

| Latency | Stability | Use Case |
|---------|-----------|----------|
| > 10 ms | Very stable | Recording, mixing, general work |
| 5-10 ms | Stable | Most production tasks |
| 3-5 ms | Good | Live monitoring, virtual instruments |
| < 3 ms | Requires optimization | Real-time performance |

**Warning**: Very low latency (< 3 ms) requires an optimized system. See [Advanced Configuration](#kernel-optimizations-for-ultra-low-latency).

---

## System Components

### Files Overview

| File | Location | Purpose |
|------|----------|---------|
| `ai-udev-handler.sh` | `/usr/local/bin/` | UDEV event handler |
| `ai-jack-autostart.sh` | `/usr/local/bin/` | JACK autostart (root context) |
| `ai-jack-autostart-user.sh` | `/usr/local/bin/` | JACK autostart (user context) |
| `ai-jack-init.sh` | `/usr/local/bin/` | JACK initialization |
| `ai-jack-shutdown.sh` | `/usr/local/bin/` | Clean JACK shutdown |
| `ai-jack-restart.sh` | `/usr/local/bin/` | JACK restart |
| `ai-jack-setting.sh` | `/usr/local/bin/` | User setting helper |
| `ai-jack-setting-system.sh` | `/usr/local/bin/` | System setting helper |
| `ai-jack-gui.py` | `/usr/local/bin/` | GTK3 GUI |
| `99-ai-jack.rules` | `/etc/udev/rules.d/` | UDEV rules |
| `ai-login-check.service` | `~/.config/systemd/user/` | Login check service |
| `50-ai-jack-settings.rules` | `/etc/polkit-1/rules.d/` | Polkit rule |

### Configuration Files

| File | Purpose |
|------|---------|
| `/etc/ai-jack/jack-setting.conf` | System-wide configuration |
| `~/.config/ai-jack/jack-setting.conf` | User-specific configuration |

### Log Files

All logs are stored in `/run/ai-jack/`:

| Log | Content |
|-----|---------|
| `jack-uvdev-handler.log` | UDEV handler activity |
| `jack-autostart.log` | Autostart (root context) |
| `jack-autostart-user.log` | Autostart (user context) |
| `jack-login-check.log` | Login check service |
| `jack-init.log` | JACK initialization details |

### Supported Scenarios

| Scenario | Behavior |
|----------|----------|
| Boot with interface connected | JACK starts after user login |
| Connect interface after login | JACK starts immediately |
| Disconnect interface | JACK stops cleanly |
| Multi-monitor setup | Automatic display detection |

---

## Troubleshooting

### Check JACK Status

```bash
# JACK running?
jack_control status

# Current parameters
jack_control dp

# Detailed status
jack_lsp -c
```

### View Logs

```bash
# All logs
ls -la /run/ai-jack/

# UDEV handler
cat /run/ai-jack/jack-uvdev-handler.log

# JACK start details
cat /run/ai-jack/jack-autostart-user.log

# JACK initialization
cat /run/ai-jack/jack-init.log

# Login check
cat /run/ai-jack/jack-login-check.log
```

### Debug Configuration

```bash
# Full configuration analysis
debug-config.sh

# Shows:
# - Active configuration file
# - Priority resolution
# - Current JACK parameters
```

### Check Services

```bash
# Login check service status
systemctl --user status ai-login-check.service

# Service logs
journalctl --user -u ai-login-check.service
```

### Common Problems

#### JACK won't start

1. Check if audio interface is detected:
   ```bash
   aplay -l | grep -i "your_pattern"
   ```

2. Check JACK errors:
   ```bash
   jack_control status
   cat /run/ai-jack/jack-init.log
   ```

3. Verify user is in audio group:
   ```bash
   groups | grep audio
   ```

4. Verify AUDIO_DEVICE is correct:
   ```bash
   grep AUDIO_DEVICE /etc/ai-jack/jack-setting.conf
   ```

#### XRuns (audio dropouts)

1. Increase latency (use larger buffer or more periods):
   ```bash
   sudo ai-jack-setting-system.sh --rate=48000 --period=512 --nperiods=2 --restart
   ```

2. Check CPU load and disable power management

3. For very low latency, ensure kernel optimizations are in place

#### GUI shows wrong status

1. Click "Refresh" button

2. Verify JACK is actually running:
   ```bash
   jack_control status
   ```

#### Permission denied errors

1. Ensure polkit rule is installed:
   ```bash
   ls /etc/polkit-1/rules.d/50-ai-jack-settings.rules
   ```

2. Verify audio group membership:
   ```bash
   groups | grep audio
   ```

#### Settings not being applied

1. Check for conflicting user config:
   ```bash
   cat ~/.config/ai-jack/jack-setting.conf
   ```

2. Remove user config to use system config:
   ```bash
   rm ~/.config/ai-jack/jack-setting.conf
   ```

---

## Advanced Configuration

### DBus Session Bus Timeout

The autostart scripts wait for the DBus session bus to become available before starting JACK. This is critical for reliable operation, especially at boot time when the user session is still initializing.

**Default timeout**: 30 seconds

**When to increase the timeout**:
- Slow boot times or complex login procedures
- Logs show "DBUS socket not found after X seconds"
- DBus-related errors in `/run/ai-jack/jack-autostart.log`

**Configuration**:

```bash
# In /etc/ai-jack/jack-setting.conf or ~/.config/ai-jack/jack-setting.conf
DBUS_TIMEOUT=60  # Increase to 60 seconds
```

**What happens on timeout**:
- JACK startup continues anyway (best-effort)
- Some features (jack_control, a2jmidid) may not work correctly
- A warning is logged with a hint to increase the timeout

**Troubleshooting DBus issues**:

```bash
# Check autostart logs for DBus warnings
grep -i dbus /run/ai-jack/jack-autostart*.log

# Verify DBus socket exists
ls -la /run/user/$(id -u)/bus
```

---

### Kernel Optimizations (for Ultra-Low Latency)

For latency below 3ms to work reliably, add these kernel boot parameters:

```bash
# /etc/default/grub
GRUB_CMDLINE_LINUX="preempt=full threadirqs"

# Update grub
sudo update-grub
```

For even better performance (advanced users):

```bash
# CPU isolation example (adjust core numbers for your system)
isolcpus=14-19 nohz_full=14-19 rcu_nocbs=14-19
```

### Environment Variable Override

For temporary testing without changing config files:

```bash
# Override device and JACK settings
export AUDIO_DEVICE=hw:M4,0
export DEVICE_PATTERN=M4
export JACK_RATE=96000
export JACK_PERIOD=128
export JACK_NPERIODS=2
ai-jack-init.sh

# Or use preset
export JACK_SETTING=3
ai-jack-init.sh
```

### High Sample Rate Configurations

For professional audio work at higher sample rates:

```bash
# 96 kHz studio quality
sudo ai-jack-setting-system.sh --rate=96000 --period=256 --nperiods=2 --restart
# Latency: ~5.3 ms

# 192 kHz high-resolution
sudo ai-jack-setting-system.sh --rate=192000 --period=128 --nperiods=2 --restart
# Latency: ~1.3 ms (requires optimized system)
```

---

## Migration from motu-m4-jack-starter

If you have an existing motu-m4-jack-starter installation, the new installer offers:

1. **Detection**: Automatically detects old installation files
2. **Cleanup**: Option to remove old scripts, rules, and config
3. **Migration**: Option to copy settings from `/etc/motu-m4/` to `/etc/ai-jack/`

To manually migrate:

```bash
# Copy old configuration
sudo mkdir -p /etc/ai-jack
sudo cp /etc/motu-m4/jack-setting.conf /etc/ai-jack/

# Add device settings to the new config
sudo nano /etc/ai-jack/jack-setting.conf
# Add: AUDIO_DEVICE=hw:M4,0
# Add: DEVICE_PATTERN=M4
```

---

## Uninstallation

```bash
# Remove scripts
sudo rm /usr/local/bin/ai-*.sh
sudo rm /usr/local/bin/ai-jack-gui.py
sudo rm /usr/local/bin/debug-config.sh
sudo rm /usr/local/bin/detect-display.sh

# Remove UDEV rule
sudo rm /etc/udev/rules.d/99-ai-jack.rules
sudo udevadm control --reload-rules

# Remove systemd service
systemctl --user disable ai-login-check.service
rm ~/.config/systemd/user/ai-login-check.service
systemctl --user daemon-reload

# Remove polkit rule
sudo rm /etc/polkit-1/rules.d/50-ai-jack-settings.rules

# Remove desktop entry and icon
sudo rm /usr/share/applications/ai-jack-settings.desktop
sudo rm /usr/share/icons/hicolor/scalable/apps/ai-jack-settings.svg

# Remove configuration
sudo rm -rf /etc/ai-jack/
rm -rf ~/.config/ai-jack/
```

---

## Support

- **Issues**: [GitHub Issues](https://github.com/giang17/ai-jack-starter/issues)
- **License**: GPL-3.0-or-later
