#!/bin/bash

# Parameter von UDEV
ACTION="$1"
KERNEL="$2"

# Pfad zum Log-File
LOG="/run/motu-m4/jack-uvdev-handler.log"

# Sicherstellen, dass das Verzeichnis existiert
mkdir -p /run/motu-m4
chmod 777 /run/motu-m4

# Logging-Funktion mit Error-Handling
log() {
    echo "$(date): $1" >> $LOG 2>&1
}

# Fehler-Handling
set -e
trap 'log "ERROR: Script abgebrochen in Zeile $LINENO"' ERR

log "UDEV-Handler aufgerufen: ACTION=$ACTION KERNEL=$KERNEL"

if [ "$ACTION" = "add" ] && [[ "$KERNEL" == controlC* ]]; then
    log "Sound-Controller hinzugefügt, prüfe auf M4..."

    # Prüfe auf eingeloggten Benutzer (flexiblere Suche nach X11-Sessions)
    log "DEBUG: Prüfe who-Befehl..."
    WHO_OUTPUT=$(who 2>&1 || echo "who-Befehl fehlgeschlagen")
    log "DEBUG: who-Ausgabe: $WHO_OUTPUT"

    # Suche nach beliebigem X11-Display (:0, :1, etc.)
    USER_LOGGED_IN=$(echo "$WHO_OUTPUT" | grep "(:" | head -n1 | awk '{print $1}' || echo "")
    log "DEBUG: Gefundener Benutzer: [$USER_LOGGED_IN]"

    if [ -z "$USER_LOGGED_IN" ]; then
        log "Kein Benutzer eingeloggt, erstelle Trigger-Datei"
        touch /run/motu-m4/m4-detected
        log "DEBUG: Trigger-Datei erstellt"
        exit 0
    fi

    log "DEBUG: Benutzer ist eingeloggt, prüfe Hardware"
    sleep 2

    log "DEBUG: Führe aplay -l aus..."
    APLAY_OUTPUT=$(aplay -l 2>&1 || echo "aplay-Befehl fehlgeschlagen")
    log "DEBUG: aplay-Ausgabe: $APLAY_OUTPUT"

    if echo "$APLAY_OUTPUT" | grep -q "M4"; then
        log "M4 gefunden, Benutzer $USER_LOGGED_IN eingeloggt, starte JACK"
        log "DEBUG: Rufe motu-m4-jack-autostart.sh auf..."
        /usr/local/bin/motu-m4-jack-autostart.sh >> $LOG 2>&1 || log "ERROR: Autostart-Script fehlgeschlagen"

        # 🎵 HINWEIS: Dynamic-Optimizer läuft separat als System-Service
        log "DEBUG: Dynamic-Optimizer läuft unabhängig als System-Service"

        # Asynchrone Ausführung
        # nohup /usr/local/bin/motu-m4-jack-autostart.sh >> $LOG 2>&1 &
    else
        log "Kein M4 gefunden"
    fi

elif [ "$ACTION" = "remove" ] && [[ "$KERNEL" == card* ]]; then
    log "Sound-Karte entfernt, prüfe auf M4..."

    # Trigger-Datei entfernen
    rm -f /run/motu-m4/m4-detected 2>/dev/null

    # Prüfe auf eingeloggten Benutzer (flexiblere Suche)
    USER_LOGGED_IN=$(who | grep "(:" | head -n1 | awk '{print $1}' || echo "")

    if [ -z "$USER_LOGGED_IN" ]; then
        log "Kein Benutzer eingeloggt, überspringe JACK-Shutdown"
        exit 0
    fi

    sleep 2

    if ! aplay -l | grep -q "M4"; then
        log "M4 nicht mehr vorhanden, Benutzer $USER_LOGGED_IN eingeloggt, beende JACK"
        /usr/local/bin/motu-m4-jack-shutdown.sh >> $LOG 2>&1 || log "ERROR: Shutdown-Script fehlgeschlagen"
    else
        log "M4 noch vorhanden"
    fi
fi

log "UDEV-Handler beendet"
