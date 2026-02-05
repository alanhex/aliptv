import SwiftUI
import SwiftData

struct FavoritesView: View {
    @Query private var favorites: [FavoriteItem]
    let playlists: [Playlist]

    init(playlists: [Playlist]) {
        self.playlists = playlists
        _favorites = Query(sort: \FavoriteItem.createdAt, order: .reverse)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Favoris")
                    .font(.largeTitle)
                    .bold()

                if favorites.isEmpty {
                    Text("Aucun favori pour le moment.")
                        .foregroundStyle(.secondary)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 20)], spacing: 20) {
                        ForEach(favorites) { item in
                            if let playlist = playlist(for: item.playlistId),
                               let client = makeClient(for: playlist),
                               let url = makeURL(for: item, client: client) {
                                NavigationLink {
                                    let stream = Stream(
                                        id: item.streamId,
                                        name: item.name,
                                        streamIcon: nil,
                                        streamType: item.type,
                                        categoryId: nil,
                                        containerExtension: nil
                                    )
                                    PlayerView(stream: stream, streamURL: url)
                                } label: {
                                    FavoriteCardView(item: item, playlistName: playlist.name)
                                }
                                .buttonStyle(.card)
                            } else {
                                FavoriteCardView(item: item, playlistName: playlistName(for: item.playlistId))
                                    .opacity(0.6)
                            }
                        }
                    }
                    .focusSection()
                }
            }
            .padding(60)
        }
    }

    private func playlistName(for id: UUID) -> String {
        playlists.first(where: { $0.id == id })?.name ?? "Liste"
    }

    private func playlist(for id: UUID) -> Playlist? {
        playlists.first(where: { $0.id == id })
    }

    private func makeClient(for playlist: Playlist) -> XtreamAPIClient? {
        guard let url = URL(string: playlist.baseURL) else { return nil }
        return XtreamAPIClient(baseURL: url, username: playlist.username, password: playlist.password)
    }

    private func makeURL(for item: FavoriteItem, client: XtreamAPIClient) -> URL? {
        switch item.type {
        case MediaType.live.rawValue:
            return client.makeStreamURL(streamId: item.streamId)
        case MediaType.vod.rawValue:
            return client.makeVodURL(streamId: item.streamId, container: nil)
        default:
            return nil
        }
    }
}

private struct FavoriteCardView: View {
    let item: FavoriteItem
    let playlistName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(item.name)
                .font(.headline)
                .lineLimit(2)

            Text(playlistName)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text(item.type.uppercased())
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.blue.opacity(0.15))
        )
        .frame(height: 160)
    }
}
