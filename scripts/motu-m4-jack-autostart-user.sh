#!/bin/bash

# =============================================================================
# MOTU M4 JACK Autostart Script - User Context
# =============================================================================
# Called from motu-m4-login-check.service after user login.
# Runs in user context with appropriate environment variables already set.
#
# Copyright (C) 2025
# License: GPL-3.0-or-later
# =============================================================================

# Log file path
LOG="/run/motu-m4/jack-autostart-user.log"

# =============================================================================
# Logging Function
# =============================================================================

log() {
    echo "$(date): $1" >> $LOG
}

log "M4 Audio Interface detected - Starting JACK directly (user context)"

# =============================================================================
# User and Session Information
# =============================================================================

# Current user information
USER=$(whoami)
USER_ID=$(id -u)

log "User: $USER (ID: $USER_ID)"

# =============================================================================
# Configuration Loading
# =============================================================================

# Load DBus timeout from configuration (default: 30 seconds)
DBUS_TIMEOUT=30

# Try system config first
if [ -f "/etc/motu-m4/jack-setting.conf" ]; then
    CONF_TIMEOUT=$(grep -E "^DBUS_TIMEOUT=" /etc/motu-m4/jack-setting.conf 2>/dev/null | cut -d= -f2)
    if [ -n "$CONF_TIMEOUT" ]; then
        DBUS_TIMEOUT="$CONF_TIMEOUT"
        log "Loaded DBUS_TIMEOUT=$DBUS_TIMEOUT from system config"
    fi
fi

# User config overrides system config
USER_CONFIG="$HOME/.config/motu-m4/jack-setting.conf"
if [ -f "$USER_CONFIG" ]; then
    CONF_TIMEOUT=$(grep -E "^DBUS_TIMEOUT=" "$USER_CONFIG" 2>/dev/null | cut -d= -f2)
    if [ -n "$CONF_TIMEOUT" ]; then
        DBUS_TIMEOUT="$CONF_TIMEOUT"
        log "Loaded DBUS_TIMEOUT=$DBUS_TIMEOUT from user config"
    fi
fi

# =============================================================================
# DBus Session Bus Verification
# =============================================================================

# Wait for DBUS socket to become available
DBUS_SOCKET="/run/user/$USER_ID/bus"
WAIT_TIME=0

log "Checking DBUS socket: $DBUS_SOCKET (timeout: ${DBUS_TIMEOUT}s)"
while [ ! -e "$DBUS_SOCKET" ] && [ $WAIT_TIME -lt $DBUS_TIMEOUT ]; do
    log "Waiting for DBUS socket... ($WAIT_TIME/${DBUS_TIMEOUT}s)"
    sleep 1
    WAIT_TIME=$((WAIT_TIME + 1))
done

if [ ! -e "$DBUS_SOCKET" ]; then
    log "WARNING: DBUS socket not found after $DBUS_TIMEOUT seconds. Continuing anyway."
    log "HINT: Increase DBUS_TIMEOUT in /etc/motu-m4/jack-setting.conf if this happens frequently."
fi

log "Starting JACK directly for user: $USER"

# =============================================================================
# User Context Execution
# =============================================================================

# Set environment variables
export DISPLAY=:1
export DBUS_SESSION_BUS_ADDRESS=unix:path=$DBUS_SOCKET
export XDG_RUNTIME_DIR=/run/user/$USER_ID

# Execute JACK initialization script directly (we are already the correct user)
/usr/local/bin/motu-m4-jack-init.sh >> $LOG 2>&1

log "JACK startup command completed"
