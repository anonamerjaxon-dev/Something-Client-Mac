import Foundation
@testable import CursorTrail

func testEmptyBuffer() {
    var buffer = RingBuffer<Int>(capacity: 5)
    XCTAssertTrue(buffer.isEmpty)
    XCTAssertEqual(buffer.count, 0)
}

func testAppendUntilFull() {
    var buffer = RingBuffer<Int>(capacity: 3)
    buffer.append(1)
    buffer.append(2)
    buffer.append(3)
    XCTAssertEqual(buffer.count, 3)
}

func testOverwriteOldest() {
    var buffer = RingBuffer<Int>(capacity: 3)
    buffer.append(1)
    buffer.append(2)
    buffer.append(3)
    buffer.append(4)
    XCTAssertEqual(buffer.count, 3)
    XCTAssertEqual(buffer[0], 2)
    XCTAssertEqual(buffer[2], 4)
}

func testClear() {
    var buffer = RingBuffer<Int>(capacity: 5)
    buffer.append(1)
    buffer.append(2)
    buffer.clear()
    XCTAssertTrue(buffer.isEmpty)
    XCTAssertEqual(buffer.count, 0)
}

func runRingBufferTests() {
    runTestSuite("RingBuffer") {
        testEmptyBuffer()
        testAppendUntilFull()
        testOverwriteOldest()
        testClear()
    }
}