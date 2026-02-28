import Foundation

@MainActor
final class SeriesListViewModel: ObservableObject {
    @Published var categories: [Category] = []
    @Published var seriesList: [Series] = []
    @Published var favoriteKeys: Set<String> = []
    @Published var selectedCategoryID: String?
    @Published var selectedSeries: Series?
    @Published var episodes: [SeriesEpisode] = []
    @Published var fallbackPlayable: PlayableItem?
    @Published var unsupportedReason: String?
    @Published var isLoading = false
    @Published var isCategoryLoading = false
    @Published var isLoadingEpisodes = false
    @Published var errorMessage: String?

    private let repository: IPTVRepository
    private let playlist: Playlist
    private var seriesByCategoryID: [String: [Series]] = [:]
    private var categoryRefreshTask: Task<Void, Never>?
    private var autoRefreshedEmptyCategoryIDs: Set<String> = []

    init(repository: IPTVRepository, playlist: Playlist) {
        self.repository = repository
        self.playlist = playlist
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        loadFromCache()

        do {
            try await repository.refreshMedia(playlist: playlist, mediaType: .series)
            loadFromCache()
            autoRefreshedEmptyCategoryIDs.removeAll()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }

        isLoading = false
    }

    func selectCategory(_ newCategoryID: String?) {
        let isSameSelection = selectedCategoryID == newCategoryID
        let previousCategoryID = selectedCategoryID
        selectedCategoryID = newCategoryID
        loadSeriesForSelectedCategory()
        guard let normalizedCategoryID = newCategoryID, !normalizedCategoryID.isEmpty else {
            if previousCategoryID != newCategoryID,
               let selectedSeries,
               selectedSeries.categoryID != newCategoryID {
                self.selectedSeries = nil
                self.episodes = []
                self.fallbackPlayable = nil
                self.unsupportedReason = nil
            }
            return
        }
        if isSameSelection && !seriesList.isEmpty { return }
        guard seriesList.isEmpty else { return }

        if previousCategoryID != normalizedCategoryID,
           let selectedSeries,
           selectedSeries.categoryID != normalizedCategoryID {
            self.selectedSeries = nil
            self.episodes = []
            self.fallbackPlayable = nil
            self.unsupportedReason = nil
        }

        refreshSelectedCategoryIfNeeded(normalizedCategoryID)
    }

    func selectSeries(_ series: Series) async {
        selectedSeries = series
        await loadEpisodes(for: series, forceRefresh: false)
    }

    func refreshEpisodes() async {
        guard let selectedSeries else { return }
        await loadEpisodes(for: selectedSeries, forceRefresh: true)
    }

    func isFavorite(_ episode: SeriesEpisode) -> Bool {
        favoriteKeys.contains(episode.asPlayable.favoriteKey)
    }

    func toggleFavorite(_ episode: SeriesEpisode) {
        let key = episode.asPlayable.favoriteKey
        do {
            try repository.toggleFavorite(episode.asPlayable)
            if favoriteKeys.contains(key) {
                favoriteKeys.remove(key)
            } else {
                favoriteKeys.insert(key)
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func loadEpisodes(for series: Series, forceRefresh: Bool) async {
        isLoadingEpisodes = true
        unsupportedReason = nil
        fallbackPlayable = nil

        do {
            let result = try await repository.loadEpisodes(playlist: playlist, series: series, forceRefresh: forceRefresh)
            switch result {
            case .episodes(let episodes):
                self.episodes = episodes
            case .fallbackPlayable(let playable, let reason):
                self.episodes = []
                self.fallbackPlayable = playable
                self.unsupportedReason = reason
            case .unsupported(let reason):
                self.episodes = []
                self.unsupportedReason = reason
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }

        isLoadingEpisodes = false
    }

    private func loadFromCache() {
        do {
            isCategoryLoading = false
            categories = try repository.categories(playlistID: playlist.id, mediaType: .series)
            let cachedSeries = try repository.series(playlistID: playlist.id, categoryID: nil)
            rebuildSeriesIndex(with: cachedSeries)

            if selectedCategoryID == nil {
                selectedCategoryID = categories.first?.categoryID
            }
            if let selectedCategoryID, categories.contains(where: { $0.categoryID == selectedCategoryID }) == false {
                self.selectedCategoryID = categories.first?.categoryID
            }
            loadSeriesForSelectedCategory()
            loadFavoriteKeys()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func loadSeriesForSelectedCategory() {
        guard let selectedCategoryID else {
            seriesList = []
            return
        }
        seriesList = seriesByCategoryID[selectedCategoryID] ?? []
    }

    private func refreshSelectedCategoryIfNeeded(_ categoryID: String) {
        guard !autoRefreshedEmptyCategoryIDs.contains(categoryID) else { return }
        autoRefreshedEmptyCategoryIDs.insert(categoryID)

        categoryRefreshTask?.cancel()
        categoryRefreshTask = Task { [weak self] in
            guard let self else { return }
            self.isCategoryLoading = true
            defer { self.isCategoryLoading = false }
            do {
                try await self.repository.refreshMediaCategory(
                    playlist: self.playlist,
                    mediaType: .series,
                    categoryID: categoryID
                )
                guard !Task.isCancelled else { return }
                self.loadFromCache()
            } catch {
                self.errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    private func loadFavoriteKeys() {
        do {
            favoriteKeys = try repository.favoriteKeys(playlistID: playlist.id, mediaType: .series)
        } catch {
            favoriteKeys = []
        }
    }

    private func rebuildSeriesIndex(with cachedSeries: [Series]) {
        var grouped: [String: [Series]] = [:]
        for item in cachedSeries {
            grouped[item.categoryID, default: []].append(item)
        }
        for key in grouped.keys {
            grouped[key]?.sort { lhs, rhs in
                lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
        }
        seriesByCategoryID = grouped
    }
}
