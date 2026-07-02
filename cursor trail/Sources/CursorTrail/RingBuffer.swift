import Foundation

/// Fixed-size ring buffer for efficient trail point storage.
/// When full, new entries overwrite the oldest.
public struct RingBuffer<T> {
    private var storage: [T?]
    private var head: Int = 0
    private var tail: Int = 0
    private var _count: Int = 0
    private let capacity: Int

    public init(capacity: Int) {
        precondition(capacity > 0, "Capacity must be positive")
        self.capacity = capacity
        self.storage = Array(repeating: nil, count: capacity)
    }

    public var isEmpty: Bool { _count == 0 }
    public var isFull: Bool { _count == capacity }
    public var count: Int { _count }

    public var first: T? {
        guard !isEmpty else { return nil }
        return self[0]
    }

    public var last: T? {
        guard !isEmpty else { return nil }
        return self[count - 1]
    }

    public mutating func append(_ element: T) {
        storage[tail] = element
        if isFull {
            head = (head + 1) % capacity
        } else {
            _count += 1
        }
        tail = (tail + 1) % capacity
    }

    public mutating func removeFirst() -> T? {
        guard !isEmpty else { return nil }
        let element = storage[head]
        storage[head] = nil
        head = (head + 1) % capacity
        _count -= 1
        return element
    }

    public mutating func clear() {
        storage = Array(repeating: nil, count: capacity)
        head = 0
        tail = 0
        _count = 0
    }

    public subscript(index: Int) -> T {
        precondition(index >= 0 && index < count, "Index out of bounds")
        let actualIndex = (head + index) % capacity
        return storage[actualIndex]!
    }

    public func toArray() -> [T] {
        var result: [T] = []
        result.reserveCapacity(count)
        for i in 0..<count {
            result.append(self[i])
        }
        return result
    }
}
