
# MOTU M4 JACK Automatisierungssystem für Ubuntu Studio

## Übersicht

Dieses System bietet eine vollständige Automatisierung des JACK Audio-Servers für das MOTU M4 Audio-Interface unter Ubuntu Studio. Es startet und stoppt JACK automatisch basierend auf der Hardware-Erkennung und dem Benutzer-Login-Status.

## System-Spezifikationen

- **OS**: Ubuntu 24.04 (Ubuntu Studio Audio Config)
- **Kernel**: 6.11.0-1022-oem (Dell OEM-Kernel)
- **Audio-Stack**: Pipewire mit JACK-Kompatibilität
- **Hardware**: MOTU M4 USB Audio Interface
- **Performance**: 10,2ms Latenz, DSP < 4%, keine XRuns

### Kernel-Optimierungen
```bash
# Boot-Parameter
preempt=full threadirqs isolcpus=14-19 nohz_full=14-19 rcu_nocbs=14-19
```

- **CPU-Isolation**: Kerne 14-19 für Audio reserviert
- **IRQ-Threading**: Verbesserte Interrupt-Behandlung
- **No-Hz/RCU**: Reduzierte Timer-Interrupts auf isolierten Kernen

## Systemkomponenten

### 1. UDEV-Regel (`99-motu-m4-jack-combined.rules`)
- Erkennt automatisch das Anschließen/Trennen der MOTU M4
- Ruft entsprechende Handler-Skripte auf
- Erstellt Trigger-Dateien für Boot-Szenarien

### 2. UDEV-Handler (`motu-m4-udev-handler.sh`)
- Läuft als root über UDEV
- Prüft Benutzer-Login-Status
- Verwaltet JACK-Start/-Stop für Hot-Plug-Szenarien

### 3. JACK-Autostart-Skripte
- **`motu-m4-jack-autostart.sh`**: Für root-Kontext (UDEV)
- **`motu-m4-jack-autostart-user.sh`**: Für user-Kontext (systemd)
- **`motu-m4-jack-init.sh`**: Eigentlicher JACK-Start mit Parametern
- **`motu-m4-jack-shutdown.sh`**: Sauberes JACK-Shutdown

### 4. Login-Check-Service (`motu-m4-login-check.service`)
- Systemd user-service
- Prüft nach Login auf bereits angeschlossene M4
- Startet JACK für Boot-Szenarien

### 5. Setting-Helper (`motu-m4-jack-setting.sh`)
- Einfache Auswahl zwischen JACK-Konfigurationen
- Persistente Speicherung in ~/.config/motu-m4/jack-setting.conf
- Übersichtliche Anzeige der verfügbaren Settings

### 6. System-Setting-Helper (`motu-m4-jack-setting-system.sh`)
- Systemweite JACK-Konfiguration (erfordert sudo)
- Konfiguration für alle Benutzer
- Robuste Lösung für UDEV/root-Kontexte

### 7. GUI (`motu-m4-jack-gui.py`)
- Minimalistische GTK3-Oberfläche
- Anzeige von JACK-Status und Hardware-Verbindung
- Auswahl zwischen den 3 JACK-Settings
- Automatischer Restart mit pkexec für Administratorrechte

## JACK-Konfiguration

Das System unterstützt drei vorkonfigurierte JACK-Parameter-Sets:

### Setting 1: Niedrige Latenz (Standard)
```bash
Device: hw:M4,0
Sample Rate: 48000 Hz
Periods: 3
Period Size: 256 frames
Latenz: ~5.3 ms
Backend: ALSA
MIDI: ALSA-JACK Bridge (a2j)
```

### Setting 2: Mittlere Latenz
```bash
Device: hw:M4,0
Sample Rate: 48000 Hz
Periods: 2
Period Size: 512 frames
Latenz: ~10.7 ms
Backend: ALSA
MIDI: ALSA-JACK Bridge (a2j)
```

### Setting 3: Ultra-niedrige Latenz
```bash
Device: hw:M4,0
Sample Rate: 96000 Hz
Periods: 3
Period Size: 128 frames
Latenz: ~1.3 ms
Backend: ALSA
MIDI: ALSA-JACK Bridge (a2j)
```

