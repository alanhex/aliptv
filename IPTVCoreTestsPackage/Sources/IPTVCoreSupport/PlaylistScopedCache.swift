import Foundation

public struct PlaylistScopedCache: Sendable {
    public struct Snapshot: Equatable, Sendable {
        public var categories: [String]
        public var streams: [String]
        public var series: [String]

        public init(categories: [String], streams: [String], series: [String]) {
            self.categories = categories
            self.streams = streams
            self.series = series
        }
    }

    private var storage: [UUID: Snapshot] = [:]

    public init() {}

    public mutating func write(playlistID: UUID, snapshot: Snapshot) {
        storage[playlistID] = snapshot
    }

    public func read(playlistID: UUID) -> Snapshot? {
        storage[playlistID]
    }

    public mutating func clear(playlistID: UUID) {
        storage.removeValue(forKey: playlistID)
    }

    public var count: Int {
        storage.count
    }
}
