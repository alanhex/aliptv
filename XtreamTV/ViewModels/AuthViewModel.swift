import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isSaving = false
    @Published var isReloadingPlaylistID: UUID?
    @Published var validationError: String?
    @Published var validationStep: PlaylistValidationStep?

    private let repository: IPTVRepository

    init(repository: IPTVRepository) {
        self.repository = repository
    }

    func savePlaylist(draft: PlaylistDraft, editing playlist: Playlist?) async -> Bool {
        isSaving = true
        validationError = nil
        defer {
            isSaving = false
            validationStep = nil
        }

        do {
            _ = try await repository.savePlaylist(draft, editing: playlist)
            return true
        } catch {
            validationError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            validationStep = repository.currentValidationStep
            return false
        }
    }

    func reload(_ playlist: Playlist) async -> Bool {
        isReloadingPlaylistID = playlist.id
        validationError = nil

        defer {
            isReloadingPlaylistID = nil
            validationStep = nil
        }

        do {
            try await repository.reloadPlaylist(playlist)
            return true
        } catch {
            validationError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            validationStep = repository.currentValidationStep
            return false
        }
    }

    func delete(_ playlist: Playlist) -> Bool {
        do {
            try repository.deletePlaylist(playlist)
            return true
        } catch {
            validationError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }
}
