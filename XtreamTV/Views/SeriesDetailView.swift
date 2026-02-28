import SwiftUI

struct SeriesDetailView: View {
    let item: SeriesItem
    let client: XtreamAPIClient

    @StateObject private var viewModel: SeriesDetailViewModel
    @Namespace private var defaultFocus

    init(item: SeriesItem, client: XtreamAPIClient) {
        self.item = item
        self.client = client
        _viewModel = StateObject(wrappedValue: SeriesDetailViewModel(client: client, seriesId: item.id))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(item.name)
                    .font(.title)
                    .bold()

                if viewModel.isLoading {
                    ProgressView()
                } else if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                } else if viewModel.episodesBySeason.isEmpty {
                    Text("No episodes available.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.episodesBySeason, id: \.season) { season, episodes in
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Season \(season)")
                                .font(.title3)
                                .bold()

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 20)], spacing: 20) {
                                ForEach(episodes) { episode in
                                    let stream = Stream(
                                        id: episode.id,
                                        name: episodeTitle(episode, season: season),
                                        streamIcon: nil,
                                        streamType: "series",
                                        categoryId: nil,
                                        containerExtension: episode.containerExtension
                                    )
                                    NavigationLink {
                                        PlayerView(stream: stream, streamURL: client.makeSeriesURL(episodeId: episode.id, container: episode.containerExtension))
                                    } label: {
                                        EpisodeCardView(title: stream.name)
                                    }
                                    .buttonStyle(.card)
                                    .prefersDefaultFocus(episodes.first == episode, in: defaultFocus)
                                }
                            }
                            .focusSection()
                        }
                    }
                }
            }
            .padding(60)
        }
        .task {
            await viewModel.load()
        }
    }

    private func episodeTitle(_ episode: SeriesEpisode, season: String) -> String {
        if let number = episode.episodeNum {
            return "S\(season)E\(number) - \(episode.title)"
        }
        return episode.title
    }
}

private struct EpisodeCardView: View {
    let title: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "play.rectangle")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(.blue)

            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(16)
        .frame(height: 200)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.blue.opacity(0.15))
        )
    }
}
