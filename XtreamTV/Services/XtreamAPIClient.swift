import Foundation
import SwiftData

protocol XtreamAPIClientProtocol {
    func authenticate(credentials: PlaylistCredentials) async throws -> XtreamAuthentication
    func fetchCategories(credentials: PlaylistCredentials, mediaType: MediaType) async throws -> [XtreamCategoryDTO]
    func fetchStreams(credentials: PlaylistCredentials, mediaType: MediaType, categoryID: String?) async throws -> [XtreamStreamDTO]
    func fetchSeries(credentials: PlaylistCredentials, categoryID: String?) async throws -> [XtreamSeriesDTO]
    func fetchSeriesInfo(
        credentials: PlaylistCredentials,
        seriesID: String,
        defaultContainerExtension: String
    ) async throws -> (episodes: [XtreamEpisodeDTO], unsupportedReason: String?)
}

final class XtreamAPIClient: XtreamAPIClientProtocol {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let timeout: TimeInterval

    init(timeout: TimeInterval = 20) {
        self.timeout = timeout
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        session = URLSession(configuration: configuration)
        decoder = JSONDecoder()
    }

    func authenticate(credentials: PlaylistCredentials) async throws -> XtreamAuthentication {
        let data = try await performRequest(credentials: credentials, action: nil)
        let auth: XtreamAuthentication
        do {
            auth = try decoder.decode(XtreamAuthentication.self, from: data)
        } catch {
            throw XtreamAPIError.decoding("Unable to decode authentication response.")
        }

        guard auth.isAuthenticated else {
            throw XtreamAPIError.unauthorized
        }

        return auth
    }

    func fetchCategories(credentials: PlaylistCredentials, mediaType: MediaType) async throws -> [XtreamCategoryDTO] {
        let data = try await performRequest(credentials: credentials, action: mediaType.xtreamActionCategories)
        do {
            return try decoder.decode([XtreamCategoryDTO].self, from: data)
        } catch {
            throw XtreamAPIError.decoding("Unable to decode \(mediaType.displayName.lowercased()) categories.")
        }
    }

