import Foundation

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published private(set) var categories: [Category] = []
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String?

    private let client: XtreamAPIClient

    init(client: XtreamAPIClient) {
        self.client = client
    }

    // Charge les catégories Live TV depuis l'API
    func loadCategories() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            categories = try await client.fetchLiveCategories()
        } catch {
            errorMessage = "Impossible de charger les catégories : \(error.localizedDescription)"
        }
    }

    // Charge les catégories VOD (Films)
    func loadCategoriesVod() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            categories = try await client.fetchVodCategories()
        } catch {
            errorMessage = "Impossible de charger les catégories VOD : \(error.localizedDescription)"
        }
    }

    // Charge les catégories Séries
    func loadCategoriesSeries() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            categories = try await client.fetchSeriesCategories()
        } catch {
            errorMessage = "Impossible de charger les catégories Séries : \(error.localizedDescription)"
        }
    }
}
