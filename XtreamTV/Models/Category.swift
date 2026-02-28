import Foundation
import SwiftData

@Model
final class Category {
    @Attribute(.unique) var cacheKey: String
    var playlistID: UUID
    var mediaTypeRaw: String
    var categoryID: String
    var name: String
    var orderIndex: Int
    var updatedAt: Date

    init(
        playlistID: UUID,
        mediaType: MediaType,
        categoryID: String,
        name: String,
        orderIndex: Int,
        updatedAt: Date = .now
    ) {
        self.playlistID = playlistID
        self.mediaTypeRaw = mediaType.rawValue
        self.categoryID = categoryID
        self.name = name
        self.orderIndex = orderIndex
        self.updatedAt = updatedAt
        self.cacheKey = "\(playlistID.uuidString)|\(mediaType.rawValue)|\(categoryID)"
    }

    var mediaType: MediaType {
        MediaType(rawValue: mediaTypeRaw) ?? .live
    }
}
