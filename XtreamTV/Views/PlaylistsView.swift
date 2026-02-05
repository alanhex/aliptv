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

                    Button {
                        showingAdd = true
                    } label: {
                        Text("Ajouter")
                            .font(.callout.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.9)
                    }
                    .frame(minWidth: 140)
                    .buttonStyle(.borderedProminent)
                }

                HStack(spacing: 16) {
                    Text("Tri : \(sortOption.title)")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    Button {
                        sortOption = sortOption.next
                    } label: {
                        Text("Changer")
                            .font(.callout.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.9)
                    }
                    .frame(minWidth: 140)
                    .buttonStyle(.bordered)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 380), spacing: 20)], spacing: 20) {
                    ForEach(sortedPlaylists) { playlist in
                        VStack(alignment: .leading, spacing: 12) {
                            Button {
                                selectedPlaylist = playlist
                            } label: {
                                PlaylistCardView(playlist: playlist)
                            }
                            .buttonStyle(.card)

                            HStack(spacing: 12) {
                                Button("Éditer") {
                                    editingPlaylist = playlist
                                }
                                .frame(minWidth: 140)
                                .buttonStyle(.bordered)

                                Button("Supprimer", role: .destructive) {
                                    delete(playlist)
                                }
                                .frame(minWidth: 250)
                                .buttonStyle(.bordered)

                                Spacer()
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
