# metalbot

`metalbot` is an iPhone-first autonomous RC car project.

The name comes from Apple Metal: the app will rely on high-performance iPhone GPU/compute paths for perception over time.

The iPhone runs perception, estimation, and high-level control. STM32 acts as MCP (motor/control processor) for low-level actuation and watchdog behavior.

## Product Direction

1. **MVP1 (active): LiDAR-only closed loop**
   - LiDAR depth sensing
   - IMU-first velocity estimation
   - speed planner + feedback control (reach target speed, then keep it)
   - straight driving by yaw-rate hold
   - planner-triggered stop when obstacle points block future path
2. **MVP2 (parallel): RGB to mono depth prototype**
   - camera stream + Core ML depth inference on iPhone
3. **MVP3 (future): sparse LiDAR + RGB depth completion**
   - fuse sparse LiDAR and monocular depth (candidate direction includes MetricAnything-style approaches)

## Hardware and Constraints

- iPhone 13 Pro / iPhone 13 Pro Max
- RC chassis with steering and throttle actuation
- STM32 MCP over BLE or Wi-Fi (both will be tested)
- Flat indoor floor for MVP1
- Vehicle speed target range (initial): `0.1` to `2.0` m/s

## Repository Docs

- `.ai-context/plan.md`: high-level plan with invariants and architecture levels
- `.ai-context/task.md`: hierarchical task backlog by MVP
- `.ai-context/walkthrough.md`: implementation-time development log

## Key APIs and Sensors

- LiDAR depth: `AVCaptureDevice.DeviceType.builtInLiDARDepthCamera` (iOS 15.4+).
- Depth stream: `AVCaptureDepthDataOutput` with confidence maps.
- IMU: Core Motion (`CMDeviceMotion` for fused gyro + accelerometer + optional magnetometer).
- GPU compute: Apple Metal for future on-device perception workloads.

## Build and Deploy

Use Xcode once for signing/capabilities, then iterate from CLI if preferred.

- build: `xcodebuild`
- install/launch: `xcrun devicectl` (Xcode 15+)

```bash
# 1) List connected devices
xcrun devicectl list devices

# 2) Build app for iOS device
xcodebuild \
  -project metalbot.xcodeproj \
  -scheme metalbot \
  -configuration Debug \
  -destination "generic/platform=iOS" \
  -derivedDataPath .build/DerivedData \
  build

# 3) Install built app bundle
xcrun devicectl device install app \
  --device <DEVICE_UDID> \
  .build/DerivedData/Build/Products/Debug-iphoneos/metalbot.app

# 4) Launch app
xcrun devicectl device process launch \
  --device <DEVICE_UDID> \
  com.your.bundle.id
```