    func fetchStreams(
        credentials: PlaylistCredentials,
        mediaType: MediaType,
        categoryID: String? = nil
    ) async throws -> [XtreamStreamDTO] {
        var extra: [URLQueryItem] = []
        if let categoryID, !categoryID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            extra.append(URLQueryItem(name: "category_id", value: categoryID))
        }
        let data = try await performRequest(
            credentials: credentials,
            action: mediaType.xtreamActionStreams,
            extraQueryItems: extra
        )
        do {
            return try decoder.decode([XtreamStreamDTO].self, from: data)
        } catch {
            throw XtreamAPIError.decoding("Unable to decode \(mediaType.displayName.lowercased()) streams.")
        }
    }

    func fetchSeries(credentials: PlaylistCredentials, categoryID: String? = nil) async throws -> [XtreamSeriesDTO] {
        var extra: [URLQueryItem] = []
        if let categoryID, !categoryID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            extra.append(URLQueryItem(name: "category_id", value: categoryID))
        }
        let data = try await performRequest(
            credentials: credentials,
            action: MediaType.series.xtreamActionStreams,
            extraQueryItems: extra
        )
        do {
            return try decoder.decode([XtreamSeriesDTO].self, from: data)
        } catch {
            throw XtreamAPIError.decoding("Unable to decode series list.")
        }
    }

    func fetchSeriesInfo(
        credentials: PlaylistCredentials,
        seriesID: String,
        defaultContainerExtension: String
    ) async throws -> (episodes: [XtreamEpisodeDTO], unsupportedReason: String?) {
        let data = try await performRequest(
            credentials: credentials,
            action: "get_series_info",
            extraQueryItems: [URLQueryItem(name: "series_id", value: seriesID)]
        )

        let jsonObject: Any
        do {
            jsonObject = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw XtreamAPIError.decoding("Invalid series details payload.")
        }

        guard let root = jsonObject as? [String: Any] else {
            throw XtreamAPIError.decoding("Unsupported series details structure.")
        }

        let episodes = parseEpisodes(
            root["episodes"],
            seasonHint: nil,
            credentials: credentials,
            fallbackSeriesID: seriesID,
            defaultContainerExtension: defaultContainerExtension
        )

        let infoMessage = (root["info"] as? [String: Any])?["message"] as? String
        let message = (root["message"] as? String) ?? infoMessage
        return (episodes, episodes.isEmpty ? message : nil)
    }

    private func performRequest(
        credentials: PlaylistCredentials,
        action: String?,
        extraQueryItems: [URLQueryItem] = []
    ) async throws -> Data {
        guard var components = URLComponents(string: "\(credentials.normalizedBaseURL)/player_api.php") else {
            throw XtreamAPIError.invalidURL
        }

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "username", value: credentials.username),
            URLQueryItem(name: "password", value: credentials.password)
        ]
        if let action {
            queryItems.append(URLQueryItem(name: "action", value: action))
        }
        queryItems.append(contentsOf: extraQueryItems)
        components.queryItems = queryItems

        guard let url = components.url else {
            throw XtreamAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw XtreamAPIError.network("Missing HTTP response.")
            }
            guard 200 ..< 300 ~= httpResponse.statusCode else {
                if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                    throw XtreamAPIError.unauthorized
                }
                throw XtreamAPIError.server("HTTP status \(httpResponse.statusCode)")
            }
            guard !data.isEmpty else {
                throw XtreamAPIError.emptyResponse
            }
            return data
        } catch let urlError as URLError {
            if urlError.code == .timedOut {
                throw XtreamAPIError.timeout
            }
            throw XtreamAPIError.network(urlError.localizedDescription)
        } catch let apiError as XtreamAPIError {
            throw apiError
        } catch {
            throw XtreamAPIError.network(error.localizedDescription)
        }
    }

    private func parseEpisodes(
        _ node: Any?,
        seasonHint: Int?,
        credentials: PlaylistCredentials,
        fallbackSeriesID: String,
        defaultContainerExtension: String
    ) -> [XtreamEpisodeDTO] {
        guard let node else { return [] }

        if let dictionary = node as? [String: Any], looksLikeEpisode(dictionary) {
            return [
                buildEpisode(
                    from: dictionary,
                    seasonHint: seasonHint,
                    credentials: credentials,
                    fallbackSeriesID: fallbackSeriesID,
                    defaultContainerExtension: defaultContainerExtension
                )
            ]
        }

        if let dictionary = node as? [String: Any] {
            var output: [XtreamEpisodeDTO] = []
            for (key, value) in dictionary {
                let seasonalKey = Int(key) ?? seasonHint
                output.append(
                    contentsOf: parseEpisodes(
                        value,
                        seasonHint: seasonalKey,
                        credentials: credentials,
                        fallbackSeriesID: fallbackSeriesID,
                        defaultContainerExtension: defaultContainerExtension
                    )
                )
            }
            return output
        }

        if let array = node as? [Any] {
            return array.flatMap {
                parseEpisodes(
                    $0,
                    seasonHint: seasonHint,
                    credentials: credentials,
                    fallbackSeriesID: fallbackSeriesID,
                    defaultContainerExtension: defaultContainerExtension
                )
            }
        }

        return []
    }

    private func looksLikeEpisode(_ dictionary: [String: Any]) -> Bool {
        dictionary["id"] != nil || dictionary["episode_num"] != nil || dictionary["title"] != nil || dictionary["stream_id"] != nil
    }

    private func buildEpisode(
        from dictionary: [String: Any],
        seasonHint: Int?,
        credentials: PlaylistCredentials,
        fallbackSeriesID: String,
        defaultContainerExtension: String
    ) -> XtreamEpisodeDTO {
        let info = dictionary["info"] as? [String: Any]

        let rawID = flexibleString(dictionary["id"])
            ?? flexibleString(dictionary["episode_id"])
            ?? flexibleString(dictionary["stream_id"])
            ?? fallbackSeriesID

        let season = flexibleInt(dictionary["season"]) ?? seasonHint ?? 0
        let episodeNumber = flexibleInt(dictionary["episode_num"]) ?? flexibleInt(dictionary["episode"]) ?? 0
        let title = flexibleString(dictionary["title"]) ?? flexibleString(dictionary["name"]) ?? "S\(season) E\(episodeNumber)"

        let extensionValue = flexibleString(dictionary["container_extension"]) ?? defaultContainerExtension
        let directSource = flexibleString(dictionary["direct_source"]) ?? flexibleString(info?["direct_source"])
        let streamURL = buildXtreamPlaybackURL(
            credentials: credentials,
            mediaType: .series,
            streamID: rawID,
            containerExtension: extensionValue,
            directSource: directSource
        )

        let overview = flexibleString(dictionary["plot"]) ?? flexibleString(info?["plot"])

        return XtreamEpisodeDTO(
            id: rawID,
            title: title,
            season: season,
            episodeNumber: episodeNumber,
            streamURL: streamURL,
            overview: overview
        )
    }

    private func flexibleString(_ value: Any?) -> String? {
        guard let value else { return nil }
        if let value = value as? String { return value }
        if let value = value as? Int { return String(value) }
        if let value = value as? Double { return String(value) }
        if let value = value as? NSNumber { return value.stringValue }
        return nil
    }

    private func flexibleInt(_ value: Any?) -> Int? {
        guard let value else { return nil }
        if let value = value as? Int { return value }
        if let value = value as? Double { return Int(value) }
        if let value = value as? String { return Int(value) }
        if let value = value as? NSNumber { return value.intValue }
        return nil
    }
}

