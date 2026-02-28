import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var repository: IPTVRepository

    let onPlay: (PlayableItem) -> Void
    let onOpenSeries: (UUID, String) -> Void

    @State private var query = ""
    @State private var results: [SearchResultItem] = []
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Search")
                .font(.largeTitle.bold())

            TextField("Channel, movie, series, or episode", text: $query)
                .padding(12)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .onChange(of: query) { _, _ in
                    performSearch()
                }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }

            if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ContentUnavailableView("Start typing", systemImage: "magnifyingglass")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if results.isEmpty {
                ContentUnavailableView("No results", systemImage: "text.magnifyingglass")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(results) { result in
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(result.title)
                                .font(.headline)
                                .lineLimit(1)
                            Text(result.subtitle)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        switch result.kind {
                        case .playable(let playable):
                            Button("Play") {
                                onPlay(playable)
                            }
                            .buttonStyle(.borderedProminent)
                        case .series(let playlistID, let seriesID):
                            Button("Open") {
                                onOpenSeries(playlistID, seriesID)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.vertical, 6)
                }
                .listStyle(.plain)
            }
        }
        .onAppear(perform: performSearch)
    }

    private func performSearch() {
        do {
            results = try repository.search(query: query)
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            results = []
        }
    }
}
