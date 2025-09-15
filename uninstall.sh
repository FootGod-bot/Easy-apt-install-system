#!/bin/bash
set -e

log() { echo "[*] $1"; }

INSTALL_DIR="/opt/mysystem"
SERVICE_NAME="mysystem-updater"

read -p "Remove systemd service? (y/N): " remove_service
if [[ $remove_service =~ ^[Yy]$ ]]; then
    systemctl stop $SERVICE_NAME || true
    systemctl disable $SERVICE_NAME || true
    rm -f /etc/systemd/system/$SERVICE_NAME.service
    systemctl daemon-reload
    log "Service removed."
fi

read -p "Remove installed files? (y/N): " remove_files
if [[ $remove_files =~ ^[Yy]$ ]]; then
    rm -rf "$INSTALL_DIR"
    log "Files removed."
fi

read -p "Remove Python packages installed by this script? (y/N): " remove_python
if [[ $remove_python =~ ^[Yy]$ ]]; then
    PYTHON_PACKAGES=$(jq -r '.python_requirements[]?' /tmp/system.json)
    for pkg in $PYTHON_PACKAGES; do
        pip3 uninstall -y $pkg || true
    done
    log "Python packages removed."
fi

read -p "Remove APT packages installed by this script? (y/N): " remove_apt
if [[ $remove_apt =~ ^[Yy]$ ]]; then
    APT_PACKAGES=$(jq -r '.apt_requirements[]?' /tmp/system.json)
    apt remove -y $APT_PACKAGES || true
    log "APT packages removed."
fi

log "Uninstall complete!"
