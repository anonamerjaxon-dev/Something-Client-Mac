# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

A SwiftUI app that reads live accelerometer data from the Bosch BMI286 IMU chip built into Apple Silicon Macs (M2+, M3, M4, or M1 Pro). The app opens the sensor via IOHID (same technique as the [spank](github.com/taigrr/spank) project) and displays X/Y/Z acceleration in g-force units with visual bars.

## Architecture

```
MotionSensorApp.swift        @main entry point, SwiftUI App lifecycle
ContentView.swift            UI: header, axis rows with visual bars, magnitude, footer
MotionSensorManager.swift    Core logic: runs on a background thread
                           1. wakeSPUDrivers()  - sets reporting/power props on AppleSPUHIDDriver
                           2. openAccelerometerDevice() - enumerates AppleSPUHIDDevice, matches vendor page 0xFF00 + usage 3
                           3. IOHIDDeviceRegisterInputReportCallback - parses 22-byte HID reports (3x int32 at offset 6)
                           4. CFRunLoopRunInMode - keeps the sensor thread alive
```

## Build & Run

```bash
cd test
./build.sh
sudo ./build/MotionSensor
```

Or manually:

```bash
cd test
swiftc -framework SwiftUI -framework Foundation -framework IOKit -framework CoreFoundation -o build/MotionSensor MotionSensorApp.swift MotionSensorManager.swift ContentView.swift
sudo ./build/MotionSensor
```

**Requires `sudo`** — `IOHIDDeviceOpen` needs root to access the accelerometer chip.

## Hardware Requirements

- Apple Silicon Mac: M2, M3, M4 (any) or M1 Pro
- Will NOT work on: base M1, M1 Air, M1 Max/Ultra, Intel Macs
- The Bosch BMI286 IMU must be present

## Key Details

- Updates at ~20 Hz via HID input reports
- Values at rest: X~0.0g, Y~0.0g, Z~-1.0g (gravity), Magnitude~1.0g
- The sensor thread uses `CFRunLoopRunInMode` to deliver async HID callbacks
- Report buffer (4096 bytes) must outlive the callback — stored as `reportBuffer` property
- UI updates are dispatched to the main queue via `DispatchQueue.main.async`
