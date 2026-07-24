import Foundation

public struct RingBuffer<T> {
    private var storage: [T?]
    private var writeIndex: Int = 0
    private var readIndex: Int = 0
    private var _count: Int = 0
    private let capacity: Int

    public init(capacity: Int) {
        precondition(capacity > 0, "Capacity must be positive")
        self.capacity = capacity
        self.storage = Array(repeating: nil, count: capacity)
    }

    public var isEmpty: Bool { _count == 0 }
    public var count: Int { _count }

    public var first: T? {
        isEmpty ? nil : self[0]
    }

    public mutating func append(_ element: T) {
        storage[writeIndex] = element
        if _count == capacity {
            readIndex = (readIndex + 1) % capacity
        } else {
            _count += 1
        }
        writeIndex = (writeIndex + 1) % capacity
    }

    @discardableResult
    public mutating func removeFirst() -> T? {
        guard !isEmpty else { return nil }
        let element = storage[readIndex]
        storage[readIndex] = nil
        readIndex = (readIndex + 1) % capacity
        _count -= 1
        return element
    }

    public mutating func clear() {
        storage = Array(repeating: nil, count: capacity)
        readIndex = 0
        writeIndex = 0
        _count = 0
    }

    public subscript(index: Int) -> T {
        precondition(index >= 0 && index < count, "Index out of bounds")
        return storage[(readIndex + index) % capacity]!
    }
}