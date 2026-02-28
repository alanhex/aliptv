import SwiftUI

struct HomeView: View {
    let playlists: [Playlist]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("XtreamIPTV")
                    .font(.largeTitle.weight(.semibold))

                Text("Quickly access your IPTV playlists, run a global cache search, or resume from your favorites.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 360), spacing: 18)], spacing: 18) {
                    StatCard(title: "Playlists", value: "\(playlists.count)", systemImage: "list.bullet.rectangle")
                    StatCard(title: "Search", value: "Local cache", systemImage: "magnifyingglass")
                    StatCard(title: "Performance", value: "Cache-first", systemImage: "bolt.fill")
                }

                if playlists.isEmpty {
                    ContentUnavailableView(
                        "No playlists",
                        systemImage: "tray",
                        description: Text("Add a playlist in Settings or from “Add Playlist”.")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 30)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            Text(value)
                .font(.title2.bold())
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
