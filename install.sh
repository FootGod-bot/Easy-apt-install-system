#!/bin/bash
set -e

# --- Configuration ---
JSON_URL="https://raw.githubusercontent.com/<your-repo>/system.json"
SERVICE_NAME="mysystem-updater"
SERVICE_COMMAND="/opt/mysystem/main.py"
SERVICE_INTERVAL=30
INSTALL_DIR="/opt/mysystem"

# --- Functions ---
log() { echo "[*] $1"; }

# 1. Install apt requirements from JSON
log "Fetching system.json..."
curl -s -o /tmp/system.json "$JSON_URL"

APT_PACKAGES=$(jq -r '.apt_requirements[]?' /tmp/system.json)
if [ ! -z "$APT_PACKAGES" ]; then
    log "Installing apt packages..."
    apt update && apt install -y $APT_PACKAGES
fi

# 2. Install Python requirements
PYTHON_PACKAGES=$(jq -r '.python_requirements[]?' /tmp/system.json)
if [ ! -z "$PYTHON_PACKAGES" ]; then
    log "Installing Python packages..."
    pip3 install $PYTHON_PACKAGES
fi

# 3. Download files
FILES=$(jq -c '.files[]' /tmp/system.json)
for file in $FILES; do
    FILE_URL=$(echo "$file" | jq -r '.url')
    FILE_PATH=$(echo "$file" | jq -r '.path')
    FILE_DIR=$(dirname "$FILE_PATH")
    mkdir -p "$FILE_DIR"
    log "Downloading $FILE_URL to $FILE_PATH..."
    curl -s -L -o "$FILE_PATH" "$FILE_URL"
done

# 4. Set permissions
PERMS=$(jq -c '.permissions[]?' /tmp/system.json)
for perm in $PERMS; do
    PATH_TO_FILE=$(echo "$perm" | jq -r '.path')
    CHMOD_VAL=$(echo "$perm" | jq -r '.chmod')
    log "Setting permissions $CHMOD_VAL on $PATH_TO_FILE..."
    chmod "$CHMOD_VAL" "$PATH_TO_FILE"
done

# 5. Download changelog
CHANGELOG_URL=$(jq -r '.changelog?' /tmp/system.json)
if [ ! -z "$CHANGELOG_URL" ]; then
    mkdir -p "$INSTALL_DIR"
    log "Downloading changelog..."
    curl -s -L -o "$INSTALL_DIR/CHANGELOG.md" "$CHANGELOG_URL"
fi

# 6. Create systemd service (forced, 30s interval)
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

log "Install complete!"
