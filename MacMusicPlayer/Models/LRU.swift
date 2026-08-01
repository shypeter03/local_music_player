
import Foundation

/// Thread-safe LRU Cache
///
/// - capacity > 0:
///     Limit the maximum number of cached items.
/// - capacity == nil:
///     Unlimited cache.
///
/// The cache itself only manages memory.
/// Disk persistence can be built on top of it.
final class LRUCache<Key: Hashable, Value> {

    private final class Node {
        let key: Key
        var value: Value

        var prev: Node?
        var next: Node?

        init(key: Key, value: Value) {
            self.key = key
            self.value = value
        }
    }

    private let lock = NSLock()

    private var cache: [Key: Node] = [:]

    // Most recently used
    private var head: Node?

    // Least recently used
    private var tail: Node?

    /// Maximum number of items.
    ///
    /// nil = unlimited
    /// 0 = no cache
    private let capacity: Int?

    init(capacity: Int? = nil) {
        if let capacity {
            self.capacity = max(0, capacity)
        } else {
            self.capacity = nil
        }
    }

    // MARK: - Public API

    var count: Int {
        lock.lock()
        defer { lock.unlock() }

        return cache.count
    }

    var isEmpty: Bool {
        lock.lock()
        defer { lock.unlock() }

        return cache.isEmpty
    }

    /// Returns a value and marks it as recently used.
    func get(_ key: Key) -> Value? {
        lock.lock()
        defer { lock.unlock() }

        guard let node = cache[key] else {
            return nil
        }

        moveToHead(node)

        return node.value
    }

    /// Insert or update a value.
    func set(_ value: Value, forKey key: Key) {
        lock.lock()
        defer { lock.unlock() }

        // Cache disabled
        if capacity == 0 {
            return
        }

        // Existing key
        if let node = cache[key] {
            node.value = value
            moveToHead(node)
            return
        }

        // New key
        let node = Node(
            key: key,
            value: value
        )

        cache[key] = node
        insertAtHead(node)

        // Remove LRU items
        if let capacity {
            while cache.count > capacity {
                removeTail()
            }
        }
    }

    /// Remove one item.
    @discardableResult
    func remove(_ key: Key) -> Value? {
        lock.lock()
        defer { lock.unlock() }

        guard let node = cache.removeValue(forKey: key) else {
            return nil
        }

        removeNode(node)

        return node.value
    }

    /// Remove all cached items.
    func removeAll() {
        lock.lock()
        defer { lock.unlock() }

        cache.removeAll()

        head = nil
        tail = nil
    }

    /// Check whether a key exists.
    func contains(_ key: Key) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        return cache[key] != nil
    }

    /// Returns keys from most recently used -> least recently used.
    var keys: [Key] {
        lock.lock()
        defer { lock.unlock() }

        var result: [Key] = []
        var node = head

        while let current = node {
            result.append(current.key)
            node = current.next
        }

        return result
    }

    // MARK: - Linked List

    private func insertAtHead(_ node: Node) {
        node.prev = nil
        node.next = head

        head?.prev = node

        head = node

        if tail == nil {
            tail = node
        }
    }

    private func moveToHead(_ node: Node) {
        // Already head
        if head === node {
            return
        }

        removeNode(node)
        insertAtHead(node)
    }

    private func removeNode(_ node: Node) {
        let previous = node.prev
        let next = node.next

        previous?.next = next
        next?.prev = previous

        if head === node {
            head = next
        }

        if tail === node {
            tail = previous
        }

        node.prev = nil
        node.next = nil
    }

    private func removeTail() {
        guard let node = tail else {
            return
        }

        cache.removeValue(forKey: node.key)
        removeNode(node)
    }
}
