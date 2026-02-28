import SwiftUI

struct SidebarView: View {
    let playlists: [Playlist]
    @Binding var selectedDestination: SidebarDestination
    @Binding var expandedPlaylists: Set<UUID>

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                section(title: String(localized: "sidebar.section.navigation", defaultValue: "Navigation")) {
                    navButton(
                        label: String(localized: "sidebar.home", defaultValue: "Home"),
                        icon: "house",
                        destination: .home
                    )
                    navButton(
                        label: String(localized: "sidebar.search", defaultValue: "Search"),
                        icon: "magnifyingglass",
                        destination: .search
                    )
                    navButton(
                        label: String(localized: "sidebar.favorites", defaultValue: "Favorites"),
                        icon: "star",
                        destination: .favorites
                    )
                }

                section(title: String(localized: "sidebar.section.playlists", defaultValue: "Playlists")) {
                    ForEach(playlists, id: \.id) { playlist in
                        playlistGroup(playlist)
                    }
                }

                section(title: String(localized: "sidebar.section.system", defaultValue: "System")) {
                    navButton(
                        label: String(localized: "sidebar.recordings", defaultValue: "Recordings"),
                        icon: "record.circle",
                        destination: .recordings
                    )
                    navButton(
                        label: String(localized: "sidebar.settings", defaultValue: "Settings"),
                        icon: "gearshape",
                        destination: .settings
                    )
                    navButton(
                        label: String(localized: "sidebar.add_playlist", defaultValue: "Add Playlist"),
                        icon: "plus.circle",
                        destination: .addPlaylist
                    )
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 10)
        }
        .scrollIndicators(.hidden)
        .focusSection()
        .onAppear {
            syncExpandedForSelection()
        }
        .onChange(of: selectedDestination) { _, _ in
            syncExpandedForSelection()
        }
    }

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.leading, 8)
            content()
        }
    }

    private func navButton(label: String, icon: String, destination: SidebarDestination) -> some View {
        return Button {
            selectedDestination = destination
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .frame(width: 20)
                Text(label)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(background(isSelected: isSelected(destination)))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
    }

    private func playlistGroup(_ playlist: Playlist) -> some View {
        return VStack(alignment: .leading, spacing: 6) {
            Button {
                togglePlaylist(playlist.id)
            } label: {
                HStack {
                    Image(systemName: expandedPlaylists.contains(playlist.id) ? "chevron.down" : "chevron.right")
                        .font(.caption.bold())
                    Text(playlist.name)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.05))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .focusEffectDisabled()

            if expandedPlaylists.contains(playlist.id) {
                VStack(alignment: .leading, spacing: 4) {
                    mediaRow(playlist: playlist, mediaType: .live)
                    mediaRow(playlist: playlist, mediaType: .movie)
                    mediaRow(playlist: playlist, mediaType: .series)
                }
                .padding(.leading, 18)
            }
        }
    }

    private func mediaRow(playlist: Playlist, mediaType: MediaType) -> some View {
        let destination = SidebarDestination.playlistMedia(playlistID: playlist.id, mediaType: mediaType)

        return Button {
            selectedDestination = destination
        } label: {
            HStack(spacing: 10) {
                Image(systemName: symbol(for: mediaType))
                    .frame(width: 20)
                Text(mediaType.displayName)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(background(isSelected: isSelected(destination)))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
    }

    private func symbol(for mediaType: MediaType) -> String {
        switch mediaType {
        case .live: return "dot.radiowaves.left.and.right"
        case .movie: return "film"
        case .series: return "sparkles.tv"
        }
    }

    private func togglePlaylist(_ playlistID: UUID) {
        if expandedPlaylists.contains(playlistID) {
            expandedPlaylists.remove(playlistID)
        } else {
            expandedPlaylists.insert(playlistID)
        }
    }

    private func isSelected(_ destination: SidebarDestination) -> Bool {
        selectedDestination == destination
    }

    private func syncExpandedForSelection() {
        guard case let .playlistMedia(playlistID, _) = selectedDestination else { return }
        expandedPlaylists.insert(playlistID)
    }

    private func background(isSelected: Bool) -> Color {
        if isSelected {
            return Color.accentColor.opacity(0.22)
        }
        return Color.white.opacity(0.02)
    }
}
