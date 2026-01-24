# Changelog

All notable changes to this project are documented here.

For detailed release notes, see [GitHub Releases](https://github.com/giang17/ai-jack-starter/releases).

## [v1.0.1](https://github.com/giang17/ai-jack-starter/releases/tag/v1.0.1) - 2026-01-24

### Hotplug Fix

#### Fixed
- **Hot-plug device switching** - Switching between different audio interfaces (e.g., MOTU M4 ↔ Scarlett Solo) now works correctly
- **Device auto-detection** - JACK always uses the currently connected device, regardless of config file

#### Removed
- **Detection Pattern input field** - No longer needed, devices are fully auto-detected
- **"Custom (enter manually)" option** - Removed from device dropdown

#### Changed
- Init script now always auto-detects the available device instead of using config
- udev handler checks for any external USB audio device, not just configured pattern
- GUI shows the actually connected device in status display
- Pattern is auto-extracted from device name (e.g., `hw:M4,0` → `M4`)

---

## [v1.0.0](https://github.com/giang17/ai-jack-starter/releases/tag/v1.0.0) - 2026-01-24

### Initial Release - Universal Audio Interface JACK Starter

Forked from motu-m4-jack-starter and redesigned to support any USB audio interface.

#### Universal Device Support
- **Auto-detection** of any USB audio interface (MOTU, Focusrite, RME, Steinberg, etc.)
- **Dynamic device selection** - choose your interface from a dropdown menu
- **Hardware info display** - shows detected sample rates and channel configuration

#### Features
- Automatic JACK start/stop when audio interface is connected/disconnected
- Hot-plug support via udev rules
- Boot detection - JACK starts after login if interface is already connected
- GTK3 GUI for easy configuration
- Flexible settings: sample rate, buffer size, periods
- Live latency calculation with color coding
- Quick preset buttons (Low, Medium, Ultra-low latency)
- A2J MIDI bridge toggle with status indicator
- Configurable DBus timeout for reliable autostart

#### New App Icon
- Modern design with stylized audio jack plug
- Sound wave indicators and AI badge
- Settings gear icon

#### Technical Improvements
- Locale-independent hardware detection (works with any system language)
- Comprehensive error handling and logging
- ShellCheck-validated shell scripts
