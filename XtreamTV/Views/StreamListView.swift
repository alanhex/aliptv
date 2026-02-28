import SwiftUI

struct StreamListView: View {
    @EnvironmentObject private var repository: IPTVRepository

    let playlist: Playlist
    let mediaType: MediaType
    let onPlay: (PlayableItem) -> Void

    @State private var viewModel: StreamListViewModel?
    @FocusState private var focusedCategoryKey: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if let viewModel {
                if viewModel.isLoading && viewModel.categories.isEmpty && viewModel.streams.isEmpty {
                    ProgressView("Loading \(mediaType.displayName.lowercased())...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    HStack(spacing: 16) {
                        categoryPane(viewModel: viewModel)
                        streamPane(viewModel: viewModel)
                    }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: "\(playlist.id.uuidString)|\(mediaType.rawValue)") {
            let created = StreamListViewModel(repository: repository, playlist: playlist, mediaType: mediaType)
            viewModel = created
            await created.load()
            if let firstKey = created.categories.first?.cacheKey {
                focusedCategoryKey = firstKey
            }
        }
        .onChange(of: viewModel?.selectedCategoryID) { _, newCategoryID in
            guard
                let viewModel,
                let newCategoryID,
                let selected = viewModel.categories.first(where: { $0.categoryID == newCategoryID })
            else { return }
            if let focusedCategoryKey,
               let focused = viewModel.categories.first(where: { $0.cacheKey == focusedCategoryKey }),
               focused.categoryID != newCategoryID {
                return
            }
            focusedCategoryKey = selected.cacheKey
        }
        .onChange(of: focusedCategoryKey) { _, newFocusedKey in
            guard
                let viewModel,
                let newFocusedKey,
                let focusedCategory = viewModel.categories.first(where: { $0.cacheKey == newFocusedKey })
            else { return }
            if viewModel.selectedCategoryID != focusedCategory.categoryID || viewModel.streams.isEmpty {
                viewModel.selectCategory(focusedCategory.categoryID)
            }
        }
    }

    private var header: some View {
        HStack {
            Text("\(playlist.name) · \(mediaType.displayName)")
                .font(.largeTitle.bold())
                .lineLimit(1)

            Spacer()

            if viewModel?.isRefreshing == true {
                ProgressView()
            }

            Button {
                guard let viewModel else { return }
                Task { await viewModel.refresh() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
    }

    private func categoryPane(viewModel: StreamListViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Categories")
                .font(.title3.bold())

            if viewModel.categories.isEmpty {
                ContentUnavailableView("No categories", systemImage: "square.grid.2x2")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.categories, id: \.cacheKey) { category in
                            Button {
                                focusedCategoryKey = category.cacheKey
                                viewModel.selectCategory(category.categoryID)
                            } label: {
                                CategoryCardView(
                                    category: category,
                                    isSelected: viewModel.selectedCategoryID == category.categoryID
                                )
                            }
                            .buttonStyle(.plain)
                            .focused($focusedCategoryKey, equals: category.cacheKey)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .focusSection()
            }
        }
        .frame(width: 330)
    }

    private func streamPane(viewModel: StreamListViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(mediaType.displayName)
                .font(.title3.bold())

            if viewModel.isCategoryLoading {
                ProgressView("Loading category...")
                    .padding(.vertical, 4)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .lineLimit(3)
            }

            if viewModel.streams.isEmpty {
                ContentUnavailableView("No items", systemImage: "tv")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.streams, id: \.cacheKey) { stream in
                    StreamCardView(
                        title: stream.title,
                        subtitle: stream.mediaType.displayName,
                        isFavorite: viewModel.isFavorite(stream),
                        onPlay: { onPlay(stream.asPlayable) },
                        onToggleFavorite: { viewModel.toggleFavorite(stream) }
                    )
                }
                .listStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
