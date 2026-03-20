# Changelog - metalbot-mcp

All notable changes to this project will be documented in this file.

## [0.2.0] - 2026-03-20

### Added
- Robust USB-Serial communication with Arduino (`asio::serial_port`).
- Real-time Arduino command feedback (ACK logging) in the dashboard.
- Automatic serial reconnection logic with error handling.
- Arduino boot synchronization (3.5s delay) and serial buffer flushing.
- Non-blocking I/O for smooth UI updates during serial operations.

## [0.1.0] - 2026-03-19

### Added
- C++17 event-driven bridge using `Asio` for network and `FTXUI` for TUI.
- Stationary bi-directional car-style meters for steering/motor feedback.
- Wi-Fi (UDP) protocol supporting heartbeats (`hb_pi`, `hb_iphone`) and commands (`cmd:s=x,m=y`).
- 1.5-second watchdog timeout for `Remote Brain` connection status.
- Real-time Pi local time and device info display.
- `CMake` build system.
