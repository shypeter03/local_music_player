import Foundation

/// Persistent LRU playback history.
///
/// The first element is the most recently played track.
/// The last element is the least recently played track.
///
/// Example:
///
/// [A, B, C]
///
/// play(B)
///
/// [B, A, C]
///
/// If capacity == 3 and play(D):
///
/// [D, B, A]
///
/// C is evicted.
final class PlaybackHistoryQueue {

    // MARK: - Configuration

    private let capacity: Int?

    private let storageKey = "savedPlayHistoryQueueIDs"

    private let defaults: UserDefaults

    // MARK: - State

    /// Most recently played -> least recently played
    private(set) var ids: [String] = []

    // MARK: - Init

    init(
        capacity: Int? = 100,
        defaults: UserDefaults = .standard
    ) {
        self.capacity = capacity
        self.defaults = defaults

        load()
    }

    // MARK: - Public

    /// Record a track as recently played.
    ///
    /// If the track already exists, it is moved to the front.
    /// If the capacity is exceeded, the least recently played
    /// track is removed.
    func record(_ trackID: String) {

        // Remove existing occurrence.
        print("写入记录:\(trackID)")
        if let index = ids.firstIndex(of: trackID) {
            ids.remove(at: index)
        }

        // Add as MRU.
        ids.insert(trackID, at: 0)

        // Apply capacity.
        if let capacity {

            if capacity <= 0 {
                ids.removeAll()
            } else if ids.count > capacity {
                ids.removeLast(
                    ids.count - capacity
                )
            }
        }

        print("当前整体记录:\(ids)")
        save()
    }
    // @discardableResult
    func pop() -> String? {
        guard !ids.isEmpty else {
            return nil
        }

        let trackID = ids.removeFirst()

        save()

        return trackID
    }

    /// Remove a specific track from history.
    func remove(_ trackID: String) {

        guard let index = ids.firstIndex(of: trackID) else {
            return
        }

        ids.remove(at: index)

        save()
    }

    /// Remove all playback history.
    func clear() {
        ids.removeAll()

        save()
    }

    /// Returns whether the track exists in history.
    func contains(_ trackID: String) -> Bool {
        ids.contains(trackID)
    }

    /// Number of history items.
    var count: Int {
        ids.count
    }

    // MARK: - Persistence

    private func save() {

        do {
            let data = try JSONEncoder().encode(ids)

            defaults.set(
                data,
                forKey: storageKey
            )

        } catch {
            print(
                "Failed to save playback history:",
                error
            )
        }
    }

    private func load() {

        guard let data = defaults.data(
            forKey: storageKey
        ) else {
            return
        }

        do {

            ids = try JSONDecoder().decode(
                [String].self,
                from: data
            )

            // Protect against an old/invalid persisted state.
            if let capacity {

                if capacity <= 0 {
                    ids.removeAll()
                } else if ids.count > capacity {
                    ids = Array(
                        ids.prefix(capacity)
                    )
                }
            }

        } catch {

            print(
                "Failed to load playback history:",
                error
            )

            ids = []
        }
    }
}
