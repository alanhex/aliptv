import SwiftUI
import SwiftData

@main
struct XtreamTVApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [Playlist.self, FavoriteItem.self])
    }
}

struct RootView: View {
    var body: some View {
        NavigationStack {
            RootContentView()
        }
    }
}

private struct RootContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var playlists: [Playlist]

    var body: some View {
        if playlists.isEmpty {
            OnboardingView { _ in }
        } else {
            AppShellView()
        }
    }
}
