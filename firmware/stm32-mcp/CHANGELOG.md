# Changelog

All notable changes to this project will be documented in this file.

## [1.0.0] - 2026-03-27

### Added
- Initial creation of `stm32-mcp` firmware target using STM32CubeMX and STM32CubeCLT.
- Target device: STM32L475 (Cortex-M4 with FPU).
- `build.sh` script for unified configure, compile, and flash on macOS with `arm-none-eabi-gcc` toolchain.
- Debug and Release CMakePresets configuration.
