import SwiftUI

struct DashboardView: View {
    let playlist: Playlist
    let onBack: () -> Void

    // Affiche les catégories Live TV
    var body: some View {
        if let url = URL(string: playlist.baseURL) {
            let client = XtreamAPIClient(
                baseURL: url,
                username: playlist.username,
                password: playlist.password
            )
            DashboardContentView(client: client, onBack: onBack, title: playlist.name, playlist: playlist)
        } else {
            VStack(spacing: 16) {
                Text("URL invalide pour la liste")
                    .font(.title2)
                    .bold()
                Text(playlist.baseURL)
                    .foregroundStyle(.secondary)
                Button("Retour aux listes") {
                    onBack()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(60)
        }
    }
}

private struct DashboardContentView: View {
    let client: XtreamAPIClient
    let onBack: () -> Void
    let title: String
    let playlist: Playlist

    @StateObject private var viewModel: DashboardViewModel
    @Namespace private var defaultFocus

    init(client: XtreamAPIClient, onBack: @escaping () -> Void, title: String, playlist: Playlist) {
        self.client = client
        self.onBack = onBack
        self.title = title
        self.playlist = playlist
        _viewModel = StateObject(wrappedValue: DashboardViewModel(client: client))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Catégories Live TV - \(title)")
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
            StreamListView(category: category, client: client, playlist: playlist, mediaType: .live)
        }
        .task {
            await viewModel.loadCategories()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    onBack()
                } label: {
                    Label("Listes", systemImage: "list.bullet")
                }
            }
        }
    }
}
