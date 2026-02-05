import Foundation
import SwiftData

@Model
final class FavoriteItem {
    @Attribute(.unique) var id: UUID
    var playlistId: UUID
    var streamId: Int
    var name: String
    var type: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        playlistId: UUID,
        streamId: Int,
        name: String,
        type: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.playlistId = playlistId
        self.streamId = streamId
        self.name = name
        self.type = type
        self.createdAt = createdAt
    }
}
