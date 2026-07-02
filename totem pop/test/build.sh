#!/bin/bash
# Build the Motion Sensor app from the command line.
# Usage: chmod +x build.sh && ./build.sh
#
# NOTE: The resulting binary must be run with sudo to access the HID device:
#   sudo ./build/MotionSensor

cd "$(dirname "$0")"

APP_NAME="MotionSensor"
BUILD_DIR="./build"

echo "🔨 Building $APP_NAME..."

mkdir -p "$BUILD_DIR"

swiftc \
    -framework SwiftUI \
    -framework Foundation \
    -framework IOKit \
    -framework CoreFoundation \
    -o "$BUILD_DIR/$APP_NAME" \
    MotionSensorApp.swift \
    MotionSensorManager.swift \
    ContentView.swift

if [ $? -eq 0 ]; then
    echo "✅ Build successful: $BUILD_DIR/$APP_NAME"
    echo ""
    echo "⚠️  Run with sudo (IOHIDDeviceOpen requires root):"
    echo "   sudo $BUILD_DIR/$APP_NAME"
else
    echo "❌ Build failed"
    exit 1
fi
