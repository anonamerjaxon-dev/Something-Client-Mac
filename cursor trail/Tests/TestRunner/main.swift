import Foundation
@testable import CursorTrail

// MARK: - Minimal Test Harness
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

private func XCTAssertTrue(_ condition: @autoclosure () -> Bool, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    XCTAssert(condition(), message(), file: file, line: line)
}

private func XCTAssertFalse(_ condition: @autoclosure () -> Bool, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    XCTAssert(!condition(), message(), file: file, line: line)
}

// MARK: - RingBuffer Tests

func testEmptyBuffer() {
    var buffer = RingBuffer<Int>(capacity: 5)
    XCTAssertTrue(buffer.isEmpty)
    XCTAssertFalse(buffer.isFull)
    XCTAssertEqual(buffer.count, 0)
}

func testAppendUntilFull() {
    var buffer = RingBuffer<Int>(capacity: 3)
    buffer.append(1)
    buffer.append(2)
    buffer.append(3)
    XCTAssertTrue(buffer.isFull)
    XCTAssertEqual(buffer.count, 3)
}

func testOverwriteOldest() {
    var buffer = RingBuffer<Int>(capacity: 3)
    buffer.append(1)
    buffer.append(2)
    buffer.append(3)
    buffer.append(4) // overwrites 1
    XCTAssertEqual(buffer.count, 3)
    XCTAssertEqual(buffer[0], 2) // oldest is now 2
    XCTAssertEqual(buffer[2], 4) // newest is 4
}

func testClear() {
    var buffer = RingBuffer<Int>(capacity: 5)
    buffer.append(1)
    buffer.append(2)
    buffer.clear()
    XCTAssertTrue(buffer.isEmpty)
    XCTAssertEqual(buffer.count, 0)
}

// MARK: - Test Runner

print("=== Running RingBuffer Tests ===")

testEmptyBuffer()
testAppendUntilFull()
testOverwriteOldest()
testClear()

print("\n=== Results ===")
print("Total: \(_assertions) assertions, \(_assertions - _failures) passed, \(_failures) failed")
if _failures > 0 {
    print("FAIL: \(_failures) test(s) failed")
    exit(1)
} else {
    print("All tests PASSED ✓")
}
