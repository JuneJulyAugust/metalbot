# Metalbot Development Milestone: End-to-End Control Path (2026-03-20)

## Summary
Successfully implemented and verified the full control path from the iPhone brain to the physical actuators of the RC car. This milestone bridges the gap between our high-level iOS application and low-level Arduino firmware.

### Achievements
1.  **Arduino Control Module**: Created `firmware/metalbot-arduino/`, a dedicated firmware for the Arduino Mega.
    - Implemented a normalized `-1.0 to 1.0` serial protocol for steering and motor power.
    - Included safety features: ESC arming sequence and heartbeat monitoring (currently disabled for debugging).
    - Isolated toolchain: Self-contained `arduino-cli` setup on the Raspberry Pi for easy deployment.
2.  **MCP Serial Integration**: Updated the C++ bridge on the Raspberry Pi (`metalbot-mcp`) to forward UDP commands from the iPhone to the Arduino via USB Serial.
    - Added robustness features: Auto-reconnect on I/O errors, 3.5s boot delay handling, and serial buffer flushing.
    - Integrated real-time serial feedback into the FTXUI dashboard.
3.  **Deployment & Testing**: Established robust `deploy.sh` scripts for both the Arduino and MCP modules, enabling seamless updates from the development machine to the Pi.
4.  **Hardware Verification**: Confirmed that steering commands from the iPhone correctly actuate the servo on Pin 4.

## Current State
- **Steering**: Fully operational end-to-end.
- **Motor**: ESC arming logic is in place; physical motor disconnected for safety during initial testing.
- **Robustness**: MCP gracefully handles Arduino resets and power brownouts.

## Prompt Context for Next Session
"In the last session, we completed the control path from iPhone -> Raspberry Pi (UDP) -> Arduino (Serial) -> Actuators. We have a robust MCP bridge and a self-contained Arduino deployment system. Steering is verified on Pin 4. Next steps: Safely test the motor power on Pin 8 and begin integrating the LiDAR/Vision feedback loop for autonomous control."
