import XCTest
@testable import IPTVCoreSupport

final class EpisodeParserTests: XCTestCase {
    func testDictionaryEpisodesShape() throws {
        let json = #"""
        {
          "episodes": {
            "1": [
              {"id": "101", "episode_num": 1, "title": "Pilote", "container_extension": "mp4"}
            ],
            "2": [
              {"id": "102", "episode_num": 1, "title": "Retour", "container_extension": "mkv"}
            ]
          }
        }
        """#.data(using: .utf8)!

        let credentials = IPTVCredentials(baseURL: "http://example.com", username: "u", password: "p")
        let episodes = try XtreamEpisodeParser.parse(from: json, credentials: credentials, fallbackSeriesID: "999")
            .sorted { $0.id < $1.id }

        XCTAssertEqual(episodes.count, 2)
        XCTAssertEqual(episodes[0].season, 1)
        XCTAssertEqual(episodes[0].streamURL, "http://example.com/series/u/p/101.mp4")
        XCTAssertEqual(episodes[1].season, 2)
        XCTAssertEqual(episodes[1].streamURL, "http://example.com/series/u/p/102.mkv")
    }

    func testArrayEpisodesShapeWithDirectSource() throws {
        let json = #"""
        {
          "episodes": [
            {"id": 2001, "season": 3, "episode_num": 7, "title": "Direct", "direct_source": "https://cdn.example.com/direct.m3u8"}
          ]
        }
        """#.data(using: .utf8)!

        let credentials = IPTVCredentials(baseURL: "http://example.com", username: "u", password: "p")
        let episodes = try XtreamEpisodeParser.parse(from: json, credentials: credentials, fallbackSeriesID: "999")

        XCTAssertEqual(episodes.count, 1)
        XCTAssertEqual(episodes[0].id, "2001")
        XCTAssertEqual(episodes[0].season, 3)
        XCTAssertEqual(episodes[0].number, 7)
        XCTAssertEqual(episodes[0].streamURL, "https://cdn.example.com/direct.m3u8")
    }
}
