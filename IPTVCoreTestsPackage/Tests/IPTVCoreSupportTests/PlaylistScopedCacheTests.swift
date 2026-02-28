import XCTest
@testable import IPTVCoreSupport

final class PlaylistScopedCacheTests: XCTestCase {
    func testReadWriteIsScopedPerPlaylist() {
        var cache = PlaylistScopedCache()
        let playlistA = UUID()
        let playlistB = UUID()

        cache.write(
            playlistID: playlistA,
            snapshot: .init(categories: ["News"], streams: ["A1"], series: ["S1"])
        )
        cache.write(
            playlistID: playlistB,
            snapshot: .init(categories: ["Sports"], streams: ["B1", "B2"], series: [])
        )

        XCTAssertEqual(cache.read(playlistID: playlistA)?.categories, ["News"])
        XCTAssertEqual(cache.read(playlistID: playlistB)?.streams, ["B1", "B2"])
        XCTAssertEqual(cache.count, 2)
    }

    func testClearRemovesOnlyRequestedPlaylist() {
        var cache = PlaylistScopedCache()
        let playlistA = UUID()
        let playlistB = UUID()

        cache.write(playlistID: playlistA, snapshot: .init(categories: ["A"], streams: ["1"], series: ["x"]))
        cache.write(playlistID: playlistB, snapshot: .init(categories: ["B"], streams: ["2"], series: ["y"]))

        cache.clear(playlistID: playlistA)

        XCTAssertNil(cache.read(playlistID: playlistA))
        XCTAssertNotNil(cache.read(playlistID: playlistB))
        XCTAssertEqual(cache.count, 1)
    }
}
