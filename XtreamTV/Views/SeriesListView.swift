import SwiftUI

struct SeriesListView: View {
    let category: Category
    let client: XtreamAPIClient
    let playlist: Playlist

    @StateObject private var viewModel: SeriesListViewModel
    @Namespace private var defaultFocus

    init(category: Category, client: XtreamAPIClient, playlist: Playlist) {
        self.category = category
        self.client = client
        self.playlist = playlist
        _viewModel = StateObject(wrappedValue: SeriesListViewModel(client: client, categoryId: category.id))
    }

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
                        ForEach(viewModel.series) { item in
                            SeriesCardView(item: item)
                                .buttonStyle(.card)
                                .prefersDefaultFocus(viewModel.series.first == item, in: defaultFocus)
                        }
                    }
                    .focusSection()
                }
            }
            .padding(60)
        }
        .task {
            await viewModel.loadSeries()
        }
    }
}
