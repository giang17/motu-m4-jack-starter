#!/bin/bash

# =============================================================================
# MOTU M4 JACK Setting Helper
# =============================================================================
# Hilfsskript zur einfachen Auswahl der JACK-Konfiguration
# Verwendung: ./motu-m4-jack-setting.sh [1|2|3|show|help] [--restart]

# Farben für die Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funktion zur Anzeige der verfügbaren Settings
show_settings() {
    echo -e "${BLUE}Verfügbare JACK-Settings:${NC}"
    echo -e "${GREEN}Setting 1 (Standard):${NC} Niedrige Latenz"
    echo "  - Sample Rate: 48.000 Hz"
    echo "  - Perioden: 2"
    echo "  - Puffergröße: 256 frames"
    echo "  - Geschätzte Latenz: ~10.7ms"
    echo ""
    echo -e "${GREEN}Setting 2:${NC} Höhere Latenz"
    echo "  - Sample Rate: 44.100 Hz"
    echo "  - Perioden: 2"
    echo "  - Puffergröße: 512 frames"
    echo "  - Geschätzte Latenz: ~23.2ms"
    echo ""
    echo -e "${GREEN}Setting 3:${NC} Ultra-niedrige Latenz"
    echo "  - Sample Rate: 96.000 Hz"
    echo "  - Perioden: 3"
    echo "  - Puffergröße: 128 frames"
    echo "  - Geschätzte Latenz: ~4.0ms"
    echo ""
}

# Funktion zur Anzeige des aktuellen Settings
show_current() {
    # Setting-Auswahl mit Fallback-Mechanismus (wie im main script)
    local current_setting=${JACK_SETTING:-}

    # Versuche User-Config-Datei zu lesen
    if [ -z "$current_setting" ] && [ -f ~/.config/motu-m4/jack-setting.conf ]; then
        current_setting=$(grep "^JACK_SETTING=" ~/.config/motu-m4/jack-setting.conf | cut -d'=' -f2 | tr -d ' ')
    fi

    # Versuche System-Config-Datei zu lesen
    if [ -z "$current_setting" ] && [ -f /etc/motu-m4/jack-setting.conf ]; then
        current_setting=$(grep "^JACK_SETTING=" /etc/motu-m4/jack-setting.conf | cut -d'=' -f2 | tr -d ' ')
    fi

    # Fallback auf Standard
    current_setting=${current_setting:-1}

    echo -e "${BLUE}Aktuelles Setting:${NC} $current_setting"

    if [ "$current_setting" = "2" ]; then
        echo -e "${GREEN}Aktiv:${NC} Setting 2 - Höhere Latenz (44.1kHz, 2x512)"
    elif [ "$current_setting" = "3" ]; then
        echo -e "${GREEN}Aktiv:${NC} Setting 3 - Ultra-niedrige Latenz (96kHz, 3x128)"
    else
        echo -e "${GREEN}Aktiv:${NC} Setting 1 - Niedrige Latenz (48kHz, 2x256)"
    fi

    # Quelle der Konfiguration anzeigen
    if [ -n "${JACK_SETTING:-}" ]; then
        echo -e "${YELLOW}Quelle:${NC} Umgebungsvariable"
    elif [ -f ~/.config/motu-m4/jack-setting.conf ]; then
        echo -e "${YELLOW}Quelle:${NC} ~/.config/motu-m4/jack-setting.conf"
    elif [ -f /etc/motu-m4/jack-setting.conf ]; then
        echo -e "${YELLOW}Quelle:${NC} /etc/motu-m4/jack-setting.conf"
    else
        echo -e "${YELLOW}Quelle:${NC} Standard (keine Konfiguration gefunden)"
    fi
}

# Funktion zum Setzen des Settings
set_setting() {
    local setting=$1
    local restart_flag=$2

    if [ "$setting" != "1" ] && [ "$setting" != "2" ] && [ "$setting" != "3" ]; then
        echo -e "${RED}Fehler:${NC} Ungültiges Setting '$setting'. Verwende 1, 2 oder 3."
        exit 1
    fi

    # Umgebungsvariable für die aktuelle Shell-Session setzen
    export JACK_SETTING=$setting

    # User-Config-Verzeichnis erstellen falls nicht vorhanden
    mkdir -p ~/.config/motu-m4

    # Persistente Konfiguration in User-Config-Datei
    echo "JACK_SETTING=$setting" > ~/.config/motu-m4/jack-setting.conf

    # Auch in ~/.bashrc setzen für Shell-Kompatibilität
    if grep -q "export JACK_SETTING=" ~/.bashrc; then
        sed -i "s/export JACK_SETTING=.*/export JACK_SETTING=$setting/" ~/.bashrc
    else
        echo "export JACK_SETTING=$setting" >> ~/.bashrc
    fi

    echo -e "${GREEN}Setting $setting aktiviert!${NC}"

    if [ "$setting" = "2" ]; then
        echo -e "${YELLOW}Hinweis:${NC} Höhere Latenz gewählt (44.1kHz, 2x512)"
    elif [ "$setting" = "3" ]; then
        echo -e "${YELLOW}Hinweis:${NC} Ultra-niedrige Latenz gewählt (96kHz, 3x128)"
    else
        echo -e "${YELLOW}Hinweis:${NC} Niedrige Latenz gewählt (48kHz, 2x256)"
    fi

    echo ""
    echo "Konfiguration gespeichert in:"
    echo -e "${BLUE}~/.config/motu-m4/jack-setting.conf${NC}"
    echo -e "${BLUE}~/.bashrc${NC}"
    echo ""
    echo "Das Setting ist sofort aktiv für neue JACK-Starts."

    # Automatisches Restart wenn gewünscht
    if [ "$restart_flag" = "--restart" ]; then
        perform_jack_restart
    fi
}

