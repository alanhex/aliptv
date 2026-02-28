import Foundation

enum SidebarDestination: Hashable {
    case home
    case search
    case favorites
    case recordings
    case settings
    case addPlaylist
    case playlistMedia(playlistID: UUID, mediaType: MediaType)
}

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var selectedDestination: SidebarDestination = .home
    @Published var expandedPlaylists: Set<UUID> = []

    func toggleExpanded(for playlistID: UUID) {
        if expandedPlaylists.contains(playlistID) {
            expandedPlaylists.remove(playlistID)
        } else {
            expandedPlaylists.insert(playlistID)
        }
    }

    func isExpanded(playlistID: UUID) -> Bool {
        expandedPlaylists.contains(playlistID)
    }

    func ensureValidSelection(playlists: [Playlist]) {
        guard case let .playlistMedia(playlistID, _) = selectedDestination else { return }
        if playlists.contains(where: { $0.id == playlistID }) == false {
            selectedDestination = .home
        }
    }
}
