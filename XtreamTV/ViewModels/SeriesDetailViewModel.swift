import Foundation

@MainActor
final class SeriesDetailViewModel: ObservableObject {
    @Published private(set) var info: SeriesInfo?
    @Published private(set) var episodesBySeason: [(season: String, episodes: [SeriesEpisode])] = []
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String?

    private let client: XtreamAPIClient
    private let seriesId: Int

    init(client: XtreamAPIClient, seriesId: Int) {
        self.client = client
        self.seriesId = seriesId
    }

    func load() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await client.fetchSeriesInfo(seriesId: seriesId)
            info = response.info
            let sorted = response.episodes
                .map { key, value in
                    let ordered = value.sorted { ($0.episodeNum ?? 0) < ($1.episodeNum ?? 0) }
                    return (season: key, episodes: ordered)
                }
                .sorted { $0.season.localizedStandardCompare($1.season) == .orderedAscending }
            episodesBySeason = sorted
        } catch {
            errorMessage = "Unable to load episodes: \(error.localizedDescription)"
        }
    }
}
