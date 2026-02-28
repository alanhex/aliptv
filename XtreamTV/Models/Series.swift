import Foundation
import SwiftData

@Model
final class Series {
    @Attribute(.unique) var cacheKey: String
    var playlistID: UUID
    var categoryID: String
    var seriesID: String
    var title: String
    var coverURL: String?
    var synopsis: String?
    var updatedAt: Date

    init(
        playlistID: UUID,
        categoryID: String,
        seriesID: String,
        title: String,
        coverURL: String? = nil,
        synopsis: String? = nil,
        updatedAt: Date = .now
    ) {
        self.playlistID = playlistID
        self.categoryID = categoryID
        self.seriesID = seriesID
        self.title = title
        self.coverURL = coverURL
        self.synopsis = synopsis
        self.updatedAt = updatedAt
        self.cacheKey = "\(playlistID.uuidString)|series|\(categoryID)|\(seriesID)"
    }
}

@Model
final class SeriesEpisode {
    @Attribute(.unique) var cacheKey: String
    var playlistID: UUID
    var seriesID: String
    var episodeID: String
    var seasonNumber: Int
    var episodeNumber: Int
    var title: String
    var streamURL: String
    var overview: String?
    var updatedAt: Date

    init(
        playlistID: UUID,
        seriesID: String,
        episodeID: String,
        seasonNumber: Int,
        episodeNumber: Int,
        title: String,
        streamURL: String,
        overview: String? = nil,
        updatedAt: Date = .now
    ) {
        self.playlistID = playlistID
        self.seriesID = seriesID
        self.episodeID = episodeID
        self.seasonNumber = seasonNumber
        self.episodeNumber = episodeNumber
        self.title = title
        self.streamURL = streamURL
        self.overview = overview
        self.updatedAt = updatedAt
        self.cacheKey = "\(playlistID.uuidString)|\(seriesID)|\(episodeID)"
    }

    var asPlayable: PlayableItem {
        PlayableItem(
            id: cacheKey,
            title: title,
            subtitle: "S\(seasonNumber) E\(episodeNumber)",
            streamURL: streamURL,
            mediaType: .series,
            playlistID: playlistID
        )
    }
}
