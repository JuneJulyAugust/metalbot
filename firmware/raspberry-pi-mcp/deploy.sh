#!/usr/bin/env bash
set -euo pipefail

# Deployment script for raspberry-pi-mcp firmware
# Usage: ./deploy.sh [pi-hostname-or-ip]

PI_HOST="${1:-pi}"
REMOTE_DIR="~/raspberry-pi-mcp"

# Get the absolute path to the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "==> Syncing source from $SCRIPT_DIR to $PI_HOST:$REMOTE_DIR..."

# Syncing only the firmware source files, avoiding build artifacts and local git
# Note: rsync source ends with / to sync contents into the remote dir
rsync -avz --delete \
    --exclude 'build/' \
    --exclude '.git/' \
    --exclude 'FTXUI/' \
    "$SCRIPT_DIR/" "$PI_HOST:$REMOTE_DIR/"

echo "==> Building on $PI_HOST..."
# Ensure FTXUI is present on the Pi (it should be cloned once)
ssh "$PI_HOST" "
    mkdir -p $REMOTE_DIR && \
    if [ ! -d $REMOTE_DIR/FTXUI ]; then
        echo '==> Cloning FTXUI on Pi...' && \
        cd $REMOTE_DIR && git clone https://github.com/ArthurSonzogni/FTXUI.git;
    fi && \
    mkdir -p $REMOTE_DIR/build && \
    cd $REMOTE_DIR/build && \
    cmake .. && \
    make -j\$(nproc 2>/dev/null || echo 4)
"

echo "==> Done. Run with: ssh $PI_HOST \"$REMOTE_DIR/build/raspberry-pi-mcp\""
