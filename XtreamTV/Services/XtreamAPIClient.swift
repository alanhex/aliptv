import Foundation

struct XtreamAPIClient {
    let baseURL: URL
    let username: String
    let password: String

    // Construit l'URL de base vers player_api.php
    private var apiEndpoint: URL {
        baseURL.appendingPathComponent("player_api.php")
    }

    func authenticate() async throws -> AuthResponse {
        let url = try makeURL(queryItems: [
            URLQueryItem(name: "username", value: username),
            URLQueryItem(name: "password", value: password)
        ])
        return try await fetchJSON(url: url, type: AuthResponse.self)
    }

    func fetchLiveCategories() async throws -> [Category] {
        let url = try makeURL(queryItems: [
            URLQueryItem(name: "username", value: username),
            URLQueryItem(name: "password", value: password),
            URLQueryItem(name: "action", value: "get_live_categories")
        ])
        return try await fetchJSON(url: url, type: [Category].self)
    }

    func fetchLiveStreams(categoryId: String) async throws -> [Stream] {
        let url = try makeURL(queryItems: [
            URLQueryItem(name: "username", value: username),
            URLQueryItem(name: "password", value: password),
            URLQueryItem(name: "action", value: "get_live_streams"),
            URLQueryItem(name: "category_id", value: categoryId)
        ])
        return try await fetchJSON(url: url, type: [Stream].self)
    }

    func fetchVodCategories() async throws -> [Category] {
        let url = try makeURL(queryItems: [
            URLQueryItem(name: "username", value: username),
            URLQueryItem(name: "password", value: password),
            URLQueryItem(name: "action", value: "get_vod_categories")
        ])
        return try await fetchJSON(url: url, type: [Category].self)
    }

    func fetchVodStreams(categoryId: String) async throws -> [Stream] {
        let url = try makeURL(queryItems: [
            URLQueryItem(name: "username", value: username),
            URLQueryItem(name: "password", value: password),
            URLQueryItem(name: "action", value: "get_vod_streams"),
            URLQueryItem(name: "category_id", value: categoryId)
        ])
        return try await fetchJSON(url: url, type: [Stream].self)
    }

    func fetchSeriesCategories() async throws -> [Category] {
        let url = try makeURL(queryItems: [
            URLQueryItem(name: "username", value: username),
            URLQueryItem(name: "password", value: password),
            URLQueryItem(name: "action", value: "get_series_categories")
        ])
        return try await fetchJSON(url: url, type: [Category].self)
    }

    func fetchSeries(categoryId: String) async throws -> [SeriesItem] {
        let url = try makeURL(queryItems: [
            URLQueryItem(name: "username", value: username),
            URLQueryItem(name: "password", value: password),
            URLQueryItem(name: "action", value: "get_series"),
            URLQueryItem(name: "category_id", value: categoryId)
        ])
        return try await fetchJSON(url: url, type: [SeriesItem].self)
    }

    // Construit l'URL du flux .m3u8 pour une chaîne
    func makeStreamURL(streamId: Int) -> URL {
        baseURL
            .appendingPathComponent("live")
            .appendingPathComponent(username)
            .appendingPathComponent(password)
            .appendingPathComponent("\(streamId).m3u8")
    }

    func makeVodURL(streamId: Int, container: String?) -> URL {
        let ext = container ?? "mp4"
        return baseURL
            .appendingPathComponent("movie")
            .appendingPathComponent(username)
            .appendingPathComponent(password)
            .appendingPathComponent("\(streamId).\(ext)")
    }

    private func makeURL(queryItems: [URLQueryItem]) throws -> URL {
        guard var components = URLComponents(url: apiEndpoint, resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        components.queryItems = queryItems
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        return url
    }

    private func fetchJSON<T: Decodable>(url: URL, type: T.Type) async throws -> T {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
