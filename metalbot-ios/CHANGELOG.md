# Changelog - metalbot-ios

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] - 2026-03-20

### Added
- **Full End-to-End Control Path**: iPhone commands now actuate RC car servos.
- **Arduino Control Module**: New Arduino Mega firmware with normalized serial protocol and safety arming logic.
- **Robust Serial Bridging**: MCP (Pi) now features auto-reconnect and boot-sync for stable Arduino communication.
- **Pi-native Toolchain**: Self-contained `arduino-cli` environment for Pi-side compilation and flashing.
- Real-time hardware feedback from actuators back to the MCP dashboard.

### Changed
- Refined steering/motor command protocol with 10Hz/20Hz update rate and ACK logging.

## [0.2.0] - 2026-03-19

### Added
- Bi-directional MCP bridge for Raspberry Pi 4B over Wi-Fi (UDP).
- `MCPTestView` diagnostics interface with real-time network metrics and manual controls.
- Dynamic IP discovery and device naming in diagnostics view.
- 1.5-second watchdog timeout for connection status.
- Card-based modern UI with `GroupBox` and SF Symbols.

### Fixed
- Build error on iOS by replacing macOS-specific `Host` API with `UIDevice`.
- Network communication logic for reliable packet parsing.
- Diagnostics view integration with `DepthCaptureView` start prompt.

## [0.1.0] - 2026-03-14


### Added
- Initial project scaffold with LiDAR-capable support checks.
- ARKit `sceneDepth` stream capture and diagnostics.
- Raw point cloud back-projection and Metal rendering.
- Orientation-aware camera view matrix and intrinsics scaling.
- RGB + point-cloud split-screen debug view (portrait/landscape).
- CLI build and deploy scripts (`build.sh`).
- Project branding with custom AppIcon assets.
- Explicit `Debug` and `Release` optimization profiles.
- Unit tests for `DepthPointProjector` math.
