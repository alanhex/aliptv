import Foundation
import SwiftData

@Model
final class FavoriteItem {
    @Attribute(.unique) var favoriteKey: String
    var playlistID: UUID
    var mediaTypeRaw: String
    var itemID: String
    var title: String
    var streamURL: String
    var createdAt: Date

    init(
        playlistID: UUID,
        mediaType: MediaType,
        itemID: String,
        title: String,
        streamURL: String,
        createdAt: Date = .now
    ) {
        self.playlistID = playlistID
        self.mediaTypeRaw = mediaType.rawValue
        self.itemID = itemID
        self.title = title
        self.streamURL = streamURL
        self.createdAt = createdAt
        self.favoriteKey = "\(playlistID.uuidString)|\(mediaType.rawValue)|\(itemID)|\(streamURL)"
    }

    var mediaType: MediaType {
        MediaType(rawValue: mediaTypeRaw) ?? .live
    }

    var asPlayable: PlayableItem {
        PlayableItem(
            id: itemID,
            title: title,
            subtitle: "Favorite · \(mediaType.displayName)",
            streamURL: streamURL,
            mediaType: mediaType,
            playlistID: playlistID
        )
    }
}
