import Foundation
import SwiftData

@Model
final class Playlist {
    @Attribute(.unique) var id: UUID
    var name: String
    var baseURL: String
    var username: String
    var password: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        baseURL: String,
        username: String,
        password: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.username = username
        self.password = password
        self.createdAt = createdAt
    }
}
