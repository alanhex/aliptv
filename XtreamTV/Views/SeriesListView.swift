import SwiftUI

struct SeriesListView: View {
    @EnvironmentObject private var repository: IPTVRepository

    let playlist: Playlist
    let onPlay: (PlayableItem) -> Void
    var onSeriesFocusChange: ((Bool) -> Void)? = nil

    @State private var viewModel: SeriesListViewModel?
    @FocusState private var focusedCategoryKey: String?
    @FocusState private var focusedSeriesKey: String?
    @State private var selectedSeriesKey: String?
    @State private var seriesPaneHasFocus = false
    @State private var pendingSidebarExitKey: String?
    @State private var presentedSeriesDetails: Series?
    @State private var lastCategoryID: String?

    private struct NoScaleListButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .scaleEffect(1.0)
                .opacity(configuration.isPressed ? 0.94 : 1.0)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if let viewModel {
                if viewModel.isLoading && viewModel.categories.isEmpty && viewModel.seriesList.isEmpty {
                    ProgressView("Loading series...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    HStack(spacing: 12) {
                        if !seriesPaneHasFocus {
                            categoryPane(viewModel: viewModel)
                        }
                        seriesGridPane(viewModel: viewModel)
                    }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: playlist.id) {
            let created = SeriesListViewModel(repository: repository, playlist: playlist)
            viewModel = created
            await created.load()
            focusedCategoryKey = created.categories.first?.cacheKey
            lastCategoryID = created.selectedCategoryID
            selectedSeriesKey = created.seriesList.first?.cacheKey
            focusedSeriesKey = selectedSeriesKey
            seriesPaneHasFocus = true
            onSeriesFocusChange?(true)
        }
        .onChange(of: viewModel?.selectedCategoryID) { _, newCategoryID in
            guard let viewModel else { return }

            // Sync category focus indicator
            if let newCategoryID,
               let selected = viewModel.categories.first(where: { $0.categoryID == newCategoryID }) {
                focusedCategoryKey = selected.cacheKey
            }

            // When category actually changed, reset series selection to first item
            if newCategoryID != lastCategoryID {
                lastCategoryID = newCategoryID
                let firstKey = viewModel.seriesList.first?.cacheKey
                selectedSeriesKey = firstKey
                if seriesPaneHasFocus {
                    focusedSeriesKey = firstKey
                }
            }
        }
        .onChange(of: focusedCategoryKey) { _, newFocusedKey in
            guard
                let viewModel,
                let newFocusedKey,
                let focusedCategory = viewModel.categories.first(where: { $0.cacheKey == newFocusedKey })
            else { return }

            if viewModel.selectedCategoryID != focusedCategory.categoryID || viewModel.seriesList.isEmpty {
                viewModel.selectCategory(focusedCategory.categoryID)
            }
        }
        .onChange(of: focusedSeriesKey) { _, newFocused in
            seriesPaneHasFocus = (newFocused != nil)
            if seriesPaneHasFocus {
                onSeriesFocusChange?(true)
            }
            if let newFocused {
                selectedSeriesKey = newFocused
                pendingSidebarExitKey = nil
            }
        }
        .onMoveCommand(perform: handleSeriesMoveCommand)
        .fullScreenCover(
            isPresented: Binding(
                get: { presentedSeriesDetails != nil },
                set: { isPresented in
                    if !isPresented {
                        presentedSeriesDetails = nil
                    }
                }
            )
        ) {
            if let series = presentedSeriesDetails {
                SeriesDetailsView(
                    playlist: playlist,
                    series: series,
                    onPlay: { playable in
                        presentedSeriesDetails = nil
                        onPlay(playable)
                    }
                )
            }
        }
    }

