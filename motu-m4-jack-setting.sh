#!/bin/bash

# =============================================================================
# MOTU M4 JACK Setting Helper
# =============================================================================
# Helper script for easy JACK configuration selection
# Usage: ./motu-m4-jack-setting.sh [1|2|3|show|help] [--restart]

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display available settings
show_settings() {
    echo -e "${BLUE}Available JACK Settings:${NC}"
    echo -e "${GREEN}Setting 1 (Default):${NC} Low Latency"
    echo "  - Sample Rate: 48,000 Hz"
    echo "  - Periods: 3"
    echo "  - Buffer Size: 256 frames"
    echo "  - Estimated Latency: ~5.3ms"
    echo ""
    echo -e "${GREEN}Setting 2:${NC} Medium Latency"
    echo "  - Sample Rate: 48,000 Hz"
    echo "  - Periods: 2"
    echo "  - Buffer Size: 512 frames"
    echo "  - Estimated Latency: ~10.7ms"
    echo ""
    echo -e "${GREEN}Setting 3:${NC} Ultra-Low Latency"
    echo "  - Sample Rate: 48,000 Hz"
    echo "  - Periods: 3"
    echo "  - Buffer Size: 128 frames"
    echo "  - Estimated Latency: ~2.7ms"
    echo ""
}

# Function to display current setting
show_current() {
    # Setting selection with fallback mechanism (like in main script)
    local current_setting=${JACK_SETTING:-}

    # Try to read user config file
    if [ -z "$current_setting" ] && [ -f ~/.config/motu-m4/jack-setting.conf ]; then
        current_setting=$(grep "^JACK_SETTING=" ~/.config/motu-m4/jack-setting.conf | cut -d'=' -f2 | tr -d ' ')
    fi

    # Try to read system config file
    if [ -z "$current_setting" ] && [ -f /etc/motu-m4/jack-setting.conf ]; then
        current_setting=$(grep "^JACK_SETTING=" /etc/motu-m4/jack-setting.conf | cut -d'=' -f2 | tr -d ' ')
    fi

    # Fallback to default
    current_setting=${current_setting:-1}

    echo -e "${BLUE}Current Setting:${NC} $current_setting"

    if [ "$current_setting" = "2" ]; then
        echo -e "${GREEN}Active:${NC} Setting 2 - Medium Latency (48kHz, 2x512)"
    elif [ "$current_setting" = "3" ]; then
        echo -e "${GREEN}Active:${NC} Setting 3 - Ultra-Low Latency (48kHz, 3x128)"
    else
        echo -e "${GREEN}Active:${NC} Setting 1 - Low Latency (48kHz, 3x256)"
    fi

    # Show configuration source
    if [ -n "${JACK_SETTING:-}" ]; then
        echo -e "${YELLOW}Source:${NC} Environment variable"
    elif [ -f ~/.config/motu-m4/jack-setting.conf ]; then
        echo -e "${YELLOW}Source:${NC} ~/.config/motu-m4/jack-setting.conf"
    elif [ -f /etc/motu-m4/jack-setting.conf ]; then
        echo -e "${YELLOW}Source:${NC} /etc/motu-m4/jack-setting.conf"
    else
        echo -e "${YELLOW}Source:${NC} Default (no configuration found)"
    fi
}

# Function to set the setting
set_setting() {
    local setting=$1
    local restart_flag=$2

    if [ "$setting" != "1" ] && [ "$setting" != "2" ] && [ "$setting" != "3" ]; then
        echo -e "${RED}Error:${NC} Invalid setting '$setting'. Use 1, 2, or 3."
        exit 1
    fi

    # Set environment variable for current shell session
    export JACK_SETTING=$setting

    # Create user config directory if not present
    mkdir -p ~/.config/motu-m4

    # Persistent configuration in user config file
    echo "JACK_SETTING=$setting" > ~/.config/motu-m4/jack-setting.conf

    # Also set in ~/.bashrc for shell compatibility
    if grep -q "export JACK_SETTING=" ~/.bashrc; then
        sed -i "s/export JACK_SETTING=.*/export JACK_SETTING=$setting/" ~/.bashrc
    else
        echo "export JACK_SETTING=$setting" >> ~/.bashrc
    fi

    echo -e "${GREEN}Setting $setting activated!${NC}"

    if [ "$setting" = "2" ]; then
        echo -e "${YELLOW}Note:${NC} Medium latency selected (48kHz, 2x512)"
    elif [ "$setting" = "3" ]; then
        echo -e "${YELLOW}Note:${NC} Ultra-low latency selected (48kHz, 3x128)"
    else
        echo -e "${YELLOW}Note:${NC} Low latency selected (48kHz, 3x256)"
    fi

    echo ""
    echo "Configuration saved to:"
    echo -e "${BLUE}~/.config/motu-m4/jack-setting.conf${NC}"
    echo -e "${BLUE}~/.bashrc${NC}"
    echo ""
    echo "The setting is immediately active for new JACK starts."

    # Automatic restart if requested
    if [ "$restart_flag" = "--restart" ]; then
        perform_jack_restart
    fi
}

