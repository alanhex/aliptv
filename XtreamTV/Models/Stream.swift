import Foundation
import SwiftData

@Model
final class Stream {
    @Attribute(.unique) var cacheKey: String
    var playlistID: UUID
    var mediaTypeRaw: String
    var streamID: String
    var categoryID: String
    var title: String
    var streamURL: String
    var logoURL: String?
    var synopsis: String?
    var genre: String?
    var releaseYear: String?
    var rating: String?
    var updatedAt: Date

    // Enrichment fields (populated by get_vod_info)
    var backdropURL: String?
    var duration: String?
    var director: String?
    var cast: String?
    var tmdbID: String?
    var youtubeTrailerID: String?
    var containerExtension: String?
    var enrichedAt: Date?

    init(
        playlistID: UUID,
        mediaType: MediaType,
        streamID: String,
        categoryID: String,
        title: String,
        streamURL: String,
        logoURL: String? = nil,
        synopsis: String? = nil,
        genre: String? = nil,
        releaseYear: String? = nil,
        rating: String? = nil,
        updatedAt: Date = .now
    ) {
        self.playlistID = playlistID
        self.mediaTypeRaw = mediaType.rawValue
        self.streamID = streamID
        self.categoryID = categoryID
        self.title = title
        self.streamURL = streamURL
        self.logoURL = logoURL
        self.synopsis = synopsis
        self.genre = genre
        self.releaseYear = releaseYear
        self.rating = rating
        self.updatedAt = updatedAt
        self.cacheKey = "\(playlistID.uuidString)|\(mediaType.rawValue)|\(categoryID)|\(streamID)"
    }

    var mediaType: MediaType {
        MediaType(rawValue: mediaTypeRaw) ?? .live
    }

    var asPlayable: PlayableItem {
        PlayableItem(
            id: "\(playlistID.uuidString)|\(mediaTypeRaw)|\(streamID)",
            title: title,
            subtitle: mediaType.displayName,
            streamURL: streamURL,
            mediaType: mediaType,
            playlistID: playlistID
        )
    }
}

struct PlayableItem: Hashable, Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let streamURL: String
    let mediaType: MediaType
    let playlistID: UUID

    var favoriteKey: String {
        "\(playlistID.uuidString)|\(mediaType.rawValue)|\(id)|\(streamURL)"
    }
}
