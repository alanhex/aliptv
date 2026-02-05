import SwiftUI
import SwiftData

enum AppSection: Hashable {
    case home
    case search
    case favorites
    case playlistLive(UUID)
    case playlistSeries(UUID)
    case playlistFilms(UUID)
    case recordings
    case settings
    case addPlaylist
}

struct AppShellView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var playlists: [Playlist]

    @State private var selectedSection: AppSection = .home
    @State private var showingAddPlaylist = false

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(
                playlists: playlists,
                selectedSection: $selectedSection,
                onAddPlaylist: {
                    showingAddPlaylist = true
                }
            )

            Divider()
                .frame(width: 1)
                .opacity(0.3)

            contentView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(isPresented: $showingAddPlaylist) {
            PlaylistFormView()
        }
        .onAppear {
            if case .home = selectedSection, let first = playlists.first {
                selectedSection = .playlistLive(first.id)
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch selectedSection {
        case .home:
            HomeView()
        case .search:
            SearchView()
        case .favorites:
            FavoritesView(playlists: playlists)
        case .playlistLive(let id):
            if let playlist = playlists.first(where: { $0.id == id }) {
                LiveCategoriesView(playlist: playlist)
            } else {
                EmptyStateView(message: "Liste introuvable.")
            }
        case .playlistSeries(let id):
            if let playlist = playlists.first(where: { $0.id == id }) {
                SeriesCategoriesView(playlist: playlist)
            } else {
                EmptyStateView(message: "Liste introuvable.")
            }
        case .playlistFilms(let id):
            if let playlist = playlists.first(where: { $0.id == id }) {
                FilmsCategoriesView(playlist: playlist)
            } else {
                EmptyStateView(message: "Liste introuvable.")
            }
        case .recordings:
            RecordingsView()
        case .settings:
            SettingsView()
        case .addPlaylist:
            EmptyStateView(message: "Ajoutez une playlist depuis le menu.")
        }
    }
}

struct EmptyStateView: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Text(message)
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
