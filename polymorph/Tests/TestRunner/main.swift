import AppKit
import Foundation
@testable import Polymorph

var testAssertions = 0
var testFailures = 0

func XCTAssert(_ condition: @autoclosure () -> Bool, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    testAssertions += 1
    if !condition() {
        testFailures += 1
        print("FAIL: \(message()) at \(file):\(line)")
    }
}

func XCTAssertEqual<T: Equatable>(_ lhs: @autoclosure () -> T, _ rhs: @autoclosure () -> T, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    testAssertions += 1
    if lhs() != rhs() {
        testFailures += 1
        print("FAIL: \(message()) — expected \(rhs()), got \(lhs()) at \(file):\(line)")
    }
}

func XCTAssertTrue(_ condition: @autoclosure () -> Bool, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    XCTAssert(condition(), message(), file: file, line: line)
}

func XCTAssertNil<T>(_ value: @autoclosure () -> T?, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    testAssertions += 1
    if value() != nil {
        testFailures += 1
        print("FAIL: \(message()) at \(file):\(line)")
    }
}

func XCTAssertNotNil<T>(_ value: @autoclosure () -> T?, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    testAssertions += 1
    if value() == nil {
        testFailures += 1
        print("FAIL: \(message()) at \(file):\(line)")
    }
}

func XCTAssertThrowsError<T>(_ expression: @autoclosure () throws -> T, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    testAssertions += 1
    do {
        _ = try expression()
        testFailures += 1
        print("FAIL: \(message()) — expected error at \(file):\(line)")
    } catch {}
}

func runSuite(_ name: String, tests: () -> Void) {
    let before = testFailures
    tests()
    print("\n=== \(name) ===")
    print("\(testAssertions) assertions, \(testAssertions - (testFailures - before)) passed, \(testFailures - before) failed")
}

let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent("polymorph-tests")

func makePNG(width: Int, height: Int, at url: URL) throws {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width,
        pixelsHigh: height,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSColor.systemBlue.setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: width, height: height)).fill()
    NSGraphicsContext.restoreGraphicsState()
    try rep.representation(using: .png, properties: [:])!.write(to: url)
}

func testStateMappingComplete() {
    for state in CursorState.allCases {
        XCTAssert(!state.cgsNames.isEmpty, "\(state.rawValue) must map to at least one CGS name")
        for name in state.cgsNames {
            XCTAssertTrue(name.hasPrefix("com.apple."), "\(name) should be namespaced")
        }
    }
    let stems = Set(CursorState.allCases.map(\.rawValue))
    XCTAssertEqual(stems.count, CursorState.allCases.count, "state raw values must be unique")
}

func testThemeMinimalArrowOnly() throws {
    let dir = tempRoot.appendingPathComponent("minimal")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    try makePNG(width: 16, height: 16, at: dir.appendingPathComponent("arrow.png"))

    let theme = try CursorTheme.load(directory: dir)
    XCTAssertEqual(theme.name, "minimal")
    XCTAssertEqual(theme.cursors.count, 1)
    XCTAssertEqual(theme.cursors[0].state, .arrow)
}

func testThemeMissingArrowThrows() throws {
    let dir = tempRoot.appendingPathComponent("noarrow")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    try makePNG(width: 8, height: 8, at: dir.appendingPathComponent("ibeam.png"))
    XCTAssertThrowsError(try CursorTheme.load(directory: dir), "missing arrow must throw")
}

func testThemeUnknownHotspotKeyThrows() throws {
    let dir = tempRoot.appendingPathComponent("badkey")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    try makePNG(width: 8, height: 8, at: dir.appendingPathComponent("arrow.png"))
    try "{\"hotspots\": {\"notAState\": [1,2]}}".write(to: dir.appendingPathComponent("theme.json"), atomically: true, encoding: .utf8)
    XCTAssertThrowsError(try CursorTheme.load(directory: dir), "unknown hotspot key must throw")
}

