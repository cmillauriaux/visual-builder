#!/bin/bash
set -e

GODOT_VERSION="4.4"
GODOT_RELEASE="4.4-stable"
GODOT_BINARY_NAME="Godot_v${GODOT_VERSION}-stable_linux.x86_64"
GODOT_ZIP="${GODOT_BINARY_NAME}.zip"
GODOT_URL="https://github.com/godotengine/godot/releases/download/${GODOT_RELEASE}/${GODOT_ZIP}"
INSTALL_PATH="/usr/local/bin/godot"

# Check if GODOT_PATH is already set and valid
if [ -n "$GODOT_PATH" ] && [ -x "$GODOT_PATH" ]; then
    INSTALLED_VERSION=$("$GODOT_PATH" --version 2>/dev/null | cut -d. -f1-2)
    if [ "$INSTALLED_VERSION" = "$GODOT_VERSION" ]; then
        echo "Godot $GODOT_VERSION already available at $GODOT_PATH."
        exit 0
    fi
fi

# Check if Godot is already installed in PATH with correct version
if command -v godot &> /dev/null; then
    INSTALLED_VERSION=$(godot --version 2>/dev/null | cut -d. -f1-2)
    if [ "$INSTALLED_VERSION" = "$GODOT_VERSION" ]; then
        echo "Godot $GODOT_VERSION already installed."
        exit 0
    fi
    echo "Godot found but wrong version ($INSTALLED_VERSION). Upgrading..."
fi

echo "Installing Godot $GODOT_VERSION headless..."

TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Download with retry (up to 4 attempts with exponential backoff)
RETRY=0
MAX_RETRIES=4
while [ $RETRY -lt $MAX_RETRIES ]; do
    if curl -L -o "$TEMP_DIR/$GODOT_ZIP" "$GODOT_URL" 2>/dev/null; then
        break
    fi
    RETRY=$((RETRY + 1))
    if [ $RETRY -lt $MAX_RETRIES ]; then
        WAIT=$((2 ** RETRY))
        echo "Download failed. Retrying in ${WAIT}s... (attempt $((RETRY + 1))/$MAX_RETRIES)"
        sleep $WAIT
    else
        echo "ERROR: Failed to download Godot after $MAX_RETRIES attempts."
        exit 1
    fi
done

# Extract and install
cd "$TEMP_DIR"
unzip -o "$GODOT_ZIP" > /dev/null
cp "$GODOT_BINARY_NAME" "$INSTALL_PATH"
chmod +x "$INSTALL_PATH"

echo "Godot $(godot --version 2>/dev/null) installed to $INSTALL_PATH"