func buildXtreamPlaybackURL(
    credentials: PlaylistCredentials,
    mediaType: MediaType,
    streamID: String,
    containerExtension: String?,
    directSource: String?
) -> String {
    let fallbackScheme = URL(string: credentials.normalizedBaseURL)?.scheme

    if let directSource, !directSource.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return normalizedPlaybackURLString(directSource, fallbackScheme: fallbackScheme)
    }

    let cleanedBase = credentials.normalizedBaseURL
    let cleanedID = streamID.trimmingCharacters(in: .whitespacesAndNewlines)
    let normalizedExtension = normalizedContainerExtension(containerExtension)
    let ext: String

    switch mediaType {
    case .live:
        ext = normalizedExtension ?? "m3u8"
        return normalizedPlaybackURLString(
            "\(cleanedBase)/live/\(credentials.username)/\(credentials.password)/\(cleanedID).\(ext)",
            fallbackScheme: fallbackScheme
        )
    case .movie:
        ext = normalizedExtension ?? "m3u8"
        return normalizedPlaybackURLString(
            "\(cleanedBase)/movie/\(credentials.username)/\(credentials.password)/\(cleanedID).\(ext)",
            fallbackScheme: fallbackScheme
        )
    case .series:
        ext = normalizedExtension ?? "m3u8"
        return normalizedPlaybackURLString(
            "\(cleanedBase)/series/\(credentials.username)/\(credentials.password)/\(cleanedID).\(ext)",
            fallbackScheme: fallbackScheme
        )
    }
}

private func normalizedContainerExtension(_ value: String?) -> String? {
    guard let value else { return nil }
    var cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    while cleaned.hasPrefix(".") {
        cleaned.removeFirst()
    }
    guard !cleaned.isEmpty else { return nil }
    guard cleaned != "null", cleaned != "nil", cleaned != "none", cleaned != "undefined", cleaned != "0" else {
        return nil
    }
    return cleaned
}

private func normalizedPlaybackURLString(_ rawURL: String, fallbackScheme: String?) -> String {
    var value = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty else { return rawURL }

    if value.hasPrefix("//"), let fallbackScheme {
        value = "\(fallbackScheme):\(value)"
    }

    if let encoded = value.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed),
       let parsed = URL(string: encoded) {
        return parsed.absoluteString
    }

    if let parsed = URL(string: value) {
        return parsed.absoluteString
    }

    return value
}

struct SearchResultItem: Identifiable, Hashable {
    enum Kind: Hashable {
        case playable(PlayableItem)
        case series(playlistID: UUID, seriesID: String)
    }

    let id: String
    let title: String
    let subtitle: String
    let kind: Kind
}

enum EpisodeLoadResult {
    case episodes([SeriesEpisode])
    case fallbackPlayable(PlayableItem, reason: String)
    case unsupported(reason: String)
}

@MainActor
final class IPTVRepository: ObservableObject {
    @Published var currentValidationStep: PlaylistValidationStep?

    private let modelContext: ModelContext
    private let apiClient: XtreamAPIClientProtocol

    init(modelContext: ModelContext, apiClient: XtreamAPIClientProtocol = XtreamAPIClient()) {
        self.modelContext = modelContext
        self.apiClient = apiClient
    }

    func playlists() throws -> [Playlist] {
        let descriptor = FetchDescriptor<Playlist>(sortBy: [SortDescriptor(\Playlist.name, order: .forward)])
        return try modelContext.fetch(descriptor)
    }

