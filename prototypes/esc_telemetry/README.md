# ESC Telemetry Scanner (macOS Prototype)

This directory contains a macOS-native Swift application and CLI tool for discovering and reverse-engineering the Bluetooth LE telemetry protocol of the Snail ESC.

## Components

- **`ESCScanner.app`**: A SwiftUI application that provides a visual log of BLE discovery and telemetry packets.
- **`esc_app.swift`**: The core logic for BLE discovery, service/characteristic subscription, and packet parsing (framed `0x02` and legacy `0x45` families).
- **`main.swift`**: A simple entry point that allows running the monitor as a standalone CLI tool.
- **`build.sh`**: A helper script to generate the Xcode project, build the app, and launch it with optional session labels.
- **`project.yml`**: [XcodeGen](https://github.com/yonaskolb/XcodeGen) configuration for the macOS app.

## Prerequisites

- macOS 14.0+
- Xcode 16.2+
- `xcodegen` (install via `brew install xcodegen`)

## Build and Run

### Using the Build Script (Recommended)

The `build.sh` script automates the process of generating the project and building the app.

```bash
# Build the app (copies to Build/ESCScanner.app)
./build.sh build

# Launch the app with a session label (logs to ~/esc_telemetry_runs/)
./build.sh launch --session-label speed_1500

# Run only the CLI probe (faster for quick tests)
swiftc -framework CoreBluetooth -framework Foundation esc_app.swift main.swift -o /tmp/esc_app_probe
/tmp/esc_app_probe
```

### Manual Build

If you prefer to use Xcode directly:

```bash
# Generate the .xcodeproj
xcodegen generate

# Open in Xcode
open ESCScanner.xcodeproj
```

## Protocol Status

The scanner implements two probe families derived from reverse-engineering the official Android APK:
1. **Framed (`0x02`)**: Modern packet format with CRC16-XMODEM checksums.
2. **Legacy (`0x45`)**: Simple fixed-length command/response pairs.

Telemetry logs are written to:
- Default: `~/esc_telemetry.log`
- Labeled sessions: `~/esc_telemetry_runs/<timestamp>_<label>.log`
