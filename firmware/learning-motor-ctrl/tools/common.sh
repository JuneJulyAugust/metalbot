#!/bin/bash
# Shared helpers for arduino-cli build/upload scripts.

TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIRMWARE_ROOT="$(cd "$TOOLS_DIR/.." && pwd)"
SKETCHES_DIR="$FIRMWARE_ROOT/sketches"

export PATH="$PATH:$TOOLS_DIR/bin"
export ARDUINO_CONFIG_FILE="$TOOLS_DIR/arduino-cli.yaml"
export ARDUINO_DIRECTORIES_DATA="$TOOLS_DIR/arduino_data"
export ARDUINO_DIRECTORIES_USER="$TOOLS_DIR/arduino_data/user"
export ARDUINO_DIRECTORIES_DOWNLOADS="$TOOLS_DIR/arduino_data/staging"

FQBN="arduino:avr:mega"

detect_port() {
  local port
  port=$(ls /dev/ttyUSB* 2>/dev/null | head -1)
  if [ -z "$port" ]; then
    echo "Error: No /dev/ttyUSB* device found." >&2
    exit 1
  fi
  sudo chmod 666 "$port" 2>/dev/null
  echo "$port"
}

compile_and_upload() {
  local sketch_dir="$1"
  local port
  port=$(detect_port)

  echo "Compiling $sketch_dir..."
  if ! arduino-cli compile --fqbn "$FQBN" "$sketch_dir"; then
    echo "Compilation failed." >&2
    return 1
  fi

  echo "Uploading to $port..."
  if ! arduino-cli upload -p "$port" --fqbn "$FQBN" "$sketch_dir"; then
    echo "Upload failed." >&2
    return 1
  fi

  echo "Done."
}
