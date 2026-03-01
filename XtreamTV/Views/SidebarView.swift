import SwiftUI

struct SidebarView: View {
    let playlists: [Playlist]
    var compact: Bool = false
    var onRequestExpand: (() -> Void)? = nil
    @Binding var selectedDestination: SidebarDestination
    @Binding var expandedPlaylists: Set<UUID>

    @FocusState private var focusedCompactDestination: SidebarDestination?
    @FocusState private var focusedRow: SidebarFocusTarget?

    private enum SidebarFocusTarget: Hashable {
        case destination(SidebarDestination)
        case playlistHeader(UUID)
    }

    private struct SidebarNoScaleButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .scaleEffect(1.0)
                .opacity(configuration.isPressed ? 0.94 : 1.0)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: compact ? 10 : 14) {
                section {
                    navButton(label: String(localized: "sidebar.home", defaultValue: "Home"), icon: "house", destination: .home)
                    navButton(label: String(localized: "sidebar.search", defaultValue: "Search"), icon: "magnifyingglass", destination: .search)
                    navButton(label: String(localized: "sidebar.favorites", defaultValue: "Favorites"), icon: "star", destination: .favorites)
                }

                if !compact {
                    section {
                        ForEach(playlists, id: \.id) { playlist in
                            playlistGroup(playlist)
                        }
                    }
                }

                section {
                    navButton(label: String(localized: "sidebar.recordings", defaultValue: "Recordings"), icon: "record.circle", destination: .recordings)
                    navButton(label: String(localized: "sidebar.settings", defaultValue: "Settings"), icon: "gearshape", destination: .settings)
                    navButton(label: String(localized: "sidebar.add_playlist", defaultValue: "Add Playlist"), icon: "plus.circle", destination: .addPlaylist)
                }
            }
            .padding(.leading, compact ? 24 : 24)
            .padding(.trailing, compact ? 8 : 12)
            .padding(.top, compact ? 34 : 34)
            .padding(.bottom, compact ? 14 : 14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .contentMargins(0)
        .clipped()
        .focusSection()
        .onAppear {
            syncExpandedForSelection()
        }
        .onChange(of: selectedDestination) { _, _ in
            syncExpandedForSelection()
        }
        .onChange(of: focusedCompactDestination) { _, newValue in
            guard compact, newValue != nil else { return }
            onRequestExpand?()
        }
    }

    private func section<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func navButton(label: String, icon: String, destination: SidebarDestination) -> some View {
        let isFocused = focusedRow == .destination(destination)
        let isSelected = selectedDestination == destination

        return Button {
            selectedDestination = destination
        } label: {
            if compact {
                compactIcon(icon: icon, isFocused: isFocused, isSelected: isSelected)
            } else {
                rowContent(label: label, icon: icon, isFocused: isFocused, isSelected: isSelected)
            }
        }
        .buttonStyle(SidebarNoScaleButtonStyle())
        .focusEffectDisabled()
        .focused($focusedCompactDestination, equals: destination)
        .focused($focusedRow, equals: .destination(destination))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func playlistGroup(_ playlist: Playlist) -> some View {
        let isFocused = focusedRow == .playlistHeader(playlist.id)
        let isSelected = isPlaylistSelected(playlist.id)

        return VStack(alignment: .leading, spacing: 8) {
            Button {
                togglePlaylist(playlist.id)
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "circle.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.pink)
                    Text(playlist.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: expandedPlaylists.contains(playlist.id) ? "chevron.down" : "chevron.right")
                        .font(.caption2.weight(.semibold))
                }
                .padding(.horizontal, 12)
                .frame(height: 48)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(rowForeground(isFocused: isFocused))
                .background(rowBackground(isFocused: isFocused, isSelected: isSelected))
                .overlay {
                    rowBorder(isFocused: isFocused)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(SidebarNoScaleButtonStyle())
            .focusEffectDisabled()
            .focused($focusedRow, equals: .playlistHeader(playlist.id))

            if expandedPlaylists.contains(playlist.id) {
                VStack(alignment: .leading, spacing: 8) {
                    mediaRow(playlist: playlist, mediaType: .live)
                    mediaRow(playlist: playlist, mediaType: .series)
                    mediaRow(playlist: playlist, mediaType: .movie)
                }
                .padding(.leading, 12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func mediaRow(playlist: Playlist, mediaType: MediaType) -> some View {
        let destination = SidebarDestination.playlistMedia(playlistID: playlist.id, mediaType: mediaType)
        let isFocused = focusedRow == .destination(destination)
        let isSelected = selectedDestination == destination

        return Button {
            selectedDestination = destination
        } label: {
            rowContent(label: mediaType.displayName, icon: symbol(for: mediaType), isFocused: isFocused, isSelected: isSelected)
                .frame(height: 44)
        }
        .buttonStyle(SidebarNoScaleButtonStyle())
        .focusEffectDisabled()
        .focused($focusedRow, equals: .destination(destination))
    }

    private func compactIcon(icon: String, isFocused: Bool, isSelected: Bool) -> some View {
        Image(systemName: icon)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isFocused ? Color.black.opacity(0.78) : Color.white.opacity(0.9))
            .frame(width: 34, height: 34)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isFocused ? Color.white.opacity(0.88) : (isSelected ? Color.white.opacity(0.18) : Color.white.opacity(0.08)))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(isFocused ? 0.2 : 0.08), lineWidth: isFocused ? 0.7 : 0.5)
            }
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func rowContent(label: String, icon: String, isFocused: Bool, isSelected: Bool) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .frame(width: 16)
            Text(label)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(height: 48)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(rowForeground(isFocused: isFocused))
        .background(rowBackground(isFocused: isFocused, isSelected: isSelected))
        .overlay {
            rowBorder(isFocused: isFocused)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func rowForeground(isFocused: Bool) -> Color {
        isFocused ? Color.black.opacity(0.78) : Color.white.opacity(0.9)
    }

    private func rowBackground(isFocused: Bool, isSelected: Bool) -> Color {
        if isFocused {
            return Color.white.opacity(0.78)
        }
        return isSelected ? Color.white.opacity(0.14) : Color.white.opacity(0.08)
    }

    @ViewBuilder
    private func rowBorder(isFocused: Bool) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(Color.white.opacity(isFocused ? 0.14 : 0.08), lineWidth: isFocused ? 0.6 : 0.5)
    }

    private func isPlaylistSelected(_ playlistID: UUID) -> Bool {
        guard case let .playlistMedia(currentID, _) = selectedDestination else { return false }
        return currentID == playlistID
    }

    private func symbol(for mediaType: MediaType) -> String {
        switch mediaType {
        case .live: return "dot.radiowaves.left.and.right"
        case .movie: return "film"
        case .series: return "tv"
        }
    }

    private func togglePlaylist(_ playlistID: UUID) {
        if expandedPlaylists.contains(playlistID) {
            expandedPlaylists.remove(playlistID)
        } else {
            expandedPlaylists.insert(playlistID)
        }
    }

    private func syncExpandedForSelection() {
        guard case let .playlistMedia(playlistID, _) = selectedDestination else { return }
        expandedPlaylists.insert(playlistID)
    }
}
