#!/bin/bash
# Stops the motor and returns ESC to neutral.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../tools/common.sh"
compile_and_upload "$SKETCHES_DIR/motor_stop/"
echo "Motor stopped and returned to neutral."
