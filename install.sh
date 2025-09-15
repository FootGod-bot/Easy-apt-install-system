#!/bin/bash

LOCAL_DIR="$HOME/my-tool"
VERSION_URL="https://raw.githubusercontent.com/<username>/my-tool/main/version.json"

# Function to check/install dependency
check_install() {
    CMD=$1
    PKG=$2
    if ! command -v "$CMD" >/dev/null 2>&1; then
        echo "$CMD not found. Installing..."
        sudo apt update && sudo apt install -y "$PKG" || { echo "Failed to install $PKG"; exit 1; }
    fi
}

# Check dependencies
check_install curl curl
check_install jq jq

mkdir -p "$LOCAL_DIR"

# Download version.json
echo "Downloading version info..."
curl -sL "$VERSION_URL" -o "$LOCAL_DIR/version.json" || { echo "Failed to fetch version.json"; exit 1; }

# Read remote version
REMOTE_VERSION=$(jq -r '.version' "$LOCAL_DIR/version.json")
echo "Remote version: $REMOTE_VERSION"

# Get local version if exists
if [ -f "$LOCAL_DIR/version_local.json" ]; then
    LOCAL_VERSION=$(jq -r '.version' "$LOCAL_DIR/version_local.json")
else
    LOCAL_VERSION="0.0.0"
fi

echo "Local version: $LOCAL_VERSION"

if [ "$REMOTE_VERSION" != "$LOCAL_VERSION" ]; then
    echo "Updating files..."

    # Loop through files
    FILES_COUNT=$(jq '.files | length' "$LOCAL_DIR/version.json")
    for ((i=0;i<$FILES_COUNT;i++)); do
        FILE_URL=$(jq -r ".files[$i].url" "$LOCAL_DIR/version.json")
        FILE_PATH=$(jq -r ".files[$i].path" "$LOCAL_DIR/version.json")
        echo "Downloading $FILE_PATH..."
        curl -sL "$FILE_URL" -o "$LOCAL_DIR/$FILE_PATH" || { echo "Failed to download $FILE_PATH"; exit 1; }
        chmod +x "$LOCAL_DIR/$FILE_PATH"
    done

    # Save local copy of version.json
    cp "$LOCAL_DIR/version.json" "$LOCAL_DIR/version_local.json"

    # Optional: show changelog
    CHANGELOG_URL=$(jq -r '.changelog' "$LOCAL_DIR/version.json")
    echo "Changelog:"
    curl -sL "$CHANGELOG_URL"
    
    echo "Update complete to version $REMOTE_VERSION"
else
    echo "Already up to date."
fi