    func categories(playlistID: UUID, mediaType: MediaType) throws -> [Category] {
        let descriptor = FetchDescriptor<Category>(
            predicate: #Predicate { model in
                model.playlistID == playlistID && model.mediaTypeRaw == mediaType.rawValue
            },
            sortBy: [SortDescriptor(\Category.orderIndex, order: .forward), SortDescriptor(\Category.name, order: .forward)]
        )
        return try modelContext.fetch(descriptor)
    }

    func streams(playlistID: UUID, mediaType: MediaType, categoryID: String?) throws -> [Stream] {
        if let categoryID {
            let descriptor = FetchDescriptor<Stream>(
                predicate: #Predicate { model in
                    model.playlistID == playlistID && model.mediaTypeRaw == mediaType.rawValue && model.categoryID == categoryID
                }
            )
            return try modelContext.fetch(descriptor)
        }

        let descriptor = FetchDescriptor<Stream>(
            predicate: #Predicate { model in
                model.playlistID == playlistID && model.mediaTypeRaw == mediaType.rawValue
            },
            sortBy: [SortDescriptor(\Stream.title, order: .forward)]
        )
        return try modelContext.fetch(descriptor)
    }

    func series(playlistID: UUID, categoryID: String?) throws -> [Series] {
        if let categoryID {
            let descriptor = FetchDescriptor<Series>(
                predicate: #Predicate { model in
                    model.playlistID == playlistID && model.categoryID == categoryID
                }
            )
            return try modelContext.fetch(descriptor)
        }

        let descriptor = FetchDescriptor<Series>(
            predicate: #Predicate { model in
                model.playlistID == playlistID
            },
            sortBy: [SortDescriptor(\Series.title, order: .forward)]
        )
        return try modelContext.fetch(descriptor)
    }

    func episodes(playlistID: UUID, seriesID: String) throws -> [SeriesEpisode] {
        let descriptor = FetchDescriptor<SeriesEpisode>(
            predicate: #Predicate { model in
                model.playlistID == playlistID && model.seriesID == seriesID
            },
            sortBy: [
                SortDescriptor(\SeriesEpisode.seasonNumber, order: .forward),
                SortDescriptor(\SeriesEpisode.episodeNumber, order: .forward)
            ]
        )
        return try modelContext.fetch(descriptor)
    }

    func favorites() throws -> [FavoriteItem] {
        let descriptor = FetchDescriptor<FavoriteItem>(sortBy: [SortDescriptor(\FavoriteItem.createdAt, order: .reverse)])
        return try modelContext.fetch(descriptor)
    }

    func favoriteKeys(playlistID: UUID? = nil, mediaType: MediaType? = nil) throws -> Set<String> {
        let descriptor: FetchDescriptor<FavoriteItem>

        switch (playlistID, mediaType) {
        case let (playlistID?, mediaType?):
            descriptor = FetchDescriptor<FavoriteItem>(
                predicate: #Predicate { model in
                    model.playlistID == playlistID && model.mediaTypeRaw == mediaType.rawValue
                }
            )
        case let (playlistID?, nil):
            descriptor = FetchDescriptor<FavoriteItem>(
                predicate: #Predicate { model in
                    model.playlistID == playlistID
                }
            )
        case let (nil, mediaType?):
            descriptor = FetchDescriptor<FavoriteItem>(
                predicate: #Predicate { model in
                    model.mediaTypeRaw == mediaType.rawValue
                }
            )
        case (nil, nil):
            descriptor = FetchDescriptor<FavoriteItem>()
        }

        let items = try modelContext.fetch(descriptor)
        return Set(items.map(\.favoriteKey))
    }

    func removeFavorite(_ favorite: FavoriteItem) throws {
        modelContext.delete(favorite)
        try modelContext.save()
    }

    func toggleFavorite(_ playable: PlayableItem) throws {
        let favoriteKey = playable.favoriteKey
        let descriptor = FetchDescriptor<FavoriteItem>(
            predicate: #Predicate { model in
                model.favoriteKey == favoriteKey
            }
        )

        if let existing = try modelContext.fetch(descriptor).first {
            modelContext.delete(existing)
        } else {
            let newFavorite = FavoriteItem(
                playlistID: playable.playlistID,
                mediaType: playable.mediaType,
                itemID: playable.id,
                title: playable.title,
                streamURL: playable.streamURL
            )
            modelContext.insert(newFavorite)
        }

        try modelContext.save()
    }

    func isFavorite(_ playable: PlayableItem) -> Bool {
        let favoriteKey = playable.favoriteKey
        let descriptor = FetchDescriptor<FavoriteItem>(
            predicate: #Predicate { model in
                model.favoriteKey == favoriteKey
            }
        )

        do {
            return try !modelContext.fetch(descriptor).isEmpty
        } catch {
            return false
        }
    }

    func search(query: String) throws -> [SearchResultItem] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return [] }

        let streams = try modelContext.fetch(FetchDescriptor<Stream>())
        let series = try modelContext.fetch(FetchDescriptor<Series>())
        let episodes = try modelContext.fetch(FetchDescriptor<SeriesEpisode>())

        var seenStreamKeys: Set<String> = []
        let streamMatches = streams
            .filter { $0.title.lowercased().contains(normalized) }
            .compactMap { stream -> SearchResultItem? in
                let playable = stream.asPlayable
                let uniqueKey = playable.favoriteKey
                guard seenStreamKeys.insert(uniqueKey).inserted else { return nil }
                return SearchResultItem(
                    id: "stream-\(uniqueKey)",
                    title: stream.title,
                    subtitle: stream.mediaType.displayName,
                    kind: .playable(playable)
                )
            }

        let episodeMatches = episodes
            .filter { $0.title.lowercased().contains(normalized) }
            .map {
                SearchResultItem(
                    id: "episode-\($0.cacheKey)",
                    title: $0.title,
                    subtitle: "Episode · S\($0.seasonNumber)E\($0.episodeNumber)",
                    kind: .playable($0.asPlayable)
                )
            }

        var seenSeriesKeys: Set<String> = []
        let seriesMatches = series
            .filter { $0.title.lowercased().contains(normalized) }
            .compactMap { item -> SearchResultItem? in
                let uniqueKey = "\(item.playlistID.uuidString)|\(item.seriesID)"
                guard seenSeriesKeys.insert(uniqueKey).inserted else { return nil }
                return SearchResultItem(
                    id: "series-\(uniqueKey)",
                    title: item.title,
                    subtitle: "Series",
                    kind: .series(playlistID: item.playlistID, seriesID: item.seriesID)
                )
            }

        return (streamMatches + episodeMatches + seriesMatches)
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    func savePlaylist(_ draft: PlaylistDraft, editing playlist: Playlist?) async throws -> Playlist {
        let cleaned = draft.trimmed()
        let credentials = try cleaned.toCredentials()

        currentValidationStep = .authenticate
        let auth = try await apiClient.authenticate(credentials: credentials)
        let playbackCredentials = credentials.replacingBaseURL(auth.playbackBaseURL)
        let preferredLiveContainer = preferredLiveContainer(from: auth.allowedOutputFormats)
        let preferredVODContainer = preferredVODContainer(from: auth.allowedOutputFormats)

        currentValidationStep = .live
        let liveCategories = try await apiClient.fetchCategories(credentials: credentials, mediaType: .live)
        let liveStreams = try await apiClient.fetchStreams(credentials: credentials, mediaType: .live, categoryID: nil)

        currentValidationStep = .vod
        let vodCategories = try await apiClient.fetchCategories(credentials: credentials, mediaType: .movie)
        let vodStreams = try await apiClient.fetchStreams(credentials: credentials, mediaType: .movie, categoryID: nil)

        currentValidationStep = .series
        let seriesCategories = try await apiClient.fetchCategories(credentials: credentials, mediaType: .series)
        let seriesItems = try await apiClient.fetchSeries(credentials: credentials, categoryID: nil)

        let entity = playlist ?? Playlist(
            name: cleaned.name,
            baseURL: credentials.normalizedBaseURL,
            username: cleaned.username,
            password: cleaned.password
        )

        if playlist == nil {
            modelContext.insert(entity)
        }

        entity.name = cleaned.name
        entity.baseURL = credentials.normalizedBaseURL
        entity.username = cleaned.username
        entity.password = cleaned.password
        entity.updatedAt = .now

        try clearCache(for: entity.id)
        cacheCategories(playlistID: entity.id, mediaType: .live, categories: liveCategories)
        cacheStreams(
            playlistID: entity.id,
            credentials: playbackCredentials,
            mediaType: .live,
            streams: liveStreams,
            preferredLiveContainer: preferredLiveContainer,
            preferredVODContainer: preferredVODContainer
        )

        cacheCategories(playlistID: entity.id, mediaType: .movie, categories: vodCategories)
        cacheStreams(
            playlistID: entity.id,
            credentials: playbackCredentials,
            mediaType: .movie,
            streams: vodStreams,
            preferredLiveContainer: preferredLiveContainer,
            preferredVODContainer: preferredVODContainer
        )

        cacheCategories(playlistID: entity.id, mediaType: .series, categories: seriesCategories)
        cacheSeries(playlistID: entity.id, seriesItems: seriesItems)

        try modelContext.save()
        currentValidationStep = nil
        return entity
    }

    func reloadPlaylist(_ playlist: Playlist) async throws {
        let credentials = playlist.credentials

        currentValidationStep = .authenticate
        let auth = try await apiClient.authenticate(credentials: credentials)
        let playbackCredentials = credentials.replacingBaseURL(auth.playbackBaseURL)
        let preferredLiveContainer = preferredLiveContainer(from: auth.allowedOutputFormats)
        let preferredVODContainer = preferredVODContainer(from: auth.allowedOutputFormats)

        currentValidationStep = .live
        let liveCategories = try await apiClient.fetchCategories(credentials: credentials, mediaType: .live)
        let liveStreams = try await apiClient.fetchStreams(credentials: credentials, mediaType: .live, categoryID: nil)

        currentValidationStep = .vod
        let vodCategories = try await apiClient.fetchCategories(credentials: credentials, mediaType: .movie)
        let vodStreams = try await apiClient.fetchStreams(credentials: credentials, mediaType: .movie, categoryID: nil)

        currentValidationStep = .series
        let seriesCategories = try await apiClient.fetchCategories(credentials: credentials, mediaType: .series)
        let seriesItems = try await apiClient.fetchSeries(credentials: credentials, categoryID: nil)

        try clearCache(for: playlist.id)
        cacheCategories(playlistID: playlist.id, mediaType: .live, categories: liveCategories)
        cacheStreams(
            playlistID: playlist.id,
            credentials: playbackCredentials,
            mediaType: .live,
            streams: liveStreams,
            preferredLiveContainer: preferredLiveContainer,
            preferredVODContainer: preferredVODContainer
        )

        cacheCategories(playlistID: playlist.id, mediaType: .movie, categories: vodCategories)
        cacheStreams(
            playlistID: playlist.id,
            credentials: playbackCredentials,
            mediaType: .movie,
            streams: vodStreams,
            preferredLiveContainer: preferredLiveContainer,
            preferredVODContainer: preferredVODContainer
        )

        cacheCategories(playlistID: playlist.id, mediaType: .series, categories: seriesCategories)
        cacheSeries(playlistID: playlist.id, seriesItems: seriesItems)

        playlist.updatedAt = .now
        try modelContext.save()
        currentValidationStep = nil
    }

    func refreshCategories(playlist: Playlist, mediaType: MediaType) async throws {
        let credentials = playlist.credentials
        let categories = try await apiClient.fetchCategories(credentials: credentials, mediaType: mediaType)
        cacheCategories(playlistID: playlist.id, mediaType: mediaType, categories: categories)
        playlist.updatedAt = .now
        try modelContext.save()
    }

    func refreshMedia(playlist: Playlist, mediaType: MediaType) async throws {
        let credentials = playlist.credentials
        let auth = try await apiClient.authenticate(credentials: credentials)
        let playbackCredentials = credentials.replacingBaseURL(auth.playbackBaseURL)
        let preferredLiveContainer = preferredLiveContainer(from: auth.allowedOutputFormats)
        let preferredVODContainer = preferredVODContainer(from: auth.allowedOutputFormats)
        let categories = try await apiClient.fetchCategories(credentials: credentials, mediaType: mediaType)

        cacheCategories(playlistID: playlist.id, mediaType: mediaType, categories: categories)

        switch mediaType {
        case .live, .movie:
            let streams = try await apiClient.fetchStreams(credentials: credentials, mediaType: mediaType, categoryID: nil)
            cacheStreams(
                playlistID: playlist.id,
                credentials: playbackCredentials,
                mediaType: mediaType,
                streams: streams,
                preferredLiveContainer: preferredLiveContainer,
                preferredVODContainer: preferredVODContainer
            )
        case .series:
            let seriesItems = try await apiClient.fetchSeries(credentials: credentials, categoryID: nil)
            cacheSeries(playlistID: playlist.id, seriesItems: seriesItems)
        }

        playlist.updatedAt = .now
        try modelContext.save()
    }

    func refreshMediaCategory(playlist: Playlist, mediaType: MediaType, categoryID: String) async throws {
        guard !categoryID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            try await refreshMedia(playlist: playlist, mediaType: mediaType)
            return
        }

        let credentials = playlist.credentials
        let auth = try await apiClient.authenticate(credentials: credentials)
        let playbackCredentials = credentials.replacingBaseURL(auth.playbackBaseURL)
        let preferredLiveContainer = preferredLiveContainer(from: auth.allowedOutputFormats)
        let preferredVODContainer = preferredVODContainer(from: auth.allowedOutputFormats)

        switch mediaType {
        case .live, .movie:
            do {
                let streams = try await apiClient.fetchStreams(
                    credentials: credentials,
                    mediaType: mediaType,
                    categoryID: categoryID
                )
                cacheStreams(
                    playlistID: playlist.id,
                    credentials: playbackCredentials,
                    mediaType: mediaType,
                    streams: streams,
                    preferredLiveContainer: preferredLiveContainer,
                    preferredVODContainer: preferredVODContainer,
                    replacingOnlyCategoryID: categoryID
                )
            } catch {
                // Some providers do not support category-filtered stream APIs; fall back to full media fetch.
                let allStreams = try await apiClient.fetchStreams(
                    credentials: credentials,
                    mediaType: mediaType,
                    categoryID: nil
                )
                cacheStreams(
                    playlistID: playlist.id,
                    credentials: playbackCredentials,
                    mediaType: mediaType,
                    streams: allStreams,
                    preferredLiveContainer: preferredLiveContainer,
                    preferredVODContainer: preferredVODContainer
                )
            }
        case .series:
            let seriesItems = try await apiClient.fetchSeries(credentials: credentials, categoryID: categoryID)
            cacheSeries(
                playlistID: playlist.id,
                seriesItems: seriesItems,
                replacingOnlyCategoryID: categoryID
            )
        }

        playlist.updatedAt = .now
        try modelContext.save()
    }

    func loadEpisodes(playlist: Playlist, series: Series, forceRefresh: Bool) async throws -> EpisodeLoadResult {
        if !forceRefresh {
            let cachedEpisodes = try episodes(playlistID: playlist.id, seriesID: series.seriesID)
            if !cachedEpisodes.isEmpty {
                return .episodes(cachedEpisodes)
            }
        }

        let auth = try await apiClient.authenticate(credentials: playlist.credentials)
        let playbackCredentials = playlist.credentials.replacingBaseURL(auth.playbackBaseURL)
        let defaultSeriesContainer = preferredVODContainer(from: auth.allowedOutputFormats) ?? "mp4"
        let info = try await apiClient.fetchSeriesInfo(
            credentials: playbackCredentials,
            seriesID: series.seriesID,
            defaultContainerExtension: defaultSeriesContainer
        )

        if info.episodes.isEmpty {
            let fallbackURL = buildXtreamPlaybackURL(
                credentials: playbackCredentials,
                mediaType: .series,
                streamID: series.seriesID,
                containerExtension: defaultSeriesContainer,
                directSource: nil
            )

            if URL(string: fallbackURL) != nil {
                return .fallbackPlayable(
                    PlayableItem(
                        id: "fallback|\(playlist.id.uuidString)|\(series.seriesID)",
                        title: "\(series.title) (main stream)",
                        subtitle: "Series fallback",
                        streamURL: fallbackURL,
                        mediaType: .series,
                        playlistID: playlist.id
                    ),
                    reason: info.unsupportedReason ?? "The provider does not expose detailed episodes."
                )
            }

            return .unsupported(reason: info.unsupportedReason ?? "The provider does not expose detailed episodes.")
        }

        try deleteEpisodes(playlistID: playlist.id, seriesID: series.seriesID)

        for episode in info.episodes {
            guard let url = episode.streamURL else { continue }
            let entity = SeriesEpisode(
                playlistID: playlist.id,
                seriesID: series.seriesID,
                episodeID: episode.id,
                seasonNumber: episode.season,
                episodeNumber: episode.episodeNumber,
                title: episode.title,
                streamURL: url,
                overview: episode.overview
            )
            modelContext.insert(entity)
        }

        try modelContext.save()
        return .episodes(try episodes(playlistID: playlist.id, seriesID: series.seriesID))
    }

    func deletePlaylist(_ playlist: Playlist) throws {
        try clearCache(for: playlist.id)
        try deleteFavorites(playlistID: playlist.id)
        modelContext.delete(playlist)
        try modelContext.save()
    }

    private func cacheCategories(playlistID: UUID, mediaType: MediaType, categories: [XtreamCategoryDTO]) {
        deleteCategories(playlistID: playlistID, mediaType: mediaType)

        for (index, category) in categories.enumerated() {
            let item = Category(
                playlistID: playlistID,
                mediaType: mediaType,
                categoryID: category.id,
                name: category.name,
                orderIndex: index
            )
            modelContext.insert(item)
        }
    }

    private func cacheStreams(
        playlistID: UUID,
        credentials: PlaylistCredentials,
        mediaType: MediaType,
        streams: [XtreamStreamDTO],
        preferredLiveContainer: String? = nil,
        preferredVODContainer: String? = nil,
        replacingOnlyCategoryID: String? = nil
    ) {
        deleteStreams(playlistID: playlistID, mediaType: mediaType, categoryID: replacingOnlyCategoryID)
        var seenPairs: Set<String> = []

        for stream in streams {
            let streamContainer = normalizedContainerExtension(stream.containerExtension)
            let preferredContainer = mediaType == .live ? preferredLiveContainer : preferredVODContainer
            let preferredNormalized = normalizedContainerExtension(preferredContainer)

            let containerExtension: String?
            if let streamContainer {
                // Keep provider extension when present; player handles fallback attempts.
                containerExtension = streamContainer
            } else if let preferredNormalized {
                containerExtension = preferredNormalized
            } else {
                containerExtension = nil
            }

            let url = buildXtreamPlaybackURL(
                credentials: credentials,
                mediaType: mediaType,
                streamID: stream.streamID,
                containerExtension: containerExtension,
                directSource: stream.directSource
            )

            let categoryIDs = stream.categoryIDs.isEmpty ? [stream.categoryID] : stream.categoryIDs
            for categoryID in categoryIDs {
                if let replacingOnlyCategoryID, categoryID != replacingOnlyCategoryID {
                    continue
                }
                let pairKey = "\(stream.streamID)|\(categoryID)"
                guard seenPairs.insert(pairKey).inserted else { continue }

                let item = Stream(
                    playlistID: playlistID,
                    mediaType: mediaType,
                    streamID: stream.streamID,
                    categoryID: categoryID,
                    title: stream.name,
                    streamURL: url,
                    logoURL: stream.streamIcon
                )
                modelContext.insert(item)
            }
        }
    }

    private func preferredLiveContainer(from outputFormats: [String]) -> String? {
        let normalized = outputFormats
            .compactMap { normalizedContainerExtension($0) }
            .filter { !$0.isEmpty }

        if normalized.contains("m3u8") { return "m3u8" }
        if normalized.contains("ts") { return "ts" }
        return nil
    }

    private func preferredVODContainer(from outputFormats: [String]) -> String? {
        let normalized = outputFormats
            .compactMap { normalizedContainerExtension($0) }
            .filter { !$0.isEmpty }

        let priority = ["m3u8", "mp4", "m4v", "mov", "ts", "avi", "mkv"]
        for candidate in priority where normalized.contains(candidate) {
            return candidate
        }
        return normalized.first
    }

    private func cacheSeries(
        playlistID: UUID,
        seriesItems: [XtreamSeriesDTO],
        replacingOnlyCategoryID: String? = nil
    ) {
        deleteSeries(playlistID: playlistID, categoryID: replacingOnlyCategoryID)
        var seenPairs: Set<String> = []

        for series in seriesItems {
            let categoryIDs = series.categoryIDs.isEmpty ? [series.categoryID] : series.categoryIDs
            for categoryID in categoryIDs {
                if let replacingOnlyCategoryID, categoryID != replacingOnlyCategoryID {
                    continue
                }
                let pairKey = "\(series.seriesID)|\(categoryID)"
                guard seenPairs.insert(pairKey).inserted else { continue }

                let item = Series(
                    playlistID: playlistID,
                    categoryID: categoryID,
                    seriesID: series.seriesID,
                    title: series.name,
                    coverURL: series.coverURL,
                    synopsis: series.synopsis
                )
                modelContext.insert(item)
            }
        }
    }

    private func clearCache(for playlistID: UUID) throws {
        deleteCategories(playlistID: playlistID, mediaType: .live)
        deleteCategories(playlistID: playlistID, mediaType: .movie)
        deleteCategories(playlistID: playlistID, mediaType: .series)
        deleteStreams(playlistID: playlistID, mediaType: .live, categoryID: nil)
        deleteStreams(playlistID: playlistID, mediaType: .movie, categoryID: nil)
        deleteSeries(playlistID: playlistID, categoryID: nil)
        try deleteEpisodes(playlistID: playlistID, seriesID: nil)
    }

    private func deleteCategories(playlistID: UUID, mediaType: MediaType) {
        let descriptor = FetchDescriptor<Category>(
            predicate: #Predicate { model in
                model.playlistID == playlistID && model.mediaTypeRaw == mediaType.rawValue
            }
        )

        do {
            for entity in try modelContext.fetch(descriptor) {
                modelContext.delete(entity)
            }
        } catch {
            // Best effort cleanup; errors are surfaced on save.
        }
    }

    private func deleteStreams(playlistID: UUID, mediaType: MediaType, categoryID: String?) {
        let descriptor: FetchDescriptor<Stream>
        if let categoryID {
            descriptor = FetchDescriptor<Stream>(
                predicate: #Predicate { model in
                    model.playlistID == playlistID && model.mediaTypeRaw == mediaType.rawValue && model.categoryID == categoryID
                }
            )
        } else {
            descriptor = FetchDescriptor<Stream>(
                predicate: #Predicate { model in
                    model.playlistID == playlistID && model.mediaTypeRaw == mediaType.rawValue
                }
            )
        }

        do {
            for entity in try modelContext.fetch(descriptor) {
                modelContext.delete(entity)
            }
        } catch {
            // Best effort cleanup; errors are surfaced on save.
        }
    }

    private func deleteSeries(playlistID: UUID, categoryID: String?) {
        let descriptor: FetchDescriptor<Series>
        if let categoryID {
            descriptor = FetchDescriptor<Series>(
                predicate: #Predicate { model in
                    model.playlistID == playlistID && model.categoryID == categoryID
                }
            )
        } else {
            descriptor = FetchDescriptor<Series>(
                predicate: #Predicate { model in
                    model.playlistID == playlistID
                }
            )
        }

        do {
            for entity in try modelContext.fetch(descriptor) {
                modelContext.delete(entity)
            }
        } catch {
            // Best effort cleanup; errors are surfaced on save.
        }
    }

    private func deleteEpisodes(playlistID: UUID, seriesID: String?) throws {
        if let seriesID {
            let descriptor = FetchDescriptor<SeriesEpisode>(
                predicate: #Predicate { model in
                    model.playlistID == playlistID && model.seriesID == seriesID
                }
            )
            for entity in try modelContext.fetch(descriptor) {
                modelContext.delete(entity)
            }
            return
        }

        let descriptor = FetchDescriptor<SeriesEpisode>(
            predicate: #Predicate { model in
                model.playlistID == playlistID
            }
        )
        for entity in try modelContext.fetch(descriptor) {
            modelContext.delete(entity)
        }
    }

    private func deleteFavorites(playlistID: UUID) throws {
        let descriptor = FetchDescriptor<FavoriteItem>(
            predicate: #Predicate { model in
                model.playlistID == playlistID
            }
        )
        for entity in try modelContext.fetch(descriptor) {
            modelContext.delete(entity)
        }
    }
}