### Setting-Auswahl

Das System verwendet eine **Prioritätshierarchie** für die Konfiguration:

1. **Umgebungsvariable** `JACK_SETTING` (höchste Priorität)
2. **User-Konfiguration** `~/.config/motu-m4/jack-setting.conf`
3. **Systemweite Konfiguration** `/etc/motu-m4/jack-setting.conf`
4. **Standard-Setting** (Setting 1)

```bash
# Über Umgebungsvariable (temporär)
export JACK_SETTING=1  # Standard (niedrige Latenz)
export JACK_SETTING=2  # Mittlere Latenz
export JACK_SETTING=3  # Ultra-niedrige Latenz

# Mit User-Hilfsskript (persistent)
./motu-m4-jack-setting.sh 1  # Setting 1 aktivieren
./motu-m4-jack-setting.sh 2  # Setting 2 aktivieren (Mittlere Latenz)
./motu-m4-jack-setting.sh 3  # Setting 3 aktivieren

# Mit System-Hilfsskript (systemweit, erfordert sudo - EMPFOHLEN)
sudo ./motu-m4-jack-setting-system.sh 1 --restart  # Niedrige Latenz (~5.3ms)
sudo ./motu-m4-jack-setting-system.sh 2 --restart  # Mittlere Latenz (~10.7ms)
sudo ./motu-m4-jack-setting-system.sh 3 --restart  # Ultra-niedrige Latenz (~1.3ms)
```

### Warum diese Hierarchie?
- **UDEV-Handler** (root-Kontext) kann User's `.bashrc` nicht lesen
- **Systemd-Services** haben eingeschränkte Umgebungsvariablen
- **Konfigurationsdateien** funktionieren in allen Kontexten
- **Flexibilität** für verschiedene Anwendungsfälle

### Automatisches Restart
Beide Setting-Skripte unterstützen automatisches JACK-Restart mit `--restart`:
- **Prüft** ob MOTU M4 verfügbar ist
- **Erkennt** ob JACK läuft (Restart vs. Start)
- **Wendet** neue Einstellungen sofort an
- **Robuste** Fehlerbehandlung

## Unterstützte Szenarien

| Szenario | Verhalten | Komponente |
|----------|-----------|------------|
| **Boot mit M4 an** | Trigger-Datei → JACK nach Login | UDEV + Login-Check |
| **M4 nach Login anschließen** | JACK startet sofort | UDEV-Handler |
| **M4 trennen** | JACK stoppt sauber | UDEV-Handler |
| **Multi-Monitor** | Flexible Display-Erkennung | Alle Komponenten |

## Installation

### 1. Skripte installieren
```bash
sudo cp motu-m4-*.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/motu-m4-*.sh
```

### 1a. GUI installieren (optional)
```bash
# Automatische Installation
sudo ./install-gui.sh

# Oder manuell:
sudo cp motu-m4-jack-gui.py /usr/local/bin/
sudo chmod +x /usr/local/bin/motu-m4-jack-gui.py
sudo cp motu-m4-jack-settings.desktop /usr/share/applications/
```

**Abhängigkeiten für GUI:**
```bash
sudo apt install python3-gi python3-gi-cairo gir1.2-gtk-3.0
```

### 2. UDEV-Regel installieren
```bash
sudo cp 99-motu-m4-jack-combined.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules
```

### 3. Systemd User-Service aktivieren
```bash
mkdir -p ~/.config/systemd/user/
cp motu-m4-login-check.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable motu-m4-login-check.service
```

### 4. JACK-Setting konfigurieren

