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
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        baseURL: String,
        username: String,
        password: String,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.username = username
        self.password = password
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var credentials: PlaylistCredentials {
        PlaylistCredentials(baseURL: baseURL, username: username, password: password)
    }
}

struct PlaylistDraft: Equatable {
    var name: String = ""
    var baseURL: String = ""
    var username: String = ""
    var password: String = ""

    init() {}

    init(playlist: Playlist) {
        name = playlist.name
        baseURL = playlist.baseURL
        username = playlist.username
        password = playlist.password
    }

    func trimmed() -> PlaylistDraft {
        var copy = self
        copy.name = copy.name.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.baseURL = copy.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.username = copy.username.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.password = copy.password.trimmingCharacters(in: .whitespacesAndNewlines)
        return copy
    }

    func validateFields() throws {
        let cleaned = trimmed()
        guard !cleaned.name.isEmpty else {
            throw XtreamAPIError.validation("Playlist name is required.")
        }
        guard !cleaned.baseURL.isEmpty else {
            throw XtreamAPIError.validation("Base URL is required.")
        }
        guard !cleaned.username.isEmpty else {
            throw XtreamAPIError.validation("Username is required.")
        }
        guard !cleaned.password.isEmpty else {
            throw XtreamAPIError.validation("Password is required.")
        }
        guard let url = URL(string: cleaned.baseURL), let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
            throw XtreamAPIError.validation("Base URL must start with http:// or https://")
        }
    }

    func toCredentials() throws -> PlaylistCredentials {
        try validateFields()
        let cleaned = trimmed()
        let normalizedBaseURL = cleaned.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return PlaylistCredentials(
            baseURL: normalizedBaseURL,
            username: cleaned.username,
            password: cleaned.password
        )
    }
}
