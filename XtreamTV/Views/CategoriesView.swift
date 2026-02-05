import SwiftUI

struct CategoriesView: View {
    let title: String
    let client: XtreamAPIClient
    let mediaType: MediaType
    let playlist: Playlist

    @StateObject private var viewModel: DashboardViewModel
    @Namespace private var defaultFocus

    init(title: String, client: XtreamAPIClient, mediaType: MediaType, playlist: Playlist) {
        self.title = title
        self.client = client
        self.mediaType = mediaType
        self.playlist = playlist
        _viewModel = StateObject(wrappedValue: DashboardViewModel(client: client))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(title)
                    .font(.title)
                    .bold()

                if viewModel.isLoading {
                    ProgressView()
                } else if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 20)], spacing: 20) {
                        ForEach(viewModel.categories) { category in
                            NavigationLink(value: category) {
                                CategoryCardView(title: category.name)
                            }
                            .buttonStyle(.card)
                            .prefersDefaultFocus(viewModel.categories.first == category, in: defaultFocus)
                        }
                    }
                    .focusSection()
                }
            }
            .padding(60)
        }
        .navigationDestination(for: Category.self) { category in
            switch mediaType {
            case .live:
                StreamListView(category: category, client: client, playlist: playlist, mediaType: .live)
            case .vod:
                StreamListView(category: category, client: client, playlist: playlist, mediaType: .vod)
            case .series:
                SeriesListView(category: category, client: client, playlist: playlist)
            }
        }
        .task {
            await loadCategories()
        }
    }

    private func loadCategories() async {
        switch mediaType {
        case .live:
            await viewModel.loadCategories()
        case .vod:
            await viewModel.loadCategoriesVod()
        case .series:
            await viewModel.loadCategoriesSeries()
        }
    }
}

struct LiveCategoriesView: View {
    let playlist: Playlist

    var body: some View {
        CategoriesView(
            title: "TV en direct - \(playlist.name)",
            client: XtreamAPIClient(baseURL: URL(string: playlist.baseURL) ?? URL(fileURLWithPath: "/"),
                                    username: playlist.username,
                                    password: playlist.password),
            mediaType: .live,
            playlist: playlist
        )
    }
}

struct SeriesCategoriesView: View {
    let playlist: Playlist

    var body: some View {
        CategoriesView(
            title: "Séries - \(playlist.name)",
            client: XtreamAPIClient(baseURL: URL(string: playlist.baseURL) ?? URL(fileURLWithPath: "/"),
                                    username: playlist.username,
                                    password: playlist.password),
            mediaType: .series,
            playlist: playlist
        )
    }
}

struct FilmsCategoriesView: View {
    let playlist: Playlist

    var body: some View {
        CategoriesView(
            title: "Films - \(playlist.name)",
            client: XtreamAPIClient(baseURL: URL(string: playlist.baseURL) ?? URL(fileURLWithPath: "/"),
                                    username: playlist.username,
                                    password: playlist.password),
            mediaType: .vod,
            playlist: playlist
        )
    }
}
