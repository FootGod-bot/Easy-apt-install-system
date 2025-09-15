#!/bin/bash
set -e

log() { echo "[*] $1"; }

# --- Ensure jq is installed ---
if ! command -v jq &> /dev/null; then
    log "jq not found. Installing..."
    apt update && apt install -y jq
fi

# --- Configuration ---
JSON_URL="https://raw.githubusercontent.com/<your-repo>/system.json"
SERVICE_NAME="mysystem-updater"
SERVICE_COMMAND="/opt/mysystem/update.sh --service"
SERVICE_INTERVAL=30
INSTALL_DIR="/opt/mysystem"

# --- Fetch system.json ---
log "Fetching system.json..."
curl -s -o /tmp/system.json "$JSON_URL"

# --- Install apt requirements ---
APT_PACKAGES=$(jq -r '.apt_requirements[]?' /tmp/system.json)
if [ ! -z "$APT_PACKAGES" ]; then
    log "Installing apt packages..."
    apt update && apt install -y $APT_PACKAGES
fi

# --- Install Python requirements ---
PYTHON_PACKAGES=$(jq -r '.python_requirements[]?' /tmp/system.json)
if [ ! -z "$PYTHON_PACKAGES" ]; then
    log "Installing Python packages..."
    pip3 install $PYTHON_PACKAGES
fi

# --- Download files ---
FILES=$(jq -c '.files[]' /tmp/system.json)
for file in $FILES; do
    FILE_URL=$(echo "$file" | jq -r '.url')
    FILE_PATH=$(echo "$file" | jq -r '.path')
    FILE_DIR=$(dirname "$FILE_PATH")
    mkdir -p "$FILE_DIR"
    log "Downloading $FILE_URL to $FILE_PATH..."
    curl -s -L -o "$FILE_PATH" "$FILE_URL"
done

# --- Set permissions ---
PERMS=$(jq -c '.permissions[]?' /tmp/system.json)
for perm in $PERMS; do
    PATH_TO_FILE=$(echo "$perm" | jq -r '.path')
    CHMOD_VAL=$(echo "$perm" | jq -r '.chmod')
    log "Setting permissions $CHMOD_VAL on $PATH_TO_FILE..."
    chmod "$CHMOD_VAL" "$PATH_TO_FILE"
done

# --- Download changelog ---
CHANGELOG_URL=$(jq -r '.changelog?' /tmp/system.json)
if [ ! -z "$CHANGELOG_URL" ]; then
    mkdir -p "$INSTALL_DIR"
    log "Downloading changelog..."
    curl -s -L -o "$INSTALL_DIR/CHANGELOG.md" "$CHANGELOG_URL"
fi

# --- Create systemd service (runs update.sh in service mode) ---
log "Creating systemd service $SERVICE_NAME..."
cat <<EOF > /etc/systemd/system/$SERVICE_NAME.service
[Unit]
Description=My system updater service

[Service]
ExecStart=/bin/bash -c 'while true; do $SERVICE_COMMAND; sleep $SERVICE_INTERVAL; done'
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable $SERVICE_NAME
systemctl start $SERVICE_NAME

# --- Mark installed version ---
NEW_VERSION=$(jq -r '.version' /tmp/system.json)
mkdir -p "$INSTALL_DIR"
echo "$NEW_VERSION" > "$INSTALL_DIR/version.txt"

log "Install complete!"