    private var header: some View {
        HStack {
            Text("\(playlist.name) · Series")
                .font(.title3.bold())
                .lineLimit(1)

            Spacer()

            if viewModel?.isLoading == true {
                ProgressView()
            }

            Button {
                guard let viewModel else { return }
                Task { await viewModel.load() }
            } label: {
                Label("Reload", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
    }

    private func categoryPane(viewModel: SeriesListViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Categories")
                .font(.headline)

            if viewModel.categories.isEmpty {
                ContentUnavailableView("No categories", systemImage: "square.grid.2x2")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.categories, id: \.cacheKey) { category in
                            Button {
                                focusedCategoryKey = category.cacheKey
                                selectedSeriesKey = nil
                                focusedSeriesKey = nil
                                seriesPaneHasFocus = false
                                viewModel.selectCategory(category.categoryID)
                            } label: {
                                CategoryCardView(
                                    category: category,
                                    isSelected: viewModel.selectedCategoryID == category.categoryID,
                                    isFocused: focusedCategoryKey == category.cacheKey
                                )
                            }
                            .buttonStyle(NoScaleListButtonStyle())
                            .focusEffectDisabled()
                            .focused($focusedCategoryKey, equals: category.cacheKey)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .focusSection()
            }
        }
        .frame(width: 380)
        .animation(.easeOut(duration: 0.2), value: seriesPaneHasFocus)
    }

    private func seriesGridPane(viewModel: SeriesListViewModel) -> some View {
        let selected = selectedSeries(in: viewModel)

        return VStack(alignment: .leading, spacing: 12) {
            if let selected {
                Text(selected.title)
                    .font(.title2.bold())
                    .lineLimit(1)
            }

            if viewModel.isCategoryLoading {
                ProgressView("Loading category...")
                    .padding(.vertical, 4)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .lineLimit(3)
            }

            if viewModel.seriesList.isEmpty {
                ContentUnavailableView("No series", systemImage: "sparkles.tv")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(
                        columns: seriesGridColumns,
                        spacing: 18
                    ) {
                        ForEach(viewModel.seriesList, id: \.cacheKey) { series in
                            Button {
                                selectedSeriesKey = series.cacheKey
                                presentedSeriesDetails = series
                            } label: {
                                PosterTile(
                                    title: series.title,
                                    posterURL: series.coverURL,
                                    isFocused: focusedSeriesKey == series.cacheKey,
                                    systemImageFallback: "sparkles.tv"
                                )
                            }
                            .buttonStyle(NoScaleListButtonStyle())
                            .focusEffectDisabled()
                            .focused($focusedSeriesKey, equals: series.cacheKey)
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 2)
                }
                .focusSection()
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func selectedSeries(in viewModel: SeriesListViewModel) -> Series? {
        if let selectedSeriesKey,
           let selected = viewModel.seriesList.first(where: { $0.cacheKey == selectedSeriesKey }) {
            return selected
        }
        return viewModel.seriesList.first
    }

    private var seriesGridColumnCount: Int {
        seriesPaneHasFocus ? 7 : 6
    }

    private var seriesGridColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(minimum: 170, maximum: 230), spacing: 18),
            count: seriesGridColumnCount
        )
    }

    private func handleSeriesMoveCommand(_ direction: MoveCommandDirection) {
        guard let viewModel else { return }

        switch direction {
        case .right:
            pendingSidebarExitKey = nil
            if focusedSeriesKey == nil {
                let target = selectedSeriesKey ?? viewModel.seriesList.first?.cacheKey
                guard let target else { return }
                focusedSeriesKey = target
                selectedSeriesKey = target
                seriesPaneHasFocus = true
                onSeriesFocusChange?(true)
            }
        case .left:
            if focusedSeriesKey == nil {
                if focusedCategoryKey != nil {
                    onSeriesFocusChange?(false)
                }
                return
            }

            guard let focusedSeriesKey,
                  let focusedIndex = viewModel.seriesList.firstIndex(where: { $0.cacheKey == focusedSeriesKey }) else {
                return
            }

            if focusedIndex % seriesGridColumnCount == 0 {
                if pendingSidebarExitKey == focusedSeriesKey {
                    self.focusedSeriesKey = nil
                    seriesPaneHasFocus = false
                    pendingSidebarExitKey = nil
                    if let selectedCategoryID = viewModel.selectedCategoryID,
                       let selectedCategory = viewModel.categories.first(where: { $0.categoryID == selectedCategoryID }) {
                        focusedCategoryKey = selectedCategory.cacheKey
                    } else {
                        focusedCategoryKey = viewModel.categories.first?.cacheKey
                    }
                } else {
                    pendingSidebarExitKey = focusedSeriesKey
                }
            } else {
                pendingSidebarExitKey = nil
            }
        default:
            pendingSidebarExitKey = nil
        }
    }
}

// MARK: - Series Details Modal

private struct SeriesDetailsView: View {
    @EnvironmentObject private var repository: IPTVRepository
    let playlist: Playlist
    let series: Series
    let onPlay: (PlayableItem) -> Void

    @Environment(\.dismiss) private var dismiss

    private struct NoScaleButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .scaleEffect(1.0)
                .opacity(configuration.isPressed ? 0.9 : 1.0)
        }
    }