func testThemeOverridesAndDefaults() throws {
    let dir = tempRoot.appendingPathComponent("overrides")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    try makePNG(width: 64, height: 64, at: dir.appendingPathComponent("arrow.png"))
    try makePNG(width: 16, height: 16, at: dir.appendingPathComponent("pointingHand.png"))
    try makePNG(width: 32, height: 32, at: dir.appendingPathComponent("pointingHand@2x.png"))
    try """
    {"name": "Tuff", "hotspots": {"arrow": [3, 1]}, "sizes": {"arrow": 24}}
    """.write(to: dir.appendingPathComponent("theme.json"), atomically: true, encoding: .utf8)

    let theme = try CursorTheme.load(directory: dir)
    XCTAssertEqual(theme.name, "Tuff")
    let arrow = theme.cursors.first { $0.state == .arrow }!
    XCTAssertEqual(arrow.hotspot.x, 3)
    XCTAssertEqual(arrow.hotspot.y, 1)
    XCTAssertEqual(arrow.pointSize.width, 24)

    let hand = theme.cursors.first { $0.state == .pointingHand }!
    let systemHand = NSCursor.pointingHand
    XCTAssertEqual(hand.pointSize.width, systemHand.image.size.width)
    XCTAssertEqual(hand.hotspot, systemHand.hotSpot)
    XCTAssertNotNil(hand.retinaFile)
}

func testLoaderProducesScaledReps() throws {
    let dir = tempRoot.appendingPathComponent("loader")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let png = dir.appendingPathComponent("arrow.png")
    try makePNG(width: 10, height: 20, at: png)

    let images = try ThemeImageLoader.cgImages(oneXURL: png, retinaURL: nil, pointSize: CGSize(width: 16, height: 32))
    XCTAssertEqual(images.count, 2)
    XCTAssertEqual(images[0].width, 16)
    XCTAssertEqual(images[0].height, 32)
    XCTAssertEqual(images[1].width, 32)
    XCTAssertEqual(images[1].height, 64)
}

func testSVGLoading() throws {
    let dir = tempRoot.appendingPathComponent("svg")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let svg = """
    <svg xmlns="http://www.w3.org/2000/svg" width="16" height="24" viewBox="0 0 16 24">
      <path d="M2 2 L2 22 M14 2 L14 22 M2 2 L14 2" stroke="#2563eb" stroke-width="2" fill="none"/>
    </svg>
    """
    try svg.write(to: dir.appendingPathComponent("ibeam.svg"), atomically: true, encoding: .utf8)
    try makePNG(width: 16, height: 16, at: dir.appendingPathComponent("arrow.png"))

    let theme = try CursorTheme.load(directory: dir)
    let ibeam = theme.cursors.first { $0.state == .ibeam }
    XCTAssertNotNil(ibeam, "svg ibeam must be discovered")

    let images = try ThemeImageLoader.cgImages(oneXURL: ibeam!.imageFile, retinaURL: nil, pointSize: CGSize(width: 12, height: 18))
    XCTAssertEqual(images[0].width, 12)
    XCTAssertEqual(images[0].height, 18)
}

func testBridgeSymbolResolution() {
    if CGSBridge.isAvailable() {
        XCTAssertNotNil(try? CGSBridge.shared.mainConnectionID(), "main connection id should resolve")
    } else {
        print("SKIP: CGS bridge unavailable on this OS")
    }
}

try? FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)

runSuite("CursorStateMapping") {
    testStateMappingComplete()
}

runSuite("CursorTheme") {
    try? testThemeMinimalArrowOnly()
    try? testThemeMissingArrowThrows()
    try? testThemeUnknownHotspotKeyThrows()
    try? testThemeOverridesAndDefaults()
}

runSuite("ThemeImageLoader") {
    try? testLoaderProducesScaledReps()
    try? testSVGLoading()
}

runSuite("CGSBridge") {
    testBridgeSymbolResolution()
}

print("\nTotal: \(testAssertions) assertions, \(testFailures) failed")
if testFailures > 0 {
    exit(1)
}
