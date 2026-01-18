#!/bin/bash

# Pfad zum Log-File (konsistent mit anderen Skripten)
LOG="/run/motu-m4/jack-init.log"

# =============================================================================
# JACK-Konfigurationsprofile
# =============================================================================

# Setting 1: Niedrige Latenz (Standard)
SETTING1_RATE=48000
SETTING1_NPERIODS=3
SETTING1_PERIOD=256
SETTING1_DESC="Niedrige Latenz (48kHz, 3x256, ~5.3ms)"

# Setting 2: Mittlere Latenz
SETTING2_RATE=48000
SETTING2_NPERIODS=2
SETTING2_PERIOD=512
SETTING2_DESC="Mittlere Latenz (48kHz, 2x512, ~10.7ms)"

# Setting 3: Ultra-niedrige Latenz
SETTING3_RATE=48000
SETTING3_NPERIODS=3
SETTING3_PERIOD=128
SETTING3_DESC="Ultra-niedrige Latenz (48kHz, 3x128, ~2.7ms)"

# Auswahl des aktiven Settings
# Priorität: 1. Umgebungsvariable JACK_SETTING, 2. Config-Datei, 3. Standard (1)
CONFIG_FILE="/etc/motu-m4/jack-setting.conf"

# Bestimme den tatsächlichen Benutzer und User-Config-Pfad
ACTUAL_USER=""
if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
    ACTUAL_USER="$SUDO_USER"
elif [ "$(whoami)" != "root" ]; then
    ACTUAL_USER="$(whoami)"
else
    # Fallback: Erkenne aktiven Desktop-User
    ACTUAL_USER=$(who | grep "(:" | head -n1 | awk '{print $1}')
fi

if [ -n "$ACTUAL_USER" ] && [ "$ACTUAL_USER" != "root" ]; then
    USER_CONFIG_FILE="/home/$ACTUAL_USER/.config/motu-m4/jack-setting.conf"
else
    USER_CONFIG_FILE="$HOME/.config/motu-m4/jack-setting.conf"
fi

# Funktion zum Lesen der Konfigurationsdatei
read_config_file() {
    local config_file="$1"
    if [ -f "$config_file" ]; then
        local setting=$(grep "^JACK_SETTING=" "$config_file" | cut -d'=' -f2 | tr -d ' ')
        if [ -n "$setting" ]; then
            echo "$setting"
            return 0
        fi
    fi
    return 1
}

# Setting-Auswahl mit Fallback-Mechanismus
JACK_SETTING=${JACK_SETTING:-}
if [ -z "$JACK_SETTING" ]; then
    # Versuche User-Config-Datei zu lesen
    JACK_SETTING=$(read_config_file "$USER_CONFIG_FILE")
fi
if [ -z "$JACK_SETTING" ]; then
    # Versuche System-Config-Datei zu lesen
    JACK_SETTING=$(read_config_file "$CONFIG_FILE")
fi
# Fallback auf Standard-Setting
JACK_SETTING=${JACK_SETTING:-1}

# Aktive Parameter basierend auf Setting setzen
if [ "$JACK_SETTING" = "2" ]; then
    ACTIVE_RATE=$SETTING2_RATE
    ACTIVE_NPERIODS=$SETTING2_NPERIODS
    ACTIVE_PERIOD=$SETTING2_PERIOD
    ACTIVE_DESC=$SETTING2_DESC
elif [ "$JACK_SETTING" = "3" ]; then
    ACTIVE_RATE=$SETTING3_RATE
    ACTIVE_NPERIODS=$SETTING3_NPERIODS
    ACTIVE_PERIOD=$SETTING3_PERIOD
    ACTIVE_DESC=$SETTING3_DESC
else
    ACTIVE_RATE=$SETTING1_RATE
    ACTIVE_NPERIODS=$SETTING1_NPERIODS
    ACTIVE_PERIOD=$SETTING1_PERIOD
    ACTIVE_DESC=$SETTING1_DESC
fi