# Function for automatic JACK restart
perform_jack_restart() {
    echo ""
    echo -e "${BLUE}=== Automatic JACK Restart ===${NC}"

    # Check if MOTU M4 is available
    if ! aplay -l | grep -q "M4"; then
        echo -e "${YELLOW}Warning:${NC} MOTU M4 not found - restart skipped"
        echo "Please connect M4 and restart manually with:"
        echo "motu-m4-jack-restart-simple.sh"
        return 1
    fi

    # Check if JACK is running
    local jack_running=false
    if jack_control status 2>/dev/null | grep -q started; then
        jack_running=true
    fi

    if [ "$jack_running" = false ]; then
        echo -e "${YELLOW}Info:${NC} JACK is not running - starting JACK (no restart needed)"
        # Call restart script (also handles case when JACK is not running)
        if [ -f "/usr/local/bin/motu-m4-jack-restart-simple.sh" ]; then
            echo "Executing JACK start..."
            /usr/local/bin/motu-m4-jack-restart-simple.sh
        else
            echo -e "${RED}Error:${NC} motu-m4-jack-restart-simple.sh not found in /usr/local/bin/"
            return 1
        fi
    else
        echo -e "${GREEN}Info:${NC} JACK is running - performing restart to activate new settings"
        # Call restart script
        if [ -f "/usr/local/bin/motu-m4-jack-restart-simple.sh" ]; then
            echo "Executing JACK restart..."
            /usr/local/bin/motu-m4-jack-restart-simple.sh
        else
            echo -e "${RED}Error:${NC} motu-m4-jack-restart-simple.sh not found in /usr/local/bin/"
            return 1
        fi
    fi

    echo -e "${GREEN}JACK restart completed!${NC}"
    echo ""
}

# Function to display help
show_help() {
    echo -e "${BLUE}MOTU M4 JACK Setting Helper${NC}"
    echo ""
    echo "Usage:"
    echo "  $0 [1|2|3|show|current|help] [--restart]"
    echo ""
    echo "Options:"
    echo "  1        - Activate Setting 1 (Low Latency)"
    echo "  2        - Activate Setting 2 (Medium Latency)"
    echo "  3        - Activate Setting 3 (Ultra-Low Latency)"
    echo "  show     - Show all available settings"
    echo "  current  - Show current setting"
    echo "  help     - Show this help"
    echo ""
    echo "Additional Options:"
    echo "  --restart - Automatic JACK restart after setting (only with 1, 2, or 3)"
    echo ""
    echo "Examples:"
    echo "  $0 1              # Activate low latency"
    echo "  $0 2 --restart    # Activate medium latency and apply immediately"
    echo "  $0 3 --restart    # Activate ultra-low latency and apply immediately"
    echo "  $0 show           # Show all settings"
    echo "  $0 current        # Show current setting"
    echo ""
    echo "The selected setting is saved to ~/.config/motu-m4/jack-setting.conf"
    echo "and ~/.bashrc and will be used on the next JACK initialization."
    echo ""
    echo "Configuration priority:"
    echo "  1. Environment variable JACK_SETTING"
    echo "  2. ~/.config/motu-m4/jack-setting.conf"
    echo "  3. /etc/motu-m4/jack-setting.conf (system-wide)"
    echo "  4. Default (Setting 1)"
}

# Main logic
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
        echo -e "${YELLOW}No option specified.${NC}"
        echo ""
        show_current
        echo ""
        show_settings
        echo "Use '$0 help' for more information."
        ;;
    *)
        echo -e "${RED}Error:${NC} Unknown option '$1'"
        echo "Use '$0 help' for more information."
        exit 1
        ;;
esac
