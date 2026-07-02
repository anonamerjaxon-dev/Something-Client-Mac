import Foundation
@testable import CursorTrail

// Minimal test harness since XCTest is not available in this toolchain.
private var _assertions = 0
private var _failures = 0

private func XCTAssert(_ condition: @autoclosure () -> Bool, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    _assertions += 1
    if !condition() {
        _failures += 1
        print("FAIL: \(message()) at \(file):\(line)")
    }
}

private func XCTAssertEqual<T: Equatable>(_ lhs: @autoclosure () -> T, _ rhs: @autoclosure () -> T, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    _assertions += 1
    if lhs() != rhs() {
        _failures += 1
        print("FAIL: \(message()) — expected \(rhs()), got \(lhs()) at \(file):\(line)")
    }
}

private func XCTAssertNil<T>(_ value: @autoclosure () -> T?, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    _assertions += 1
    if value() != nil {
        _failures += 1
        print("FAIL: \(message()) — expected nil, got \(String(describing: value())) at \(file):\(line)")
    }
}

private func XCTAssertNotNil<T>(_ value: @autoclosure () -> T?, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    _assertions += 1
    if value() == nil {
        _failures += 1
        print("FAIL: \(message()) — expected non-nil, got nil at \(file):\(line)")
    }
}

func testDefaultConfiguration() {
    let config = TrailConfiguration()
    XCTAssertEqual(config.thickness, 12.0)
    XCTAssertEqual(config.length, 100)
    XCTAssertEqual(config.style, .line)
    XCTAssertEqual(config.speedMode, .adaptive)
    XCTAssertEqual(config.opacity, 0.8)
    XCTAssertNil(config.glow)
    XCTAssertNil(config.particles)
}

func testCustomConfiguration() {
    let config = TrailConfiguration(
        color: .gradient(.red, .blue),
        thickness: 6,
        length: 200,
        style: .ribbon,
        speedMode: .fixed,
        opacity: 0.5,
        glow: GlowConfig(radius: 10, intensity: 0.6),
        particles: ParticleConfig(count: 8, size: 4, color: .white)
    )
    XCTAssertEqual(config.thickness, 6)
    XCTAssertEqual(config.length, 200)
    XCTAssertEqual(config.style, .ribbon)
    XCTAssertEqual(config.opacity, 0.5)
    XCTAssertNotNil(config.glow)
    XCTAssertNotNil(config.particles)
}

func runTrailConfigurationTests() {
    _assertions = 0
    _failures = 0

    testDefaultConfiguration()
    testCustomConfiguration()

    print("\n=== TrailConfiguration Test Results ===")
    print("Total: \(_assertions) assertions, \(_assertions - _failures) passed, \(_failures) failed")
    if _failures > 0 {
        fatalError("\(_failures) test(s) failed")
    } else {
        print("All TrailConfiguration tests PASSED ✓")
    }
}
