import SwiftUI

struct SidebarView: View {
    let playlists: [Playlist]
    @Binding var selectedSection: AppSection
    let onAddPlaylist: () -> Void

    @FocusState private var focusedItem: SidebarFocus?
    @State private var expandedPlaylists: Set<UUID> = []

    var body: some View {
        let expanded = focusedItem != nil
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(mainItems) { item in
                    sidebarButton(for: item, expanded: expanded)
                }

                Divider()
                    .padding(.vertical, 8)

                ForEach(playlists) { playlist in
                    playlistHeader(playlist: playlist, expanded: expanded)

                    if expanded && expandedPlaylists.contains(playlist.id) {
                        sidebarButton(
                            for: SidebarItem(
                                id: "live-\(playlist.id.uuidString)",
                                title: "TV en direct",
                                systemImage: "tv",
                                section: .playlistLive(playlist.id)
                            ),
                            expanded: expanded,
                            indent: 24
                        )
                        sidebarButton(
                            for: SidebarItem(
                                id: "series-\(playlist.id.uuidString)",
                                title: "Séries",
                                systemImage: "tv.inset.filled",
                                section: .playlistSeries(playlist.id)
                            ),
                            expanded: expanded,
                            indent: 24
                        )
                        sidebarButton(
                            for: SidebarItem(
                                id: "films-\(playlist.id.uuidString)",
                                title: "Films",
                                systemImage: "film",
                                section: .playlistFilms(playlist.id)
                            ),
                            expanded: expanded,
                            indent: 24
                        )
                    }
                }

                Divider()
                    .padding(.vertical, 8)

                ForEach(secondaryItems) { item in
                    sidebarButton(for: item, expanded: expanded)
                }

                Spacer(minLength: 12)
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 12)
        }
        .frame(width: expanded ? 380 : 90)
        .animation(.easeInOut(duration: 0.2), value: expanded)
        .focusSection()
        .background(Color.black.opacity(0.2))
    }

    private func sidebarButton(for item: SidebarItem, expanded: Bool, indent: CGFloat = 0) -> some View {
        let isFocused = focusedItem == .item(item)

        return HStack(spacing: 16) {
            Image(systemName: item.systemImage)
                .font(.title3)
                .frame(width: 32)

            if expanded {
                Text(item.title)
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.leading, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal, 30)
        .padding(.leading, indent)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isFocused ? Color.white.opacity(0.18) : Color.clear)
        )
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .focusable(true)
        .focused($focusedItem, equals: .item(item))
        .onTapGesture {
            if item.section == .addPlaylist {
                onAddPlaylist()
            } else {
                selectedSection = item.section
            }
        }
    }

    private func playlistHeader(playlist: Playlist, expanded: Bool) -> some View {
        let isFocused = focusedItem == .playlistHeader(playlist.id)

        return HStack(spacing: 16) {
            Image(systemName: expandedPlaylists.contains(playlist.id) ? "chevron.down" : "chevron.right")
                .font(.callout)
                .frame(width: 20)

            Image(systemName: "rectangle.stack")
                .font(.title3)
                .frame(width: 32)

            if expanded {
                Text(playlist.name)
                    .font(.subheadline)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.leading, 4)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isFocused ? Color.white.opacity(0.12) : Color.clear)
        )
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .focusable(true)
        .focused($focusedItem, equals: .playlistHeader(playlist.id))
        .foregroundStyle(.secondary)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                if expandedPlaylists.contains(playlist.id) {
                    expandedPlaylists.remove(playlist.id)
                } else {
                    expandedPlaylists.insert(playlist.id)
                }
            }
        }
    }

    private var mainItems: [SidebarItem] {
        [
            SidebarItem(id: "home", title: "Accueil", systemImage: "house", section: .home),
            SidebarItem(id: "search", title: "Recherche", systemImage: "magnifyingglass", section: .search),
            SidebarItem(id: "favorites", title: "Favoris", systemImage: "heart", section: .favorites)
        ]
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

private enum SidebarFocus: Hashable {
    case item(SidebarItem)
    case playlistHeader(UUID)
}
