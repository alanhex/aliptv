import Foundation

@MainActor
final class SeriesListViewModel: ObservableObject {
    @Published private(set) var series: [SeriesItem] = []
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String?

    private let client: XtreamAPIClient
    private let categoryId: String

    init(client: XtreamAPIClient, categoryId: String) {
        self.client = client
        self.categoryId = categoryId
    }

    func loadSeries() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            series = try await client.fetchSeries(categoryId: categoryId)
        } catch {
            errorMessage = "Impossible de charger les séries : \(error.localizedDescription)"
        }
    }
}