    @State private var episodes: [SeriesEpisode] = []
    @State private var fallbackPlayable: PlayableItem?
    @State private var unsupportedReason: String?
    @State private var isLoadingEpisodes = true
    @State private var errorMessage: String?
    @State private var selectedSeason: Int?
    @FocusState private var focusedSeason: Int?
    @FocusState private var focusedEpisodeKey: String?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Full-screen backdrop
                seriesBackdrop
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()

                // Gradient overlay
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.98),
                        Color.black.opacity(0.75),
                        Color.black.opacity(0.3),
                        Color.clear
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )

                // Main content
                VStack(alignment: .leading, spacing: 0) {
                    Spacer()

                    // ── Top: Series info ──
                    VStack(alignment: .leading, spacing: 14) {
                        // Title
                        Text(series.title.isEmpty ? "Title unavailable" : series.title)
                            .font(.system(size: 52, weight: .bold, design: .rounded))
                            .lineLimit(2)
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.8), radius: 12, y: 4)

                        // Synopsis
                        if let synopsis = series.synopsis, !synopsis.isEmpty {
                            Text(synopsis)
                                .font(.callout)
                                .foregroundStyle(.white.opacity(0.85))
                                .lineLimit(4)
                                .frame(maxWidth: 700, alignment: .leading)
                                .shadow(color: .black.opacity(0.6), radius: 6, y: 2)
                        }

                        // Play button
                        if let firstEpisode = filteredEpisodes.first {
                            Button {
                                onPlay(firstEpisode.asPlayable)
                            } label: {
                                Label(playButtonLabel, systemImage: "play.fill")
                                    .font(.callout.weight(.semibold))
                                    .padding(.horizontal, 28)
                                    .padding(.vertical, 12)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.white)
                            .foregroundStyle(.black)
                            .shadow(color: .black.opacity(0.4), radius: 8, y: 2)
                            .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, 80)
                    .padding(.bottom, 28)

                    // ── Divider + Episodes section (opaque background) ──
                    VStack(alignment: .leading, spacing: 0) {
                        // Divider line
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 1)

                        // Seasons + Episodes content
                        if isLoadingEpisodes {
                            ProgressView("Loading episodes...")
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 30)
                        } else if let reason = unsupportedReason {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(reason)
                                    .foregroundStyle(.white.opacity(0.7))
                                    .fixedSize(horizontal: false, vertical: true)

                                if let fallbackPlayable {
                                    Button("Play main stream") {
                                        onPlay(fallbackPlayable)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.white)
                                    .foregroundStyle(.black)
                                }
                            }
                            .padding(24)
                            .padding(.horizontal, 80)
                        } else if episodes.isEmpty {
                            Text("No episodes available")
                                .foregroundStyle(.white.opacity(0.6))
                                .padding(.horizontal, 80)
                                .padding(.vertical, 20)
                        } else {
                            HStack(alignment: .top, spacing: 0) {
                                // Season column (label + list)
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Seasons")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)

                                    ForEach(availableSeasons, id: \.self) { season in
                                        seasonButton(season)
                                    }
                                }
                                .frame(width: 180)
                                .padding(.leading, 80)
                                .padding(.trailing, 24)
                                .focusSection()

                                // Episodes column (label + cards)
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Episodes")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)

                                    ScrollView(.vertical, showsIndicators: true) {
                                        LazyVStack(spacing: 8) {
                                            ForEach(filteredEpisodes, id: \.cacheKey) { episode in
                                                Button {
                                                    onPlay(episode.asPlayable)
                                                } label: {
                                                    episodeCard(episode, isFocused: focusedEpisodeKey == episode.cacheKey)
                                                }
                                                .buttonStyle(NoScaleButtonStyle())
                                                .focusEffectDisabled()
                                                .focused($focusedEpisodeKey, equals: episode.cacheKey)
                                            }
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                                .padding(.trailing, 80)
                                .focusSection()
                            }
                            .padding(.top, 8)
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .foregroundStyle(.red)
                                .lineLimit(3)
                                .padding(.horizontal, 80)
                        }
                    }
                    .background(Color(.sRGB, red: 0.06, green: 0.06, blue: 0.08, opacity: 1))
                }

                // Close button
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 34, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.95))
                                .shadow(color: .black.opacity(0.6), radius: 8, y: 3)
                        }
                        .buttonStyle(NoScaleButtonStyle())
                        .focusEffectDisabled()
                    }
                    .padding(.top, 28)
                    .padding(.trailing, 34)
                    Spacer()
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
        .task {
            await loadEpisodes()
        }
    }

    // MARK: - Play Button Label

    private var playButtonLabel: String {
        guard let season = selectedSeason else { return "Play" }
        let episodeCount = filteredEpisodes.count
        if episodeCount > 0 {
            let ep = filteredEpisodes[0]
            return "Play Season \(season): Episode \(ep.episodeNumber)"
        }
        return "Play Season \(season)"
    }

    // MARK: - Season Button

    private func seasonButton(_ season: Int) -> some View {
        let isSelected = selectedSeason == season
        let isFocused = focusedSeason == season

        return Button {
            selectedSeason = season
        } label: {
            Text("Season \(season)")
                .font(.subheadline.weight(isSelected ? .bold : .regular))
                .foregroundStyle(isSelected || isFocused ? .white : .white.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isFocused ? Color.white.opacity(0.2) : (isSelected ? Color.white.opacity(0.12) : Color.clear))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    if isFocused {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
                    }
                }
        }
        .buttonStyle(NoScaleButtonStyle())
        .focusEffectDisabled()
        .focused($focusedSeason, equals: season)
    }

    // MARK: - Episode Card

    private func episodeCard(_ episode: SeriesEpisode, isFocused: Bool) -> some View {
        HStack(spacing: 16) {
            // Episode thumbnail
            Group {
                if let thumbnailURL = episode.thumbnailURL,
                   let url = URL(string: thumbnailURL.trimmingCharacters(in: .whitespacesAndNewlines)),
                   !thumbnailURL.isEmpty {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        default:
                            thumbnailPlaceholder
                        }
                    }
                } else {
                    thumbnailPlaceholder
                }
            }
            .frame(width: 200, height: 112)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                // Episode code
                Text("S\(String(format: "%02d", episode.seasonNumber))E\(String(format: "%02d", episode.episodeNumber))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.45))

                // Episode title
                Text(episode.title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                    .foregroundStyle(.white)

                // Metadata line (duration, air date, rating)
                let metaParts = episodeMetadata(episode)
                if !metaParts.isEmpty {
                    Text(metaParts)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.45))
                        .padding(.top, 1)
                }

                // Description
                if let overview = episode.overview, !overview.isEmpty {
                    Text(overview)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(isFocused ? Color.white.opacity(0.1) : Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            if isFocused {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
            }
        }
    }

    private var thumbnailPlaceholder: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.white.opacity(0.08))
            .overlay {
                Image(systemName: "play.fill")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.4))
            }
    }

    private func episodeMetadata(_ episode: SeriesEpisode) -> String {
        var parts: [String] = []
        if let duration = episode.duration, !duration.isEmpty {
            parts.append(duration)
        }
        if let airDate = episode.airDate, !airDate.isEmpty {
            parts.append(airDate)
        }
        if let rating = episode.rating, rating > 0 {
            parts.append("★ \(String(format: "%.1f", rating))")
        }
        return parts.joined(separator: "  ·  ")
    }

    // MARK: - Backdrop

    @ViewBuilder
    private var seriesBackdrop: some View {
        let urlString = series.coverURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let urlString, let url = URL(string: urlString), !urlString.isEmpty {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                default:
                    fallbackBackground
                }
            }
        } else {
            fallbackBackground
        }
    }

    private var fallbackBackground: some View {
        LinearGradient(
            colors: [
                Color(.sRGB, red: 0.08, green: 0.09, blue: 0.12, opacity: 1),
                Color(.sRGB, red: 0.03, green: 0.03, blue: 0.04, opacity: 1)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Episode Data

    private var availableSeasons: [Int] {
        Array(Set(episodes.map(\.seasonNumber))).sorted()
    }

    private var filteredEpisodes: [SeriesEpisode] {
        guard let selectedSeason else { return episodes }
        return episodes.filter { $0.seasonNumber == selectedSeason }
    }

    private func loadEpisodes() async {
        isLoadingEpisodes = true
        unsupportedReason = nil
        fallbackPlayable = nil
        errorMessage = nil

        do {
            let result = try await repository.loadEpisodes(playlist: playlist, series: series, forceRefresh: true)
            switch result {
            case .episodes(let loadedEpisodes):
                self.episodes = loadedEpisodes
                if let firstSeason = availableSeasons.first {
                    selectedSeason = firstSeason
                }
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
}
