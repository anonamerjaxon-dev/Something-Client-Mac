import Foundation
import IOKit
import IOKit.hid
import CoreFoundation

/// Reads the Bosch BMI286 IMU accelerometer from Apple Silicon Macs via IOHID.
///
/// Uses the same technique as the `spank` project (taigrr/spank):
/// 1. Wakes the AppleSPUHIDDriver by setting reporting/power properties
/// 2. Enumerates AppleSPUHIDDevice services, finds the accelerometer
/// 3. Opens the IOHIDDevice and registers an input-report callback
/// 4. Parses 22-byte HID reports (3× int32 XYZ at byte offset 6)
///
/// Requires `sudo` because IOHIDDeviceOpen needs root privileges.
/// Only available on Apple Silicon Macs (M2+, or M1 Pro).
final class MotionSensorManager: ObservableObject {

    // MARK: - Published state

    @Published var x: Double = 0.0
    @Published var y: Double = 0.0
    @Published var z: Double = 0.0
    @Published var magnitude: Double = 0.0
    @Published private(set) var isConnected = false
    @Published private(set) var statusMessage = "Initializing…"

    // MARK: - HID report format (Bosch BMI286)

    private static let imuReportLen = 22
    private static let imuDataOffset = 6       // XYZ payload starts here
    private static let reportBufSize = 4096

    // MARK: - Apple SPU HID constants

    private static let pageVendor: Int = 0xFF00
    private static let usageAccel: Int = 3

    // MARK: - Private

    private var sensorThread: Thread?
    private var reportBuffer: [UInt8]?
    private var deviceRef: IOHIDDevice?

    // MARK: - Lifecycle

    deinit {
        stop()
    }

    // MARK: - Public API

    func start() {
        guard sensorThread == nil else { return }

        let thread = Thread { [weak self] in
            self?.sensorLoop()
        }
        thread.name = "MotionSensor"
        thread.qualityOfService = .userInteractive
        sensorThread = thread
        thread.start()
    }

    func stop() {
        sensorThread?.cancel()
        sensorThread = nil
        if let device = deviceRef {
            IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
            deviceRef = nil
        }
        reportBuffer = nil
    }

    // MARK: - Sensor thread

    private func sensorLoop() {
        // Step 1: Wake up the SPU HID drivers.
        wakeSPUDrivers()

        // Step 2: Find and open the accelerometer HID device.
        guard let device = openAccelerometerDevice() else {
            DispatchQueue.main.async { [weak self] in
                self?.isConnected = false
                self?.statusMessage = "No accelerometer found.\nRequires Apple Silicon Mac (M2+ or M1 Pro) and sudo."
            }
            return
        }

        deviceRef = device

        // Step 3: Allocate the report buffer (must outlive the callback).
        var buffer = [UInt8](repeating: 0, count: Self.reportBufSize)
        reportBuffer = buffer

        // Step 4: Register the input-report callback.
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let callback: IOHIDReportCallback = { context, _, _, _, _, report, reportLen in
            guard let context = context else { return }
            let manager = Unmanaged<MotionSensorManager>.fromOpaque(context).takeUnretainedValue()
            manager.handleReport(report, length: reportLen)
        }

        IOHIDDeviceRegisterInputReportCallback(
            device,
            &buffer,
            buffer.count,
            callback,
            selfPtr
        )

        // Step 5: Schedule the device on this thread's run loop.
        IOHIDDeviceScheduleWithRunLoop(
            device,
            CFRunLoopGetCurrent(),
            "kCFRunLoopDefaultMode" as CFString
        )

        DispatchQueue.main.async { [weak self] in
            self?.isConnected = true
            self?.statusMessage = "Connected to BMI286 IMU (Apple Silicon)"
        }

        // Step 6: Run the CFRunLoop forever (delivers HID callbacks).
        while !(sensorThread?.isCancelled ?? true) {
            CFRunLoopRunInMode(CFRunLoopMode.defaultMode!, 0.1, true)
        }
    }

    // MARK: - Wake SPU drivers

    private func wakeSPUDrivers() {
        guard let matching = IOServiceMatching("AppleSPUHIDDriver") else { return }
        var iterator: io_iterator_t = 0
        let kr = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard kr == KERN_SUCCESS else { return }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            var val: Int32 = 1
            let num = CFNumberCreate(kCFAllocatorDefault, .sInt32Type, &val)
            IORegistryEntrySetCFProperty(service, "SensorPropertyReportingState" as CFString, num)
            IORegistryEntrySetCFProperty(service, "SensorPropertyPowerState" as CFString, num)

            var interval: Int32 = 1000
            let intervalNum = CFNumberCreate(kCFAllocatorDefault, .sInt32Type, &interval)
            IORegistryEntrySetCFProperty(service, "ReportInterval" as CFString, intervalNum)

            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        IOObjectRelease(iterator)
    }

    // MARK: - Open accelerometer device

    private func openAccelerometerDevice() -> IOHIDDevice? {
        guard let matching = IOServiceMatching("AppleSPUHIDDevice") else { return nil }
        var iterator: io_iterator_t = 0
        let kr = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard kr == KERN_SUCCESS else { return nil }

        var foundDevice: IOHIDDevice?
        var service = IOIteratorNext(iterator)

        while service != 0 && foundDevice == nil {
            // Read PrimaryUsagePage and PrimaryUsage to identify the accelerometer.
            if let pageValue = IORegistryEntryCreateCFProperty(service, "PrimaryUsagePage" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Int,
               let usageValue = IORegistryEntryCreateCFProperty(service, "PrimaryUsage" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Int,
               pageValue == Self.pageVendor,
               usageValue == Self.usageAccel {

                let device = IOHIDDeviceCreate(kCFAllocatorDefault, service)
                if let device = device {
                    let openResult = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
                    if openResult == KERN_SUCCESS {
                        foundDevice = device
                    }
                }
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }

        IOObjectRelease(iterator)
        return foundDevice
    }

    // MARK: - Report handling

    private func handleReport(_ report: UnsafePointer<UInt8>, length: CFIndex) {
        guard length >= Self.imuReportLen else { return }

        // Parse 3× int32 little-endian values at the IMU data offset.
        let xRaw = report.withMemoryRebound(to: Int32.self, capacity: 6) { ptr in
            Int32(littleEndian: ptr[Self.imuDataOffset / 4])
        }
        let yRaw = report.withMemoryRebound(to: Int32.self, capacity: 6) { ptr in
            Int32(littleEndian: ptr[(Self.imuDataOffset + 4) / 4])
        }
        let zRaw = report.withMemoryRebound(to: Int32.self, capacity: 6) { ptr in
            Int32(littleEndian: ptr[(Self.imuDataOffset + 8) / 4])
        }

        // The BMI286 driver outputs values already scaled to g-force units.
        let x = Double(xRaw)
        let y = Double(yRaw)
        let z = Double(zRaw)
        let mag = sqrt(x * x + y * y + z * z)

        DispatchQueue.main.async { [weak self] in
            self?.x = x
            self?.y = y
            self?.z = z
            self?.magnitude = mag
        }
    }
}
