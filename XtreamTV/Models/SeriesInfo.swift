import Foundation

struct SeriesInfoResponse: Codable, Hashable {
    let info: SeriesInfo?
    let episodes: [String: [SeriesEpisode]]
}

struct SeriesInfo: Codable, Hashable {
    let name: String?
    let cover: String?
    let plot: String?
    let genre: String?

    enum CodingKeys: String, CodingKey {
        case name
        case cover
        case plot
        case genre
    }
}

struct SeriesEpisode: Identifiable, Codable, Hashable {
    let id: Int
    let title: String
    let containerExtension: String?
    let episodeNum: Int?

    enum CodingKeys: String, CodingKey {
        case id = "episode_id"
        case title
        case containerExtension = "container_extension"
        case episodeNum = "episode_num"
    }
}
