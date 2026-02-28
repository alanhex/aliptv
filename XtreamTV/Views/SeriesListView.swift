import SwiftUI

struct SeriesListView: View {
    @EnvironmentObject private var repository: IPTVRepository

    let playlist: Playlist
    let onPlay: (PlayableItem) -> Void

    @State private var viewModel: SeriesListViewModel?
    @FocusState private var focusedCategoryKey: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("\(playlist.name) · Series")
                .font(.largeTitle.bold())
                .lineLimit(1)

            if let viewModel {
                if viewModel.isLoading && viewModel.seriesList.isEmpty {
                    ProgressView("Loading series...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    HStack(spacing: 16) {
                        categoriesPane(viewModel)
                        seriesPane(viewModel)
                        episodesPane(viewModel)
                    }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: playlist.id) {
            let created = SeriesListViewModel(repository: repository, playlist: playlist)
            viewModel = created
            await created.load()
            focusedCategoryKey = created.categories.first?.cacheKey
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
            if viewModel.selectedCategoryID != focusedCategory.categoryID || viewModel.seriesList.isEmpty {
                viewModel.selectCategory(focusedCategory.categoryID)
            }
        }
    }

    private func categoriesPane(_ viewModel: SeriesListViewModel) -> some View {
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
        .frame(width: 320)
    }

    private func seriesPane(_ viewModel: SeriesListViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Series")
                    .font(.title3.bold())
                Spacer()
                Button {
                    Task { await viewModel.load() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }

            if viewModel.isCategoryLoading {
                ProgressView("Loading category...")
                    .padding(.vertical, 4)
            }

            if viewModel.seriesList.isEmpty {
                ContentUnavailableView("No series", systemImage: "sparkles.tv")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.seriesList, id: \.cacheKey) { series in
                    SeriesCardView(
                        title: series.title,
                        subtitle: series.synopsis,
                        isSelected: viewModel.selectedSeries?.cacheKey == series.cacheKey,
                        onSelect: {
                            Task { await viewModel.selectSeries(series) }
                        }
                    )
                }
                .listStyle(.plain)
            }
        }
        .frame(width: 430)
    }

    private func episodesPane(_ viewModel: SeriesListViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Episodes")
                    .font(.title3.bold())
                Spacer()
                if viewModel.isLoadingEpisodes {
                    ProgressView()
                }
                Button {
                    Task { await viewModel.refreshEpisodes() }
                } label: {
                    Label("Reload", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.selectedSeries == nil)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .lineLimit(3)
            }

            if let reason = viewModel.unsupportedReason {
                VStack(alignment: .leading, spacing: 12) {
                    Text(reason)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let fallbackPlayable = viewModel.fallbackPlayable {
                        Button("Play main stream") {
                            onPlay(fallbackPlayable)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            if viewModel.episodes.isEmpty {
                ContentUnavailableView(
                    viewModel.selectedSeries == nil ? "Select a series" : "No episodes",
                    systemImage: "film.stack"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.episodes, id: \.cacheKey) { episode in
                    StreamCardView(
                        title: episode.title,
                        subtitle: "S\(episode.seasonNumber) E\(episode.episodeNumber)",
                        isFavorite: viewModel.isFavorite(episode),
                        onPlay: { onPlay(episode.asPlayable) },
                        onToggleFavorite: { viewModel.toggleFavorite(episode) }
                    )
                }
                .listStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
