import Foundation
@testable import CursorTrail

func testDefaultConfiguration() {
    let config = TrailConfiguration()
    XCTAssertEqual(config.thickness, 12.0)
    XCTAssertEqual(config.length, 10)
    XCTAssertEqual(config.style, .ribbon)
    XCTAssertEqual(config.opacity, 0.8)
    XCTAssertNil(config.glow)
}

func testCustomConfiguration() {
    let config = TrailConfiguration(
        color: .gradient(.red, .blue),
        thickness: 6,
        length: 200,
        style: .ribbon,
        opacity: 0.5,
        glow: GlowConfig(radius: 10, intensity: 0.6)
    )
    XCTAssertEqual(config.thickness, 6)
    XCTAssertEqual(config.length, 200)
    XCTAssertEqual(config.style, .ribbon)
    XCTAssertEqual(config.opacity, 0.5)
    XCTAssertNotNil(config.glow)
}

func runTrailConfigurationTests() {
    runTestSuite("TrailConfiguration") {
        testDefaultConfiguration()
        testCustomConfiguration()
    }
}