# Debug-Logging für Konfiguration
log_config_debug() {
    echo "$(date): CONFIG DEBUG - ACTUAL_USER: ${ACTUAL_USER:-unset}" >> $LOG
    echo "$(date): CONFIG DEBUG - USER_CONFIG_FILE: $USER_CONFIG_FILE" >> $LOG
    echo "$(date): CONFIG DEBUG - CONFIG_FILE: $CONFIG_FILE" >> $LOG
    echo "$(date): CONFIG DEBUG - JACK_SETTING env: ${JACK_SETTING:-unset}" >> $LOG
    echo "$(date): CONFIG DEBUG - HOME: $HOME" >> $LOG
    echo "$(date): CONFIG DEBUG - SUDO_USER: ${SUDO_USER:-unset}" >> $LOG
    echo "$(date): CONFIG DEBUG - Current user: $(whoami)" >> $LOG
    if [ -f "$USER_CONFIG_FILE" ]; then
        echo "$(date): CONFIG DEBUG - User config exists: $(cat "$USER_CONFIG_FILE")" >> $LOG
    else
        echo "$(date): CONFIG DEBUG - User config does not exist: $USER_CONFIG_FILE" >> $LOG
    fi
    if [ -f "$CONFIG_FILE" ]; then
        echo "$(date): CONFIG DEBUG - System config exists: $(cat "$CONFIG_FILE")" >> $LOG
    else
        echo "$(date): CONFIG DEBUG - System config does not exist: $CONFIG_FILE" >> $LOG
    fi
    echo "$(date): CONFIG DEBUG - Final JACK_SETTING: $JACK_SETTING" >> $LOG
    echo "$(date): CONFIG DEBUG - Active config: Rate=$ACTIVE_RATE, Periods=$ACTIVE_NPERIODS, Period=$ACTIVE_PERIOD" >> $LOG
}

# Logging-Funktion
log() {
    echo "$(date): $1" >> $LOG
}

# Funktion zum Beenden mit Fehlermeldung
fail() {
    echo "ERROR: $1"
    log "ERROR: $1"
    exit 1
}

# Debug-Informationen loggen
log_config_debug

# Prüfen, ob das M4-Interface verfügbar ist
if ! aplay -l | grep -q "M4"; then
    fail "MOTU M4 Audio-Interface nicht gefunden. Bitte einschalten oder anschließen."
fi

# JACK-Status prüfen und stoppen falls läuft
echo "Prüfe JACK-Status..."
log "Prüfe JACK-Status..."
jack_control status | grep -q "started"
if [ $? -eq 0 ]; then
    echo "JACK läuft - stoppe für Parameterkonfiguration..."
    log "JACK läuft - stoppe für Parameterkonfiguration..."
    jack_control stop
    sleep 1
fi

# JACK-Parameter konfigurieren
echo "Konfiguriere JACK mit $ACTIVE_DESC..."
log "Konfiguriere JACK mit $ACTIVE_DESC (Rate: $ACTIVE_RATE, Perioden: $ACTIVE_NPERIODS, Puffergröße: $ACTIVE_PERIOD)..."

jack_control ds alsa
jack_control dps device hw:M4,0
jack_control dps rate $ACTIVE_RATE
jack_control dps nperiods $ACTIVE_NPERIODS
jack_control dps period $ACTIVE_PERIOD

# JACK starten
echo "Starte JACK-Server mit neuen Parametern..."
log "Starte JACK-Server mit neuen Parametern..."
jack_control start || fail "JACK-Server konnte nicht gestartet werden"

# Status prüfen
jack_control status || fail "JACK-Server läuft nicht korrekt"

# A2J MIDI-Bridge starten (mit RT-Optimierung)
echo "Starte ALSA-MIDI Bridge..."
log "Starte ALSA-MIDI Bridge..."

# Prüfen, ob a2j bereits läuft
a2j_status=$(a2j_control --status 2>&1)
if echo "$a2j_status" | grep -q "bridge is running"; then
    echo "A2J MIDI-Bridge läuft bereits."
    log "A2J MIDI-Bridge läuft bereits."
else
    # Hardware-Export aktivieren
    a2j_control --ehw || echo "Hardware-Export möglicherweise bereits aktiviert"

    # A2J-Bridge starten
    a2j_control --start || echo "A2J MIDI-Bridge konnte nicht gestartet werden, möglicherweise bereits aktiv"

    # Real-Time-Priorität für a2j prüfen und optimieren
    sleep 1  # Kurz warten bis a2j-Prozess läuft
    a2j_pid=$(pgrep a2j)
    if [ -n "$a2j_pid" ]; then
        rt_class=$(ps -o cls= -p $a2j_pid 2>/dev/null | tr -d ' ')
        if [ "$rt_class" = "FF" ]; then
            echo "A2J läuft bereits mit Real-Time-Priorität"
            log "A2J läuft mit Real-Time-Priorität (PID: $a2j_pid)"
        else
            echo "A2J läuft ohne Real-Time-Priorität - das ist normal"
            log "A2J läuft ohne RT-Priorität (PID: $a2j_pid, Klasse: $rt_class)"
        fi
    fi
fi

echo "JACK-Audio-System erfolgreich gestartet mit $ACTIVE_DESC"
log "JACK-Audio-System erfolgreich gestartet mit $ACTIVE_DESC (Rate: $ACTIVE_RATE, Perioden: $ACTIVE_NPERIODS, Puffergröße: $ACTIVE_PERIOD)"