#### Systemweite Konfiguration (EMPFOHLEN für Produktionseinsatz)
```bash
# Einmal systemweit konfigurieren - funktioniert für alle Szenarien
sudo ./motu-m4-jack-setting-system.sh 2 --restart  # Höhere Latenz (empfohlen)

# Alle verfügbaren Settings:
sudo ./motu-m4-jack-setting-system.sh 1 --restart  # Niedrige Latenz (48kHz, 3x256, ~5.3ms)
sudo ./motu-m4-jack-setting-system.sh 2 --restart  # Mittlere Latenz (48kHz, 2x512, ~10.7ms)  
sudo ./motu-m4-jack-setting-system.sh 3 --restart  # Ultra-niedrige Latenz (96kHz, 3x128, ~1.3ms)

# Status prüfen
sudo ./motu-m4-jack-setting-system.sh current
jack_settings.sh  # Aktuelle JACK-Parameter anzeigen
```

#### User-spezifische Konfiguration (optional)
```bash
# Nur verwenden wenn User-spezifische Settings gewünscht
./motu-m4-jack-setting.sh 2 --restart

# Verfügbare Settings anzeigen
./motu-m4-jack-setting.sh show

# WICHTIG: User-Config überschreibt System-Config!
# Zum Entfernen: rm ~/.config/motu-m4/jack-setting.conf
```

#### Schnellstart (Empfohlene Konfiguration)
```bash
# Für die meisten Anwendungsfälle perfekt:
sudo ./motu-m4-jack-setting-system.sh 2 --restart
```

## Dateien im System

```
/usr/local/bin/
├── motu-m4-udev-handler.sh          # UDEV-Handler (root)
├── motu-m4-jack-autostart.sh        # Autostart für UDEV-Kontext
├── motu-m4-jack-autostart-user.sh   # Autostart für User-Kontext
├── motu-m4-jack-init.sh             # JACK-Initialisierung
├── motu-m4-jack-shutdown.sh         # JACK-Shutdown
├── motu-m4-jack-restart-simple.sh   # JACK-Restart
├── motu-m4-jack-setting.sh          # User-Setting-Helper
├── motu-m4-jack-setting-system.sh   # System-Setting-Helper
├── motu-m4-jack-gui.py              # GTK3 GUI
└── debug-config.sh                  # Konfiguration-Debug-Tool

/usr/share/applications/
└── motu-m4-jack-settings.desktop    # Desktop-Eintrag für GUI

/etc/udev/rules.d/
└── 99-motu-m4-jack-combined.rules   # Hardware-Erkennungsregeln

~/.config/systemd/user/
└── motu-m4-login-check.service      # Login-Check-Service

~/.config/motu-m4/                    # User-Konfiguration
└── jack-setting.conf                # User-JACK-Setting

/etc/motu-m4/                         # System-Konfiguration
└── jack-setting.conf                # System-JACK-Setting

/run/motu-m4/                         # Runtime-Logs
├── jack-autostart.log
├── jack-autostart-user.log
├── jack-login-check.log
├── jack-uvdev-handler.log
├── jack-init.log
└── m4-detected                      # Trigger-Datei
```

## Gelöste technische Herausforderungen

### 1. Display-Erkennung
**Problem**: Dual-Monitor-Setup änderte Display von `:0` zu `:1`
**Lösung**: Flexible Erkennung mit `grep "(:"`

### 2. Benutzerrechte
**Problem**: `runuser` funktioniert nur als root
**Lösung**: Separate Skripte für verschiedene Ausführungskontexte

### 3. Timing-Probleme
**Problem**: DBUS-Socket nicht verfügbar bei frühem Start
**Lösung**: Warteschleifen und Login-Erkennung

### 4. Log-Berechtigungen
**Problem**: Konfliktende Schreibrechte zwischen root und user
**Lösung**: Getrennte Log-Dateien in `/run/motu-m4/`

### 5. Konfiguration in verschiedenen Kontexten
**Problem**: UDEV (root) kann User's `.bashrc` nicht lesen
**Lösung**: Hierarchische Konfiguration über Dateien mit Fallback-Mechanismus

### 6. User-Config vs. System-Config Konflikte
**Problem**: User-Konfiguration überschreibt systemweite Settings unbemerkt
**Lösung**: Debug-Tools und klare Empfehlung für systemweite Konfiguration

## Debugging

