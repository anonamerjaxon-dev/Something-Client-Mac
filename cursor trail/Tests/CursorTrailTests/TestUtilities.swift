import Foundation

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

func XCTAssertFalse(_ condition: @autoclosure () -> Bool, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    XCTAssert(!condition(), message(), file: file, line: line)
}

func XCTAssertNil<T>(_ value: @autoclosure () -> T?, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    testAssertions += 1
    if value() != nil {
        testFailures += 1
        print("FAIL: \(message()) — expected nil, got \(String(describing: value())) at \(file):\(line)")
    }
}

func XCTAssertNotNil<T>(_ value: @autoclosure () -> T?, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    testAssertions += 1
    if value() == nil {
        testFailures += 1
        print("FAIL: \(message()) — expected non-nil, got nil at \(file):\(line)")
    }
}

func runTestSuite(_ name: String, tests: () -> Void) {
    testAssertions = 0
    testFailures = 0
    tests()
    print("\n=== \(name) ===")
    print("\(testAssertions) assertions, \(testAssertions - testFailures) passed, \(testFailures) failed")
    if testFailures > 0 {
        fatalError("\(testFailures) test(s) failed in \(name)")
    } else {
        print("\(name): PASSED ✓")
    }
}