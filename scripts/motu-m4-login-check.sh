#!/bin/bash

# Pfad zum Log-File
LOG="/run/motu-m4/jack-login-check.log"

# Logging-Funktion
log() {
    echo "$(date): $1" >> $LOG
}

# Sicherstellen, dass das Verzeichnis existiert
mkdir -p /run/motu-m4

log "Login-Check: Starte nach dem Boot"

# Warte, bis der Benutzer vollständig eingeloggt ist
MAX_WAIT=120  # 2 Minuten warten
WAIT_TIME=0

log "Login-Check: Warte auf Benutzer-Login..."

while [ $WAIT_TIME -lt $MAX_WAIT ]; do
    # Prüfe auf eingeloggten Benutzer mit X11-Display
    USER_LOGGED_IN=$(who | grep "(:" | head -n1 | awk '{print $1}')

    if [ -n "$USER_LOGGED_IN" ]; then
        log "Login-Check: Benutzer $USER_LOGGED_IN eingeloggt nach $WAIT_TIME Sekunden"
        break
    fi

    sleep 5
    WAIT_TIME=$((WAIT_TIME + 5))
done

if [ -z "$USER_LOGGED_IN" ]; then
    log "Login-Check: Kein Benutzer nach $MAX_WAIT Sekunden eingeloggt, breche ab"
    exit 1
fi

log "Login-Check: Prüfe auf bereits angeschlossene M4"

# Prüfen, ob eine Trigger-Datei existiert (M4 wurde beim Boot erkannt)
if [ -f /run/motu-m4/m4-detected ]; then
    log "Login-Check: M4-Trigger-Datei gefunden, prüfe Hardware"

    # Prüfen, ob M4 tatsächlich noch angeschlossen ist
    if aplay -l | grep -q "M4"; then
        log "Login-Check: M4 ist angeschlossen, starte JACK"
        # Verwende das User-Script, da wir als Benutzer laufen
        /usr/local/bin/motu-m4-jack-autostart-user.sh >> $LOG 2>&1
    else
        log "Login-Check: M4 nicht mehr angeschlossen"
    fi

    # Trigger-Datei entfernen
    rm -f /run/motu-m4/m4-detected
    log "Login-Check: Trigger-Datei entfernt"
else
    log "Login-Check: Keine M4-Trigger-Datei gefunden"
fi

# 🎵 HINWEIS: Dynamic-Optimizer läuft separat als System-Service
log "Login-Check: Dynamic-Optimizer läuft unabhängig als System-Service"

log "Login-Check: Beendet"
