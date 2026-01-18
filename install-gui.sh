#!/bin/bash
# =============================================================================
# MOTU M4 JACK GUI - Installations-Skript
# =============================================================================
# Installiert die minimalistische GUI für MOTU M4 JACK Settings
#
# Verwendung: sudo ./install-gui.sh

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Prüfen ob als root ausgeführt
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Fehler:${NC} Dieses Script erfordert root-Rechte."
    echo "Bitte mit sudo ausführen: sudo $0"
    exit 1
fi

echo -e "${BLUE}=== MOTU M4 JACK GUI Installation ===${NC}"
echo ""

# Script-Verzeichnis ermitteln
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Prüfen ob Python3 und GTK3 verfügbar sind
echo -e "${YELLOW}Prüfe Abhängigkeiten...${NC}"

if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Fehler:${NC} Python3 nicht gefunden"
    echo "Installiere mit: sudo apt install python3"
    exit 1
fi

# GTK3 Python-Bindings prüfen
if ! python3 -c "import gi; gi.require_version('Gtk', '3.0'); from gi.repository import Gtk" 2>/dev/null; then
    echo -e "${RED}Fehler:${NC} Python GTK3 Bindings nicht gefunden"
    echo "Installiere mit: sudo apt install python3-gi python3-gi-cairo gir1.2-gtk-3.0"
    exit 1
fi

echo -e "${GREEN}✓ Python3 und GTK3 verfügbar${NC}"

# polkit prüfen (für pkexec)
if ! command -v pkexec &> /dev/null; then
    echo -e "${YELLOW}Warnung:${NC} pkexec nicht gefunden - GUI benötigt pkexec für sudo-Operationen"
    echo "Installiere mit: sudo apt install policykit-1"
fi

# GUI-Skript installieren
echo ""
echo -e "${YELLOW}Installiere GUI-Skript...${NC}"

if [ -f "$SCRIPT_DIR/motu-m4-jack-gui.py" ]; then
    cp "$SCRIPT_DIR/motu-m4-jack-gui.py" /usr/local/bin/
    chmod +x /usr/local/bin/motu-m4-jack-gui.py
    echo -e "${GREEN}✓ GUI-Skript installiert nach /usr/local/bin/motu-m4-jack-gui.py${NC}"
else
    echo -e "${RED}Fehler:${NC} motu-m4-jack-gui.py nicht gefunden in $SCRIPT_DIR"
    exit 1
fi

# Desktop-Datei installieren
echo ""
echo -e "${YELLOW}Installiere Desktop-Eintrag...${NC}"

if [ -f "$SCRIPT_DIR/motu-m4-jack-settings.desktop" ]; then
    cp "$SCRIPT_DIR/motu-m4-jack-settings.desktop" /usr/share/applications/
    chmod 644 /usr/share/applications/motu-m4-jack-settings.desktop
    echo -e "${GREEN}✓ Desktop-Eintrag installiert${NC}"

    # Desktop-Datenbank aktualisieren
    if command -v update-desktop-database &> /dev/null; then
        update-desktop-database /usr/share/applications/ 2>/dev/null
    fi
else
    echo -e "${YELLOW}Warnung:${NC} motu-m4-jack-settings.desktop nicht gefunden - übersprungen"
fi

# Icon installieren
echo ""
echo -e "${YELLOW}Installiere Icon...${NC}"

if [ -f "$SCRIPT_DIR/motu-m4-jack-settings.svg" ]; then
    # Hicolor Icon-Verzeichnis erstellen falls nicht vorhanden
    mkdir -p /usr/share/icons/hicolor/scalable/apps/
    cp "$SCRIPT_DIR/motu-m4-jack-settings.svg" /usr/share/icons/hicolor/scalable/apps/
    chmod 644 /usr/share/icons/hicolor/scalable/apps/motu-m4-jack-settings.svg
    echo -e "${GREEN}✓ Icon installiert${NC}"

    # Icon-Cache aktualisieren
    if command -v gtk-update-icon-cache &> /dev/null; then
        gtk-update-icon-cache -f /usr/share/icons/hicolor/ 2>/dev/null
    fi
else
    echo -e "${YELLOW}Warnung:${NC} motu-m4-jack-settings.svg nicht gefunden - übersprungen"
    echo "  Die GUI verwendet das Standard-Icon 'audio-card'."
fi

# Polkit-Regel installieren (optional - für passwortlosen Betrieb)
echo ""
echo -e "${YELLOW}Installiere Polkit-Regel...${NC}"

if [ -f "$SCRIPT_DIR/50-motu-m4-jack-settings.rules" ]; then
    cp "$SCRIPT_DIR/50-motu-m4-jack-settings.rules" /etc/polkit-1/rules.d/
    chmod 644 /etc/polkit-1/rules.d/50-motu-m4-jack-settings.rules
    echo -e "${GREEN}✓ Polkit-Regel installiert${NC}"
    echo -e "  ${BLUE}Info:${NC} Mitglieder der 'audio'-Gruppe können Settings ohne Passwort ändern"

    # Prüfen ob aktueller Benutzer in audio-Gruppe ist
    ACTUAL_USER="${SUDO_USER:-$USER}"
    if id -nG "$ACTUAL_USER" | grep -qw "audio"; then
        echo -e "  ${GREEN}✓ Benutzer '$ACTUAL_USER' ist bereits in der 'audio'-Gruppe${NC}"
    else
        echo -e "  ${YELLOW}Hinweis:${NC} Benutzer '$ACTUAL_USER' ist nicht in der 'audio'-Gruppe"
        echo "    Hinzufügen mit: sudo usermod -aG audio $ACTUAL_USER"
        echo "    (Neuanmeldung erforderlich)"
    fi
else
    echo -e "${YELLOW}Warnung:${NC} 50-motu-m4-jack-settings.rules nicht gefunden - übersprungen"
    echo "  Die GUI wird bei jeder Änderung nach dem Passwort fragen."
fi

# Prüfen ob das Setting-Script installiert ist
echo ""
echo -e "${YELLOW}Prüfe System-Skripte...${NC}"

if [ -f "/usr/local/bin/motu-m4-jack-setting-system.sh" ]; then
    echo -e "${GREEN}✓ motu-m4-jack-setting-system.sh gefunden${NC}"
else
    echo -e "${YELLOW}Warnung:${NC} motu-m4-jack-setting-system.sh nicht in /usr/local/bin/"
    echo "  Die GUI benötigt dieses Skript zum Ändern der Einstellungen."
    echo "  Installiere es mit: sudo cp motu-m4-jack-setting-system.sh /usr/local/bin/"
fi

# Zusammenfassung
echo ""
echo -e "${GREEN}=== Installation abgeschlossen ===${NC}"
echo ""
echo -e "Die GUI kann gestartet werden mit:"
echo -e "  ${BLUE}motu-m4-jack-gui.py${NC}"
echo ""
echo -e "Oder über das Anwendungsmenü unter:"
echo -e "  ${BLUE}Audio/Video → MOTU M4 JACK Settings${NC}"
echo ""
if [ -f "/etc/polkit-1/rules.d/50-motu-m4-jack-settings.rules" ]; then
    echo -e "${GREEN}Hinweis:${NC} Polkit-Regel aktiv - kein Passwort erforderlich"
    echo "für Mitglieder der 'audio'-Gruppe."
else
    echo -e "${YELLOW}Hinweis:${NC} Beim Anwenden von Einstellungen wird nach dem"
    echo "Administratorpasswort gefragt (via pkexec)."
fi
