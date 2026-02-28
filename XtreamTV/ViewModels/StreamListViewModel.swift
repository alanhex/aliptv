import Foundation

@MainActor
final class StreamListViewModel: ObservableObject {
    @Published var categories: [Category] = []
    @Published var streams: [Stream] = []
    @Published var favoriteKeys: Set<String> = []
    @Published var selectedCategoryID: String?
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var isCategoryLoading = false
    @Published var errorMessage: String?

    private let repository: IPTVRepository
    private let playlist: Playlist
    private let mediaType: MediaType
    private var streamsByCategoryID: [String: [Stream]] = [:]
    private var categoryRefreshTask: Task<Void, Never>?
    private var autoRefreshedEmptyCategoryIDs: Set<String> = []

    init(repository: IPTVRepository, playlist: Playlist, mediaType: MediaType) {
        self.repository = repository
        self.playlist = playlist
        self.mediaType = mediaType
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        loadFromCache()

        do {
            if categories.isEmpty {
                try await repository.refreshCategories(playlist: playlist, mediaType: mediaType)
                loadFromCache()
            }

            if let selectedCategoryID {
                isCategoryLoading = true
                defer { isCategoryLoading = false }
                try await repository.refreshMediaCategory(
                    playlist: playlist,
                    mediaType: mediaType,
                    categoryID: selectedCategoryID
                )
                loadFromCache()
                autoRefreshedEmptyCategoryIDs = [selectedCategoryID]
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }

        isLoading = false
    }

    func refresh() async {
        isRefreshing = true
        errorMessage = nil

        do {
            try await repository.refreshMedia(playlist: playlist, mediaType: mediaType)
            loadFromCache()
            autoRefreshedEmptyCategoryIDs.removeAll()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }

        isRefreshing = false
    }

    func selectCategory(_ newCategoryID: String?) {
        let isSameSelection = selectedCategoryID == newCategoryID
        selectedCategoryID = newCategoryID
        loadStreamsForSelectedCategory()
        guard let normalizedCategoryID = newCategoryID, !normalizedCategoryID.isEmpty else { return }
        if isSameSelection && !streams.isEmpty { return }
        guard streams.isEmpty else { return }
        refreshSelectedCategoryIfNeeded(normalizedCategoryID)
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
                    mediaType: self.mediaType,
                    categoryID: categoryID
                )
                guard !Task.isCancelled else { return }
                self.loadFromCache()
            } catch {
                self.errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    func isFavorite(_ stream: Stream) -> Bool {
        favoriteKeys.contains(stream.asPlayable.favoriteKey)
    }

    func toggleFavorite(_ stream: Stream) {
        let key = stream.asPlayable.favoriteKey
        do {
            try repository.toggleFavorite(stream.asPlayable)
            if favoriteKeys.contains(key) {
                favoriteKeys.remove(key)
            } else {
                favoriteKeys.insert(key)
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func loadFromCache() {
        do {
            isCategoryLoading = false
            categories = try repository.categories(playlistID: playlist.id, mediaType: mediaType)
            let cachedStreams = try repository.streams(
                playlistID: playlist.id,
                mediaType: mediaType,
                categoryID: nil
            )
            rebuildStreamIndex(with: cachedStreams)
            if selectedCategoryID == nil {
                selectedCategoryID = categories.first?.categoryID
            }
            if let selectedCategoryID, categories.contains(where: { $0.categoryID == selectedCategoryID }) == false {
                self.selectedCategoryID = categories.first?.categoryID
            }
            loadStreamsForSelectedCategory()
            loadFavoriteKeys()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func loadStreamsForSelectedCategory() {
        guard let selectedCategoryID else {
            streams = []
            return
        }
        streams = streamsByCategoryID[selectedCategoryID] ?? []
    }

    private func loadFavoriteKeys() {
        do {
            favoriteKeys = try repository.favoriteKeys(playlistID: playlist.id, mediaType: mediaType)
        } catch {
            favoriteKeys = []
        }
    }

    private func rebuildStreamIndex(with cachedStreams: [Stream]) {
        var grouped: [String: [Stream]] = [:]
        for stream in cachedStreams {
            grouped[stream.categoryID, default: []].append(stream)
        }
        for key in grouped.keys {
            grouped[key]?.sort { lhs, rhs in
                lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
        }
        streamsByCategoryID = grouped
    }
}
