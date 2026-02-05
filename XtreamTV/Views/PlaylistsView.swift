import SwiftUI
import SwiftData

struct PlaylistsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var playlists: [Playlist]

    @Binding var selectedPlaylist: Playlist?

    @State private var showingAdd = false
    @State private var editingPlaylist: Playlist?
    @State private var sortOption: SortOption = .name

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Text("Mes listes")
                        .font(.largeTitle)
                        .bold()

                    Spacer()

                    Button("Ajouter") {
                        showingAdd = true
                    }
                    .buttonStyle(.borderedProminent)
                }

                HStack(spacing: 16) {
                    Text("Tri : \(sortOption.title)")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    Button("Changer") {
                        sortOption = sortOption.next
                    }
                    .buttonStyle(.bordered)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 20)], spacing: 20) {
                    ForEach(sortedPlaylists) { playlist in
                        Button {
                            selectedPlaylist = playlist
                        } label: {
                            PlaylistCardView(playlist: playlist)
                        }
                        .buttonStyle(.card)
                        .contextMenu {
                            Button("Éditer") {
                                editingPlaylist = playlist
                            }
                            Button("Supprimer", role: .destructive) {
                                delete(playlist)
                            }
                        }
                    }
                }
                .focusSection()
            }
            .padding(60)
        }
        .sheet(isPresented: $showingAdd) {
            PlaylistFormView()
        }
        .sheet(item: $editingPlaylist) { playlist in
            PlaylistFormView(playlist: playlist)
        }
    }

    private var sortedPlaylists: [Playlist] {
        switch sortOption {
        case .name:
            return playlists.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .recent:
            return playlists.sorted { $0.createdAt > $1.createdAt }
        }
    }

    private func delete(_ playlist: Playlist) {
        modelContext.delete(playlist)
        if selectedPlaylist?.id == playlist.id {
            selectedPlaylist = nil
        }
    }
}

private enum SortOption {
    case name
    case recent

    var title: String {
        switch self {
        case .name: return "Nom"
        case .recent: return "Récent"
        }
    }

    var next: SortOption {
        switch self {
        case .name: return .recent
        case .recent: return .name
        }
    }
}
