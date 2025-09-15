#!/bin/bash
set -e

log() { echo "[*] $1"; }

install_python_package() {
    PACKAGE=$1
    if ! pip3 install --upgrade $PACKAGE; then
        echo "⚠️ Python package $PACKAGE failed to upgrade."
        read -p "Try upgrading with --break-system-packages? [y/N]: " choice
        if [[ "$choice" =~ ^[Yy]$ ]]; then
            pip3 install --upgrade --break-system-packages $PACKAGE
        else
            echo "Skipping $PACKAGE."
        fi
    fi
}

# --- Ensure jq is installed ---
if ! command -v jq &> /dev/null; then
    log "jq not found. Installing..."
    apt update && apt install -y jq
fi

# --- Configuration ---
JSON_URL="https://raw.githubusercontent.com/FootGod-bot/Universal-ssh-keys/refs/heads/main/system.json"
INSTALL_DIR="/opt/mysystem"
CURRENT_VERSION_FILE="$INSTALL_DIR/version.txt"

# --- Check for service flag ---
SKIP_DOWNLOAD=0
if [ "$1" == "--service" ]; then
    SKIP_DOWNLOAD=1
    log "Running in service mode: skipping file downloads."
fi

# --- Fetch system.json if not in service mode ---
if [ $SKIP_DOWNLOAD -eq 0 ]; then
    log "Fetching system.json..."
    curl -s -o /tmp/system.json "$JSON_URL"
fi

# --- Determine version ---
NEW_VERSION=$(jq -r '.version' /tmp/system.json)
CURRENT_VERSION="0"
if [ -f "$CURRENT_VERSION_FILE" ]; then
    CURRENT_VERSION=$(cat "$CURRENT_VERSION_FILE")
fi

if [ "$CURRENT_VERSION" == "$NEW_VERSION" ] && [ $SKIP_DOWNLOAD -eq 0 ]; then
    log "System already up to date (version $CURRENT_VERSION). Exiting."
    exit 0
fi

if [ $SKIP_DOWNLOAD -eq 0 ]; then
    log "Updating from version $CURRENT_VERSION to $NEW_VERSION..."
fi

# --- Install apt requirements ---
if [ $SKIP_DOWNLOAD -eq 0 ]; then
    APT_PACKAGES=$(jq -r '.apt_requirements[]?' /tmp/system.json)
    if [ ! -z "$APT_PACKAGES" ]; then
        log "Installing apt packages..."
        apt update && apt install -y $APT_PACKAGES
    fi
fi

# --- Install Python requirements ---
if [ $SKIP_DOWNLOAD -eq 0 ]; then
    PYTHON_PACKAGES=$(jq -r '.python_requirements[]?' /tmp/system.json)
    for pkg in $PYTHON_PACKAGES; do
        install_python_package $pkg
    done
fi

# --- Download files ---
if [ $SKIP_DOWNLOAD -eq 0 ]; then
    FILES=$(jq -c '.files[]' /tmp/system.json)
    for file in $FILES; do
        FILE_URL=$(echo "$file" | jq -r '.url')
        FILE_PATH=$(echo "$file" | jq -r '.path')
        FILE_DIR=$(dirname "$FILE_PATH")
        mkdir -p "$FILE_DIR"
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
    if [ ! -z "$CHANGELOG_URL" ]; then
        mkdir -p "$INSTALL_DIR"
        log "Downloading changelog..."
        curl -s -L -o "$INSTALL_DIR/CHANGELOG.md" "$CHANGELOG_URL"
    fi
fi

# --- Update version file ---
if [ $SKIP_DOWNLOAD -eq 0 ]; then
    echo "$NEW_VERSION" > "$CURRENT_VERSION_FILE"
fi

log "Update complete!"
