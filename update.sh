#!/bin/bash
set -e

# --- Configuration ---
JSON_URL="https://raw.githubusercontent.com/<your-repo>/system.json"
INSTALL_DIR="/opt/mysystem"
CURRENT_VERSION_FILE="$INSTALL_DIR/version.txt"

log() { echo "[*] $1"; }

# 1. Fetch JSON
log "Fetching system.json..."
curl -s -o /tmp/system.json "$JSON_URL"
NEW_VERSION=$(jq -r '.version' /tmp/system.json)

# 2. Check version
CURRENT_VERSION="0"
if [ -f "$CURRENT_VERSION_FILE" ]; then
    CURRENT_VERSION=$(cat "$CURRENT_VERSION_FILE")
fi

if [ "$CURRENT_VERSION" == "$NEW_VERSION" ]; then
    log "System already up to date (version $CURRENT_VERSION). Exiting."
    exit 0
fi
log "Updating from version $CURRENT_VERSION to $NEW_VERSION..."

# 3. Install apt requirements
APT_PACKAGES=$(jq -r '.apt_requirements[]?' /tmp/system.json)
if [ ! -z "$APT_PACKAGES" ]; then
    log "Installing apt packages..."
    apt update && apt install -y $APT_PACKAGES
fi

# 4. Install Python requirements
PYTHON_PACKAGES=$(jq -r '.python_requirements[]?' /tmp/system.json)
if [ ! -z "$PYTHON_PACKAGES" ]; then
    log "Installing/updating Python packages..."
    pip3 install --upgrade $PYTHON_PACKAGES
fi

# 5. Download files
FILES=$(jq -c '.files[]' /tmp/system.json)
for file in $FILES; do
    FILE_URL=$(echo "$file" | jq -r '.url')
    FILE_PATH=$(echo "$file" | jq -r '.path')
    FILE_DIR=$(dirname "$FILE_PATH")
    mkdir -p "$FILE_DIR"
    log "Downloading $FILE_URL to $FILE_PATH..."
    curl -s -L -o "$FILE_PATH" "$FILE_URL"
done

# 6. Set permissions
PERMS=$(jq -c '.permissions[]?' /tmp/system.json)
for perm in $PERMS; do
    PATH_TO_FILE=$(echo "$perm" | jq -r '.path')
    CHMOD_VAL=$(echo "$perm" | jq -r '.chmod')
    log "Setting permissions $CHMOD_VAL on $PATH_TO_FILE..."
    chmod "$CHMOD_VAL" "$PATH_TO_FILE"
done

# 7. Download changelog
CHANGELOG_URL=$(jq -r '.changelog?' /tmp/system.json)
if [ ! -z "$CHANGELOG_URL" ]; then
    mkdir -p "$INSTALL_DIR"
    log "Downloading changelog..."
    curl -s -L -o "$INSTALL_DIR/CHANGELOG.md" "$CHANGELOG_URL"
fi

# 8. Update version file
echo "$NEW_VERSION" > "$CURRENT_VERSION_FILE"

log "Update complete!"