### Log-Dateien prüfen
```bash
# Alle Logs anzeigen
ls -la /run/motu-m4/

# UDEV-Handler-Aktivität
cat /run/motu-m4/jack-uvdev-handler.log

# Login-Check-Aktivität
cat /run/motu-m4/jack-login-check.log

# JACK-Start-Details
cat /run/motu-m4/jack-autostart-user.log
```

### JACK-Status prüfen
```bash
jack_control status
jack_control dp  # Parameter anzeigen
jack_settings.sh  # Übersichtliche Parameter-Anzeige
```

### Konfiguration debuggen
```bash
# Vollständige Konfigurationsanalyse:
bash debug-config.sh

# Zeigt Prioritätsauflösung und aktuelle Parameter
```

### Services prüfen
```bash
systemctl --user status motu-m4-login-check.service
```

## Erweiterte Konfiguration

### IRQ-Affinität (optional)
```bash
# set_irq_affinity.sh für optimale IRQ-Verteilung
# Automatisch über systemd-service ausführbar
```

### Alternative Audio-Interfaces
- Skripte können für andere USB-Audio-Interfaces angepasst werden
- `aplay -l | grep "INTERFACE_NAME"` in den Skripten ändern
- JACK-Parameter in `motu-m4-jack-init.sh` anpassen
- Neue Settings über die Variablen am Anfang des Scripts definieren

### JACK-Parameter anpassen
```bash
# In motu-m4-jack-init.sh neue Settings hinzufügen:
SETTING4_RATE=192000
SETTING4_NPERIODS=2
SETTING4_PERIOD=64
SETTING4_DESC="Extreme Latenz (192kHz, 2x64)"
```

### Konfigurationspriorität verstehen
Die **Prioritätshierarchie** macht das System robust für verschiedene Szenarien:

- **Entwicklung/Testing**: Umgebungsvariable für temporäre Änderungen
- **Normaler Betrieb**: User-Konfiguration für persönliche Einstellungen
- **System-Administration**: Systemweite Konfiguration für alle Benutzer
- **Fallback**: Standard-Setting als sichere Basis

### Automatisches Restart verwenden
```bash
# Empfohlene Verwendung (sofortige Anwendung):
sudo ./motu-m4-jack-setting-system.sh 2 --restart

# Ohne automatisches Restart (manuell später):
sudo ./motu-m4-jack-setting-system.sh 2
sudo ./motu-m4-jack-restart-simple.sh
```

### Produktions-Empfehlungen
```bash
# Optimale Konfiguration für die meisten Setups:
sudo ./motu-m4-jack-setting-system.sh 2 --restart

# User-Konfigurationen vermeiden:
rm ~/.config/motu-m4/jack-setting.conf  # Falls vorhanden

# Status regelmäßig prüfen:
bash debug-config.sh
```

### GUI verwenden
```bash
# GUI starten
motu-m4-jack-gui.py

# Oder über Anwendungsmenü:
# Audio/Video → MOTU M4 JACK Settings
```

Die GUI bietet:
- **Status-Anzeige**: JACK-Server-Status und Hardware-Verbindung
- **Setting-Auswahl**: Alle 3 Latenz-Profile mit Details
- **Automatischer Restart**: Optional nach Änderung
- **Administratorrechte**: Via pkexec (Passwort-Abfrage)

## Kompatibilität

- **Ubuntu Studio 24.04+**
- **Pipewire-basierte Audio-Stacks**
- **JACK2 via D-Bus**
- **USB-Audio-Interfaces mit ALSA-Unterstützung**
- **Multi-Monitor-Setups**

---

## Lizenz

Dieses Projekt steht unter der **GNU General Public License v3.0** (GPL-3.0).

Sie können diese Software frei verwenden, modifizieren und weitergeben, solange Sie:
- Die Lizenz beibehalten
- Den Quellcode verfügbar machen
- Änderungen dokumentieren

Siehe [LICENSE](LICENSE) für den vollständigen Lizenztext.

---

**Entwickelt und getestet**: Januar 2026  
**Lizenz**: GPL-3.0-or-later  
**Status**: Produktionsreif ✅
