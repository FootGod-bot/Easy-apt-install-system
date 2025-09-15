#!/bin/bash
set -e

log() { echo "[*] $1"; }

# --- Ensure jq is installed ---
if ! command -v jq &> /dev/null; then
    log "jq not found. Installing..."
    apt update && apt install -y jq
fi

# --- Configuration ---
JSON_URL="https://raw.githubusercontent.com/FootGod-bot/Universal-ssh-keys/refs/heads/main/system.json"
INSTALL_DIR="/opt/mysystem"
CURRENT_VERSION_FILE="$INSTALL_DIR/version.txt"

# --- Service mode ---
SKIP_DOWNLOAD=0
if [ "$1" == "--service" ]; then
    SKIP_DOWNLOAD=1
    log "Running in service mode: skipping file downloads."
fi

# --- Fetch system.json ---
if [ $SKIP_DOWNLOAD -eq 0 ]; then
    log "Fetching system.json..."
    curl -s -o /tmp/system.json "$JSON_URL"
fi

# --- Determine version ---
NEW_VERSION=$(jq -r '.version' /tmp/system.json)
CURRENT_VERSION="0"
[ -f "$CURRENT_VERSION_FILE" ] && CURRENT_VERSION=$(cat "$CURRENT_VERSION_FILE")

if [ "$CURRENT_VERSION" == "$NEW_VERSION" ] && [ $SKIP_DOWNLOAD -eq 0 ]; then
    log "System already up to date (version $CURRENT_VERSION). Exiting."
    exit 0
fi

[ $SKIP_DOWNLOAD -eq 0 ] && log "Updating from version $CURRENT_VERSION to $NEW_VERSION..."

# --- Install apt requirements ---
if [ $SKIP_DOWNLOAD -eq 0 ]; then
    APT_PACKAGES=$(jq -r '.apt_requirements[]?' /tmp/system.json)
    [ ! -z "$APT_PACKAGES" ] && apt update && apt install -y $APT_PACKAGES
fi

# --- Install Python requirements ---
if [ $SKIP_DOWNLOAD -eq 0 ]; then
    PYTHON_PACKAGES=$(jq -r '.python_requirements[]?' /tmp/system.json)
    if [ ! -z "$PYTHON_PACKAGES" ]; then
        for pkg in $PYTHON_PACKAGES; do
            pip3 install --upgrade $pkg || {
                echo "⚠️ Python package $pkg failed (PEP 668)."
                read -p "Continue with --break-system-packages? (y/N): " choice
                case "$choice" in
                    y|Y ) pip3 install --break-system-packages $pkg ;;
                    * ) echo "Skipping $pkg" ;;
                esac
            }
        done
    fi
fi

# --- Download files ---
if [ $SKIP_DOWNLOAD -eq 0 ]; then
    FILES=$(jq -c '.files[]' /tmp/system.json)
    for file in $FILES; do
        FILE_URL=$(echo "$file" | jq -r '.url')
        FILE_PATH=$(echo "$file" | jq -r '.path')
        mkdir -p "$(dirname "$FILE_PATH")"
        log "Downloading $FILE_URL to $FILE_PATH..."
        curl -s -L -o "$FILE_PATH" "$FILE_URL"
    done
fi

# --- Set permissions ---
if [ $SKIP_DOWNLOAD -eq 0 ]; then
    PERMS=$(jq -c '.permissions[]?' /tmp/system.json)
    for perm in $PERMS; do
        PATH_TO_FILE=$(echo "$perm" | jq -r '.path')
        CHMOD_VAL=$(echo "$perm" | jq -r '.chmod')
        log "Setting permissions $CHMOD_VAL on $PATH_TO_FILE..."
        chmod "$CHMOD_VAL" "$PATH_TO_FILE"
    done
fi

# --- Download changelog ---
if [ $SKIP_DOWNLOAD -eq 0 ]; then
    CHANGELOG_URL=$(jq -r '.changelog?' /tmp/system.json)
    [ ! -z "$CHANGELOG_URL" ] && mkdir -p "$INSTALL_DIR" && curl -s -L -o "$INSTALL_DIR/CHANGELOG.md" "$CHANGELOG_URL"
fi

# --- Update version file ---
[ $SKIP_DOWNLOAD -eq 0 ] && echo "$NEW_VERSION" > "$CURRENT_VERSION_FILE"

log "Update complete!"
