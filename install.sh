#!/bin/sh

# ==================================================
# OpenVPN Client Config Installer (Refactored)
# Designed for Red Lion SN/RAM (snupdate)
# ==================================================

TMP_DIR="/tmp"
WORK_DIR="$TMP_DIR/ovpn_install_$$"
OVPN_DIR="/etc/openvpn"
VALIDATOR_NAME="ovpn_validation_checker.sh"

LOG_PREFIX="[OpenVPN Installer]"

log() {
    echo "$LOG_PREFIX $1"
}

fail() {
    log "ERROR: $1"
    cleanup
    exit 1
}

cleanup() {
    [ -d "$WORK_DIR" ] && rm -rf "$WORK_DIR"
}

# ==================================================
# 0. Validate input (ZIP file from snupdate)
# ==================================================

PACKAGE="$1"

if [ -z "$PACKAGE" ]; then
    fail "No package argument supplied"
fi

if [ ! -f "$PACKAGE" ]; then
    fail "Package not found: $PACKAGE"
fi

log "Starting installation using package: $PACKAGE"

# ==================================================
# 1. Prepare working directory
# ==================================================

rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR" || fail "Failed to create working directory"

log "Created working directory: $WORK_DIR"

# ==================================================
# 2. Extract package contents
# ==================================================

log "Extracting package..."

unzip -o "$PACKAGE" -d "$WORK_DIR" >/dev/null 2>&1 \
    || fail "Failed to extract package"

log "Extraction complete"

# Debug (can comment out later)
log "Extracted contents:"
ls -R "$WORK_DIR"

# ==================================================
# 3. Locate config file
# ==================================================

CONFIG_FILES=$(find "$WORK_DIR" -type f \( -name "*.ovpn" -o -name "*.conf" \))

CONFIG_COUNT=$(echo "$CONFIG_FILES" | wc -w)

if [ "$CONFIG_COUNT" -eq 0 ]; then
    fail "No .ovpn or .conf file found in package"
elif [ "$CONFIG_COUNT" -gt 1 ]; then
    fail "Multiple config files found — only one is allowed"
fi

CONFIG_FILE=$(echo "$CONFIG_FILES" | head -n1)

log "Found config: $CONFIG_FILE"

# ==================================================
# 4. Locate validator script
# ==================================================

VALIDATOR=$(find "$WORK_DIR" -type f -name "$VALIDATOR_NAME" | head -n1)

if [ -z "$VALIDATOR" ]; then
    fail "Validation script not found in package"
fi

chmod +x "$VALIDATOR"

log "Using validator: $VALIDATOR"

# ==================================================
# 5. Run validation
# ==================================================

log "Running validation..."

"$VALIDATOR" "$CONFIG_FILE"
RC=$?

if [ "$RC" -ne 0 ]; then
    fail "Validation failed"
fi

log "Validation passed"

# ==================================================
# 6. Prepare OpenVPN directory
# ==================================================

mkdir -p "$OVPN_DIR" || fail "Failed to create $OVPN_DIR"

# ==================================================
# 7. Compare with existing configs
# ==================================================

EXISTING_FILES=$(find "$OVPN_DIR" -maxdepth 1 \( -name "*.ovpn" -o -name "*.conf" \))
MATCH_FOUND=0

if [ -n "$EXISTING_FILES" ]; then
    log "Existing OpenVPN config(s) found"

    for FILE in $EXISTING_FILES; do
        if cmp -s "$FILE" "$CONFIG_FILE"; then
            log "Matching config already installed: $FILE"
            MATCH_FOUND=1
            break
        fi
    done
else
    log "No existing configs found"
fi

# ==================================================
# 8. Install new config if needed
# ==================================================

if [ "$MATCH_FOUND" -eq 0 ]; then

    log "Config differs — installing new configuration"

    BACKUP_DIR="$TMP_DIR/openvpn_backup_$(date +%s)"
    mkdir -p "$BACKUP_DIR"

    log "Backing up existing configs to: $BACKUP_DIR"

    cp "$OVPN_DIR"/*.ovpn "$OVPN_DIR"/*.conf "$BACKUP_DIR" 2>/dev/null

    rm -f "$OVPN_DIR"/*.ovpn "$OVPN_DIR"/*.conf 2>/dev/null

    BASE_NAME=$(basename "$CONFIG_FILE")

    case "$BASE_NAME" in
        *.ovpn)
            NEW_NAME=$(echo "$BASE_NAME" | sed 's/\.ovpn$/.conf/')
            ;;
        *.conf)
            NEW_NAME="$BASE_NAME"
            ;;
        *)
            fail "Unsupported config file type"
            ;;
    esac

    TARGET_FILE="$OVPN_DIR/$NEW_NAME"

    log "Installing config as: $TARGET_FILE"

    cp "$CONFIG_FILE" "$TARGET_FILE" \
        || fail "Failed to copy new config"

    log "Config installed successfully"

    # ==================================================
    # 9. Restart OpenVPN
    # ==================================================

    log "Restarting OpenVPN service..."

    service openvpn restart
    RC=$?

    if [ "$RC" -ne 0 ]; then
        fail "OpenVPN restart failed"
    fi

    log "OpenVPN restart succeeded"

    # ==================================================
    # 10. Health check
    # ==================================================

    log "Waiting for tunnel to establish..."
    sleep 5

    if ifconfig tun0 >/dev/null 2>&1; then
        log "Tunnel interface tun0 is up ✅"
    else
        log "WARNING: tun0 not detected — VPN may not be connected"
    fi

else
    log "No changes detected — skipping install and restart"
fi

# ==================================================
# 11. Cleanup
# ==================================================

cleanup

log "Installation complete"

exit 0
