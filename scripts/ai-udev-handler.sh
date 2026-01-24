#!/bin/bash

# =============================================================================
# Audio Interface UDEV Event Handler - v3.0
# =============================================================================
# This script is triggered by UDEV when a sound device is added/removed.
# It detects audio interface connections and calls appropriate startup/shutdown
# scripts. Works with any JACK-compatible audio interface.
#
# Parameters from UDEV:
#   $1 (ACTION): "add" or "remove"
#   $2 (KERNEL): Device kernel name (e.g., "controlC0", "card0")
#
# Copyright (C) 2025
# License: GPL-3.0-or-later
# =============================================================================

# UDEV event parameters
ACTION="$1"
KERNEL="$2"

# Log file path - use /run/ai-jack if writable, otherwise /tmp
if mkdir -p /run/ai-jack 2>/dev/null; then
    chmod 777 /run/ai-jack 2>/dev/null
    LOG="/run/ai-jack/jack-udev-handler.log"
else
    mkdir -p /tmp/ai-jack 2>/dev/null
    chmod 777 /tmp/ai-jack 2>/dev/null
    LOG="/tmp/ai-jack/jack-udev-handler.log"
fi

# =============================================================================
# Configuration Loading
# =============================================================================
SYSTEM_CONFIG_FILE="/etc/ai-jack/jack-setting.conf"
DEVICE_PATTERN=""

# Load DEVICE_PATTERN from config if available
if [ -f "$SYSTEM_CONFIG_FILE" ]; then
    DEVICE_PATTERN=$(grep "^DEVICE_PATTERN=" "$SYSTEM_CONFIG_FILE" 2>/dev/null | cut -d'=' -f2 | tr -d ' ')
fi

# =============================================================================
# Auto-Detection Helper
# =============================================================================
# Patterns to filter out internal/onboard audio devices
INTERNAL_DEVICE_PATTERNS="HDA NVidia|HDA Intel|HDA ATI|HDA AMD|HDMI|sof-|PCH"

# Check if any external USB audio interface is connected
any_external_audio_device_present() {
    local aplay_output
    aplay_output=$(LC_ALL=C aplay -l 2>/dev/null)

    # Parse aplay output to find USB audio devices (exclude internal devices)
    while IFS= read -r line; do
        if [[ "$line" =~ ^card\ ([0-9]+):\ ([a-zA-Z0-9_]+)\ \[([^\]]+)\] ]]; then
            local card_name="${BASH_REMATCH[3]}"
            local card_id="${BASH_REMATCH[2]}"

            # Skip internal devices
            if echo "$card_name $card_id" | grep -qiE "$INTERNAL_DEVICE_PATTERNS"; then
                continue
            fi

            # Found an external USB audio device
            log "Found external audio device: $card_name ($card_id)"
            return 0
        fi
    done <<< "$aplay_output"

    return 1
}

# =============================================================================
# Logging and Error Handling
# =============================================================================

# Logging function with error handling
log() {
    echo "$(date): $1" >> $LOG 2>&1
}

# Set error trap to catch failures
set -e
trap 'log "ERROR: Script failed at line $LINENO"' ERR

log "UDEV handler called: ACTION=$ACTION KERNEL=$KERNEL"
log "DEBUG: DEVICE_PATTERN=${DEVICE_PATTERN:-<not set>}"

# =============================================================================
# Device Addition Handler (when audio interface is connected)
# =============================================================================

if [ "$ACTION" = "add" ] && [[ "$KERNEL" == controlC* ]]; then
    log "Sound controller added, checking for audio interface..."

    # Check for logged-in user (flexible X11 session detection)
    log "DEBUG: Running who command..."
    WHO_OUTPUT=$(who 2>&1 || echo "who command failed")
    log "DEBUG: who output: $WHO_OUTPUT"

    # Search for any X11 display session (:0, :1, etc.)
    USER_LOGGED_IN=$(echo "$WHO_OUTPUT" | grep "(:" | head -n1 | awk '{print $1}' || echo "")
    log "DEBUG: Found user: [$USER_LOGGED_IN]"

    if [ -z "$USER_LOGGED_IN" ]; then
        log "No user logged in, creating trigger file"
        touch /run/ai-jack/device-detected
        log "DEBUG: Trigger file created"
        exit 0
    fi

    log "DEBUG: User is logged in, checking hardware"
    sleep 2

    log "DEBUG: Running aplay -l..."
    APLAY_OUTPUT=$(LC_ALL=C aplay -l 2>&1 || echo "aplay command failed")
    log "DEBUG: aplay output: $APLAY_OUTPUT"

    # Check for ANY external audio device (not just the configured pattern)
    # The ai-jack-init.sh script will auto-detect and use the available device
    DEVICE_FOUND=false
    if any_external_audio_device_present; then
        DEVICE_FOUND=true
        log "External audio interface detected"
    fi

    if [ "$DEVICE_FOUND" = true ]; then
        log "Audio interface found, user $USER_LOGGED_IN logged in, starting JACK"
        log "DEBUG: Calling ai-jack-autostart.sh..."
        /usr/local/bin/ai-jack-autostart.sh >> $LOG 2>&1 || log "ERROR: Autostart script failed"

        # NOTE: Dynamic optimizer runs separately as system service
        log "DEBUG: Dynamic optimizer runs independently as system service"
    else
        log "No external audio interface found (internal devices filtered)"
    fi

# =============================================================================
# Device Removal Handler (when audio interface is disconnected)
# =============================================================================

elif [ "$ACTION" = "remove" ] && [[ "$KERNEL" == card* ]]; then
    log "Sound device removed, checking for audio interface..."

    # Remove trigger file
    rm -f /run/ai-jack/device-detected 2>/dev/null

    # Check for logged-in user (flexible search)
    USER_LOGGED_IN=$(who | grep "(:" | head -n1 | awk '{print $1}' || echo "")

    if [ -z "$USER_LOGGED_IN" ]; then
        log "No user logged in, skipping JACK check"
        exit 0
    fi

    sleep 2

    # Check if ANY external audio device is still available
    if any_external_audio_device_present; then
        log "Another external audio device still available, restarting JACK with new device"
        /usr/local/bin/ai-jack-autostart.sh >> $LOG 2>&1 || log "ERROR: Autostart script failed"
    else
        log "No external audio interface remaining, user $USER_LOGGED_IN logged in, stopping JACK"
        /usr/local/bin/ai-jack-shutdown.sh >> $LOG 2>&1 || log "ERROR: Shutdown script failed"
    fi
fi

log "UDEV handler completed"
