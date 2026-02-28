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
    var updatedAt: Date

    init(
        playlistID: UUID,
        mediaType: MediaType,
        streamID: String,
        categoryID: String,
        title: String,
        streamURL: String,
        logoURL: String? = nil,
        updatedAt: Date = .now
    ) {
        self.playlistID = playlistID
        self.mediaTypeRaw = mediaType.rawValue
        self.streamID = streamID
        self.categoryID = categoryID
        self.title = title
        self.streamURL = streamURL
        self.logoURL = logoURL
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
