import SwiftUI
import SwiftData

struct StreamListView: View {
    let category: Category
    let client: XtreamAPIClient
    let playlist: Playlist
    let mediaType: MediaType

    @StateObject private var viewModel: StreamListViewModel
    @Namespace private var defaultFocus
    @Environment(\.modelContext) private var modelContext
    @Query private var favorites: [FavoriteItem]

    init(category: Category, client: XtreamAPIClient, playlist: Playlist, mediaType: MediaType) {
        self.category = category
        self.client = client
        self.playlist = playlist
        self.mediaType = mediaType
        _viewModel = StateObject(wrappedValue: StreamListViewModel(client: client, categoryId: category.id, mediaType: mediaType))
    }

    // Grille des chaînes Live TV d'une catégorie
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(category.name)
                    .font(.title)
                    .bold()

                if viewModel.isLoading {
                    ProgressView()
                } else if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 20)], spacing: 20) {
                        ForEach(viewModel.streams) { stream in
                            let streamURL = makeURL(for: stream)
                            NavigationLink {
                                PlayerView(stream: stream, streamURL: streamURL)
                            } label: {
                                StreamCardView(stream: stream)
                            }
                            .buttonStyle(.card)
                            .prefersDefaultFocus(viewModel.streams.first == stream, in: defaultFocus)
                            .contextMenu {
                                Button(isFavorite(stream) ? "Retirer des favoris" : "Ajouter aux favoris") {
                                    toggleFavorite(stream)
                                }
                            }
                        }
                    }
                    .focusSection()
                }
            }
            .padding(60)
        }
        .task {
            await viewModel.loadStreams()
        }
    }

    private func makeURL(for stream: Stream) -> URL {
        switch mediaType {
        case .live:
            return client.makeStreamURL(streamId: stream.id)
        case .vod:
            return client.makeVodURL(streamId: stream.id, container: stream.containerExtension)
        case .series:
            return client.makeStreamURL(streamId: stream.id)
        }
    }

    private func isFavorite(_ stream: Stream) -> Bool {
        favorites.contains(where: { $0.playlistId == playlist.id && $0.streamId == stream.id })
    }

    private func toggleFavorite(_ stream: Stream) {
        if let existing = favorites.first(where: { $0.playlistId == playlist.id && $0.streamId == stream.id }) {
            modelContext.delete(existing)
        } else {
            let type = mediaType.rawValue
            let item = FavoriteItem(playlistId: playlist.id, streamId: stream.id, name: stream.name, type: type)
            modelContext.insert(item)
        }
    }
}
