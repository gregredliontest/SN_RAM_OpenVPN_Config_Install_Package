#!/bin/sh

# ==================================================
# OpenVPN Config Validator (Installer-Ready)
# Compatible with OpenVPN 2.3.x
# ==================================================

FILE="$1"
WORK_DIR="/tmp/ovpn_extract"

LOG_PREFIX="[OVPN VALIDATOR]"

log() {
    echo "$LOG_PREFIX $1"
}

warn() {
    echo "$LOG_PREFIX WARNING: $1"
}

error() {
    echo "$LOG_PREFIX ERROR: $1"
    FAIL=1
}

# ==================================================
# 0. Input validation
# ==================================================

if [ -z "$FILE" ]; then
    echo "Usage: $0 <config.ovpn|config.conf>"
    exit 1
fi

if [ ! -f "$FILE" ]; then
    echo "[ERROR] File not found: $FILE"
    exit 1
fi

log "Validating: $FILE"

FAIL=0

# ==================================================
# Helper functions
# ==================================================

has_option() {
    grep -qE "^[[:space:]]*$1\b" "$FILE"
}

get_value() {
    grep -E "^[[:space:]]*$1 " "$FILE" | head -n1 | awk '{$1=""; print substr($0,2)}'
}

has_inline_block() {
    grep -q "<$1>" "$FILE" && grep -q "</$1>" "$FILE"
}

# ==================================================
# 1. BASIC CHECKS
# ==================================================

has_option "remote" || error "Missing 'remote' directive"
has_option "dev" || error "Missing 'dev' directive"

PROTO=$(get_value proto)
[ -n "$PROTO" ] && log "Protocol: $PROTO"

REMOTE=$(get_value remote)
[ -n "$REMOTE" ] && log "Remote: $REMOTE"

# ==================================================
# 2. CRYPTO VALIDATION (2.3 SAFE)
# ==================================================

CIPHER=$(get_value cipher)

if [ -z "$CIPHER" ]; then
    warn "No cipher specified (recommended: AES-256-CBC)"
else
    log "Cipher: $CIPHER"
fi

echo "$CIPHER" | grep -qi "gcm" && error "GCM cipher not supported in OpenVPN 2.3"

has_option "data-ciphers" && error "data-ciphers not supported in OpenVPN 2.3"
has_option "ncp-ciphers" && error "ncp-ciphers not supported in OpenVPN 2.3"

# ==================================================
# 3. TLS VALIDATION
# ==================================================

if has_option "tls-crypt"; then
    error "tls-crypt is NOT supported in OpenVPN 2.3"
fi

if has_option "tls-auth"; then
    log "tls-auth detected"

    if ! has_option "key-direction"; then
        warn "tls-auth present but no key-direction specified"
    fi
else
    warn "No tls-auth found (verify server requirements)"
fi

# ==================================================
# 4. CERT VALIDATION
# ==================================================

CA_OK=0
CERT_OK=0
KEY_OK=0

if has_inline_block "ca"; then
    log "Inline CA found"
    CA_OK=1
elif has_option "ca"; then
    log "CA file directive found"
    CA_OK=1
fi

if has_inline_block "cert"; then
    log "Inline cert found"
    CERT_OK=1
elif has_option "cert"; then
    log "Cert file directive found"
    CERT_OK=1
fi

if has_inline_block "key"; then
    log "Inline key found"
    KEY_OK=1
elif has_option "key"; then
    log "Key file directive found"
    KEY_OK=1
fi

[ "$CA_OK" -eq 0 ] && error "Missing CA certificate"
[ "$CERT_OK" -eq 0 ] && error "Missing client certificate"
[ "$KEY_OK" -eq 0 ] && error "Missing private key"

# ==================================================
# 5. AUTH CHECK
# ==================================================

AUTH=$(get_value auth)

if [ -z "$AUTH" ]; then
    warn "No auth specified (recommended: SHA256)"
else
    log "Auth: $AUTH"
fi

# ==================================================
# 6. COMPRESSION CHECK
# ==================================================

has_option "compress" && error "compress directive not supported in OpenVPN 2.3"

if has_option "comp-lzo"; then
    log "comp-lzo enabled (legacy)"
fi

# ==================================================
# 7. OPTIONAL: INLINE CERT EXTRACTION
# ==================================================

# Only run if explicitly enabled
if [ "$EXTRACT_INLINE" = "1" ]; then

    log "Extracting inline certs to $WORK_DIR"

    rm -rf "$WORK_DIR"
    mkdir -p "$WORK_DIR"

    extract_block() {
        NAME="$1"
        OUTFILE="$2"

        awk "/<$NAME>/,/<\\/$NAME>/" "$FILE" | sed '1d;$d' > "$WORK_DIR/$OUTFILE"

        if [ -s "$WORK_DIR/$OUTFILE" ]; then
            log "Extracted $NAME → $WORK_DIR/$OUTFILE"
        fi
    }

    has_inline_block "ca" && extract_block "ca" "ca.crt"
    has_inline_block "cert" && extract_block "cert" "client.crt"
    has_inline_block "key" && extract_block "key" "client.key"
    has_inline_block "tls-auth" && extract_block "tls-auth" "ta.key"

fi

# ==================================================
# 8. FINAL RESULT
# ==================================================

echo "----------------------------------------"

if [ "$FAIL" -ne 0 ]; then
    error "VALIDATION FAILED"
    exit 1
else
    log "VALIDATION PASSED"
    exit 0
fi