# Funktion für automatisches JACK-Restart
perform_jack_restart() {
    echo ""
    echo -e "${BLUE}=== Automatisches JACK-Restart ===${NC}"

    # Prüfen ob MOTU M4 verfügbar ist
    if ! aplay -l | grep -q "M4"; then
        echo -e "${YELLOW}Warnung:${NC} MOTU M4 nicht gefunden - Restart übersprungen"
        echo "Bitte M4 anschließen und manuell restarten mit:"
        echo "motu-m4-jack-restart-simple.sh"
        return 1
    fi

    # Prüfen ob JACK läuft
    local jack_running=false
    if jack_control status 2>/dev/null | grep -q started; then
        jack_running=true
    fi

    if [ "$jack_running" = false ]; then
        echo -e "${YELLOW}Info:${NC} JACK läuft nicht - starte nur JACK (kein Restart nötig)"
        # Restart-Script aufrufen (behandelt auch den Fall wenn JACK nicht läuft)
        if [ -f "/usr/local/bin/motu-m4-jack-restart-simple.sh" ]; then
            echo "Führe JACK-Start aus..."
            /usr/local/bin/motu-m4-jack-restart-simple.sh
        else
            echo -e "${RED}Fehler:${NC} motu-m4-jack-restart-simple.sh nicht gefunden in /usr/local/bin/"
            return 1
        fi
    else
        echo -e "${GREEN}Info:${NC} JACK läuft - führe Restart durch um neue Einstellungen zu aktivieren"
        # Restart-Script aufrufen
        if [ -f "/usr/local/bin/motu-m4-jack-restart-simple.sh" ]; then
            echo "Führe JACK-Restart aus..."
            /usr/local/bin/motu-m4-jack-restart-simple.sh
        else
            echo -e "${RED}Fehler:${NC} motu-m4-jack-restart-simple.sh nicht gefunden in /usr/local/bin/"
            return 1
        fi
    fi

    echo -e "${GREEN}JACK-Restart abgeschlossen!${NC}"
    echo ""
}

# Funktion zur Anzeige der Hilfe
show_help() {
    echo -e "${BLUE}MOTU M4 JACK Setting Helper${NC}"
    echo ""
    echo "Verwendung:"
    echo "  $0 [1|2|3|show|current|help] [--restart]"
    echo ""
    echo "Optionen:"
    echo "  1        - Setting 1 aktivieren (Niedrige Latenz)"
    echo "  2        - Setting 2 aktivieren (Höhere Latenz)"
    echo "  3        - Setting 3 aktivieren (Ultra-niedrige Latenz)"
    echo "  show     - Alle verfügbaren Settings anzeigen"
    echo "  current  - Aktuelles Setting anzeigen"
    echo "  help     - Diese Hilfe anzeigen"
    echo ""
    echo "Zusätzliche Optionen:"
    echo "  --restart - Automatisches JACK-Restart nach dem Setzen (nur mit 1, 2 oder 3)"
    echo ""
    echo "Beispiele:"
    echo "  $0 1              # Niedrige Latenz aktivieren"
    echo "  $0 2 --restart    # Höhere Latenz aktivieren und sofort anwenden"
    echo "  $0 3 --restart    # Ultra-niedrige Latenz aktivieren und sofort anwenden"
    echo "  $0 show           # Alle Settings anzeigen"
    echo "  $0 current        # Aktuelles Setting anzeigen"
    echo ""
    echo "Das gewählte Setting wird in ~/.config/motu-m4/jack-setting.conf"
    echo "und ~/.bashrc gespeichert und bei der nächsten JACK-Initialisierung verwendet."
    echo ""
    echo "Konfigurationspriorität:"
    echo "  1. Umgebungsvariable JACK_SETTING"
    echo "  2. ~/.config/motu-m4/jack-setting.conf"
    echo "  3. /etc/motu-m4/jack-setting.conf (systemweit)"
    echo "  4. Standard (Setting 1)"
}

# Hauptlogik
case "$1" in
    "1"|"2"|"3")
        set_setting "$1" "$2"
        ;;
    "show")
        show_settings
        ;;
    "current")
        show_current
        ;;
    "help"|"-h"|"--help")
        show_help
        ;;
    "")
        echo -e "${YELLOW}Keine Option angegeben.${NC}"
        echo ""
        show_current
        echo ""
        show_settings
        echo "Verwende '$0 help' für weitere Informationen."
        ;;
    *)
        echo -e "${RED}Fehler:${NC} Unbekannte Option '$1'"
        echo "Verwende '$0 help' für weitere Informationen."
        exit 1
        ;;
esac
