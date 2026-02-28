import SwiftUI
import SwiftData

struct AppShellView: View {
    @EnvironmentObject private var repository: IPTVRepository
    @Query(sort: [SortDescriptor(\Playlist.name, order: .forward)]) private var playlists: [Playlist]

    @StateObject private var dashboardViewModel = DashboardViewModel()
    @StateObject private var playerViewModel = PlayerViewModel()
    @State private var selectedPlayable: PlayableItem?

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(
                playlists: playlists,
                selectedDestination: $dashboardViewModel.selectedDestination,
                expandedPlaylists: $dashboardViewModel.expandedPlaylists
            )
            .frame(width: 400)
            .frame(maxHeight: .infinity)
            .background(Color.white.opacity(0.04))
            .overlay(alignment: .trailing) {
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 1)
            }

            detailContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, 28)
                .padding(.vertical, 22)
        }
        .background(
            LinearGradient(
                colors: [
                    Color(.sRGB, red: 0.07, green: 0.08, blue: 0.1, opacity: 1),
                    Color(.sRGB, red: 0.03, green: 0.03, blue: 0.04, opacity: 1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .fullScreenCover(item: $selectedPlayable) { playable in
            PlayerView(playable: playable, viewModel: playerViewModel)
        }
        .onChange(of: playlists) { _, newValue in
            dashboardViewModel.ensureValidSelection(playlists: newValue)
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        switch dashboardViewModel.selectedDestination {
        case .home:
            HomeView(playlists: playlists)
        case .search:
            SearchView(onPlay: { selectedPlayable = $0 }, onOpenSeries: openSeries)
        case .favorites:
            FavoritesView(onPlay: { selectedPlayable = $0 })
        case .recordings:
            RecordingsView()
        case .settings:
            SettingsView()
        case .addPlaylist:
            PlaylistFormView(editingPlaylist: nil)
        case .playlistMedia(let playlistID, let mediaType):
            if let playlist = playlists.first(where: { $0.id == playlistID }) {
                if mediaType == .series {
                    SeriesListView(playlist: playlist, onPlay: { selectedPlayable = $0 })
                } else {
                    StreamListView(playlist: playlist, mediaType: mediaType, onPlay: { selectedPlayable = $0 })
                }
            } else {
                ContentUnavailableView("Playlist not found", systemImage: "exclamationmark.triangle")
            }
        }
    }

    private func openSeries(playlistID: UUID, seriesID: String) {
        dashboardViewModel.selectedDestination = .playlistMedia(playlistID: playlistID, mediaType: .series)
    }
}
