# Changelog - metalbot-mcp

All notable changes to this project will be documented in this file.

## [0.1.0] - 2026-03-19

### Added
- C++17 event-driven bridge using `Asio` for network and `FTXUI` for TUI.
- Stationary bi-directional car-style meters for steering/motor feedback.
- Wi-Fi (UDP) protocol supporting heartbeats (`hb_pi`, `hb_iphone`) and commands (`cmd:s=x,m=y`).
- 1.5-second watchdog timeout for `Remote Brain` connection status.
- Real-time Pi local time and device info display.
- `CMake` build system.
