import Foundation

@MainActor
final class StreamListViewModel: ObservableObject {
    @Published private(set) var streams: [Stream] = []
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String?

    private let client: XtreamAPIClient
    private let categoryId: String
    private let mediaType: MediaType

    init(client: XtreamAPIClient, categoryId: String, mediaType: MediaType) {
        self.client = client
        self.categoryId = categoryId
        self.mediaType = mediaType
    }

    // Charge les chaînes Live TV d'une catégorie
    func loadStreams() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            switch mediaType {
            case .live:
                streams = try await client.fetchLiveStreams(categoryId: categoryId)
            case .vod:
                streams = try await client.fetchVodStreams(categoryId: categoryId)
            case .series:
                streams = []
            }
        } catch {
            errorMessage = "Impossible de charger les chaînes : \(error.localizedDescription)"
        }
    }
}
