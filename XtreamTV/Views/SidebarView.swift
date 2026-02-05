import SwiftUI

struct SidebarView: View {
    let playlists: [Playlist]
    @Binding var selectedSection: AppSection
    let onAddPlaylist: () -> Void

    @FocusState private var focusedItem: SidebarItem?

    var body: some View {
        let expanded = focusedItem != nil
        VStack(alignment: .leading, spacing: 8) {
            ForEach(mainItems) { item in
                sidebarButton(for: item, expanded: expanded)
            }

            Divider()
                .padding(.vertical, 8)

            ForEach(playlistItems) { item in
                sidebarButton(for: item, expanded: expanded)
            }

            Divider()
                .padding(.vertical, 8)

            ForEach(secondaryItems) { item in
                sidebarButton(for: item, expanded: expanded)
            }

            Spacer()
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 12)
        .frame(width: expanded ? 280 : 90)
        .animation(.easeInOut(duration: 0.2), value: expanded)
        .focusSection()
        .background(Color.black.opacity(0.2))
    }

    private func sidebarButton(for item: SidebarItem, expanded: Bool) -> some View {
        Button {
            if item.section == .addPlaylist {
                onAddPlaylist()
            } else {
                selectedSection = item.section
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item.systemImage)
                    .font(.title3)
                    .frame(width: 32)

                if expanded {
                    Text(item.title)
                        .font(.title3)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedSection == item.section ? Color.white.opacity(0.15) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .focused($focusedItem, equals: item)
    }

    private var mainItems: [SidebarItem] {
        [
            SidebarItem(id: "home", title: "Accueil", systemImage: "house", section: .home),
            SidebarItem(id: "search", title: "Recherche", systemImage: "magnifyingglass", section: .search),
            SidebarItem(id: "favorites", title: "Favoris", systemImage: "heart", section: .favorites)
        ]
    }

    private var playlistItems: [SidebarItem] {
        playlists.flatMap { playlist in
            [
                SidebarItem(id: "live-\(playlist.id.uuidString)", title: "\(playlist.name) - Live", systemImage: "tv", section: .playlistLive(playlist.id)),
                SidebarItem(id: "series-\(playlist.id.uuidString)", title: "\(playlist.name) - Séries", systemImage: "tv.inset.filled", section: .playlistSeries(playlist.id)),
                SidebarItem(id: "films-\(playlist.id.uuidString)", title: "\(playlist.name) - Films", systemImage: "film", section: .playlistFilms(playlist.id))
            ]
        }
    }

    private var secondaryItems: [SidebarItem] {
        [
            SidebarItem(id: "recordings", title: "Enregistrements", systemImage: "dot.radiowaves.left.and.right", section: .recordings),
            SidebarItem(id: "settings", title: "Paramètres", systemImage: "gearshape", section: .settings),
            SidebarItem(id: "add", title: "Ajouter playlist", systemImage: "plus.circle", section: .addPlaylist)
        ]
    }
}

struct SidebarItem: Identifiable, Hashable {
    let id: String
    let title: String
    let systemImage: String
    let section: AppSection
}
