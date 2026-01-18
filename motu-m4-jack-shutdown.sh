#!/bin/bash

# Pfad zum Log-File (konsistent mit anderen Skripten)
LOG="/run/motu-m4/jack-autostart.log"

# Logging-Funktion
log() {
    echo "$(date): $1" >> $LOG
}

log "M4 Audio Interface entfernt - Beende JACK"

# Dynamische Erkennung des aktiven Benutzers
ACTIVE_USER=$(who | grep "(:" | head -n1 | awk '{print $1}')

# Fallback: Wenn kein aktiver User erkannt wird, versuche über SUDO_USER
if [ -z "$ACTIVE_USER" ]; then
    ACTIVE_USER="${SUDO_USER:-}"
fi

if [ -z "$ACTIVE_USER" ]; then
    log "WARNUNG: Kein aktiver Benutzer erkannt - versuche trotzdem fortzufahren"
    USER="$USER"
else
    USER="$ACTIVE_USER"
fi
USER_ID=$(id -u "$USER" 2>/dev/null || echo "")

log "Beende JACK für Benutzer: $USER"

# Umgebungsvariablen setzen
export DISPLAY=:1
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$USER_ID/bus
export XDG_RUNTIME_DIR=/run/user/$USER_ID

# JACK und A2J sauber beenden - ohne su
runuser -l $USER -c "
# Zuerst A2J MIDI-Bridge sauber beenden
if a2j_control --status 2>/dev/null | grep -q 'bridge is running'; then
    echo 'Beende A2J MIDI-Bridge sauber...'
    a2j_control --stop 2>/dev/null || true
    sleep 1
fi

# Dann JACK sauber beenden
jack_control stop 2>/dev/null || true
sleep 2

# Prüfen ob Prozesse noch laufen und sanft beenden
if pgrep jackdbus >/dev/null 2>&1; then
    echo 'Beende jackdbus sanft...'
    killall jackdbus 2>/dev/null || true
    sleep 1
fi

if pgrep jackd >/dev/null 2>&1; then
    echo 'Beende jackd sanft...'
    killall jackd 2>/dev/null || true
    sleep 1
fi

if pgrep a2jmidid >/dev/null 2>&1; then
    echo 'Beende a2jmidid sanft...'
    killall a2jmidid 2>/dev/null || true
    sleep 1
fi

# Falls Prozesse immer noch laufen, hart beenden
if pgrep 'jack|a2j' >/dev/null 2>&1; then
    echo 'Erzwinge Beendigung verbliebener Prozesse...'
    killall -9 jackdbus jackd a2jmidid 2>/dev/null || true
fi

# Temporäre Dateien bereinigen
rm -f /tmp/jack-*-$USER_ID 2>/dev/null
rm -f /dev/shm/jack-*-$USER_ID 2>/dev/null
" >> $LOG 2>&1

# Kurze Pause, damit alle Ressourcen freigegeben werden
sleep 2

log "JACK-Server wurde vollständig beendet und bereinigt"
