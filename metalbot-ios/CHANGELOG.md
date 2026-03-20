# Changelog - metalbot-ios

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
