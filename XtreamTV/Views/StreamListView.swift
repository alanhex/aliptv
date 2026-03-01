import SwiftUI

struct StreamListView: View {
    @EnvironmentObject private var repository: IPTVRepository

    let playlist: Playlist
    let mediaType: MediaType
    let onPlay: (PlayableItem) -> Void
    var onMovieFocusChange: ((Bool) -> Void)? = nil

    @State private var viewModel: StreamListViewModel?
    @FocusState private var focusedCategoryKey: String?
    @FocusState private var focusedMovieKey: String?
    @State private var selectedMovieKey: String?
    @State private var moviePaneHasFocus = false
    @State private var pendingSidebarExitFromMovieKey: String?
    @State private var presentedMovieDetails: Stream?

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
                if viewModel.isLoading && viewModel.categories.isEmpty && viewModel.streams.isEmpty {
                    ProgressView("Loading \(mediaType.displayName.lowercased())...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    HStack(spacing: 12) {
                        if mediaType == .movie {
                            if !moviePaneHasFocus {
                                categoryPane(viewModel: viewModel)
                            }
                            moviePane(viewModel: viewModel)
                        } else {
                            categoryPane(viewModel: viewModel)
                            streamPane(viewModel: viewModel)
                        }
                    }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: "\(playlist.id.uuidString)|\(mediaType.rawValue)") {
            let created = StreamListViewModel(repository: repository, playlist: playlist, mediaType: mediaType)
            viewModel = created
            await created.load()
            focusedCategoryKey = created.categories.first?.cacheKey
            selectedMovieKey = created.streams.first?.cacheKey
            if mediaType == .movie {
                focusedMovieKey = selectedMovieKey
                moviePaneHasFocus = true
                onMovieFocusChange?(true)
            } else {
                focusedMovieKey = nil
                moviePaneHasFocus = false
                onMovieFocusChange?(false)
            }
        }
        .onChange(of: viewModel?.selectedCategoryID) { _, newCategoryID in
            guard
                let viewModel,
                let newCategoryID,
                let selected = viewModel.categories.first(where: { $0.categoryID == newCategoryID })
            else { return }
            focusedCategoryKey = selected.cacheKey
        }
        .onChange(of: focusedCategoryKey) { _, newFocusedKey in
            guard
                mediaType != .movie,
                let viewModel,
                let newFocusedKey,
                let focusedCategory = viewModel.categories.first(where: { $0.cacheKey == newFocusedKey })
            else { return }

            if viewModel.selectedCategoryID != focusedCategory.categoryID || viewModel.streams.isEmpty {
                viewModel.selectCategory(focusedCategory.categoryID)
            }
        }
        .onChange(of: viewModel?.streams.map(\.cacheKey)) { _, keys in
            guard mediaType == .movie, let keys else { return }

            if let selectedMovieKey, keys.contains(selectedMovieKey) {
                return
            }
            selectedMovieKey = keys.first

            if moviePaneHasFocus {
                focusedMovieKey = selectedMovieKey
            }
        }
        .onChange(of: focusedMovieKey) { _, newFocused in
            guard mediaType == .movie else { return }
            moviePaneHasFocus = (newFocused != nil)
            if moviePaneHasFocus {
                onMovieFocusChange?(true)
            }
            if let newFocused {
                selectedMovieKey = newFocused
                pendingSidebarExitFromMovieKey = nil
            }
        }
        .onMoveCommand(perform: handleMovieMoveCommand)
        .fullScreenCover(
            isPresented: Binding(
                get: { presentedMovieDetails != nil },
                set: { isPresented in
                    if !isPresented {
                        presentedMovieDetails = nil
                    }
                }
            )
        ) {
            if let movie = presentedMovieDetails {
                MovieDetailsView(
                    repository: repository,
                    playlist: playlist,
                    movie: movie,
                    onPlay: {
                        presentedMovieDetails = nil
                        onPlay(movie.asPlayable)
                    }
                )
            }
        }
    }

    private var header: some View {
        HStack {
            Text("\(playlist.name) · \(mediaType.displayName)")
                .font(.title3.bold())
                .lineLimit(1)

            Spacer()

            if viewModel?.isRefreshing == true {
                ProgressView()
            }

            Button {
                guard let viewModel else { return }
                Task { await viewModel.refresh() }
            } label: {
                Label("Reload", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
    }

    private func categoryPane(viewModel: StreamListViewModel) -> some View {
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
                                if mediaType == .movie {
                                    selectedMovieKey = nil
                                    focusedMovieKey = nil
                                    moviePaneHasFocus = false
                                }
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
        .frame(width: mediaType == .movie ? 380 : 332)
        .animation(.easeOut(duration: 0.2), value: moviePaneHasFocus)
    }

    private func moviePane(viewModel: StreamListViewModel) -> some View {
        let selected = selectedMovie(in: viewModel)

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

            if viewModel.streams.isEmpty {
                ContentUnavailableView("No movies", systemImage: "film")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(
                        columns: movieGridColumns,
                        spacing: 18
                    ) {
                        ForEach(viewModel.streams, id: \.cacheKey) { stream in
                            Button {
                                selectedMovieKey = stream.cacheKey
                                presentedMovieDetails = stream
                            } label: {
                                PosterTile(
                                    title: stream.title,
                                    posterURL: stream.logoURL,
                                    isFocused: focusedMovieKey == stream.cacheKey
                                )
                            }
                            .buttonStyle(NoScaleListButtonStyle())
                            .focusEffectDisabled()
                            .focused($focusedMovieKey, equals: stream.cacheKey)
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

    private func streamPane(viewModel: StreamListViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(mediaType.displayName)
                .font(.title3.bold())

            if viewModel.isCategoryLoading {
                ProgressView("Loading category...")
                    .padding(.vertical, 4)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .lineLimit(3)
            }

            if viewModel.streams.isEmpty {
                ContentUnavailableView("No items", systemImage: "tv")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.streams, id: \.cacheKey) { stream in
                    StreamCardView(
                        title: stream.title,
                        subtitle: stream.mediaType.displayName,
                        details: streamBrowseDetails(stream),
                        posterURL: stream.logoURL,
                        isFavorite: viewModel.isFavorite(stream),
                        onPlay: { onPlay(stream.asPlayable) },
                        onToggleFavorite: { viewModel.toggleFavorite(stream) }
                    )
                }
                .listStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func selectedMovie(in viewModel: StreamListViewModel) -> Stream? {
        if let selectedMovieKey,
           let selected = viewModel.streams.first(where: { $0.cacheKey == selectedMovieKey }) {
            return selected
        }
        return viewModel.streams.first
    }

    private var movieGridColumnCount: Int {
        moviePaneHasFocus ? 7 : 6
    }

    private var movieGridColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(minimum: 170, maximum: 230), spacing: 18),
            count: movieGridColumnCount
        )
    }

    private func handleMovieMoveCommand(_ direction: MoveCommandDirection) {
        guard mediaType == .movie, let viewModel else { return }

        switch direction {
        case .right:
            pendingSidebarExitFromMovieKey = nil
            if focusedMovieKey == nil {
                let target = selectedMovieKey ?? viewModel.streams.first?.cacheKey
                guard let target else { return }
                focusedMovieKey = target
                selectedMovieKey = target
                moviePaneHasFocus = true
                onMovieFocusChange?(true)
            }
        case .left:
            if focusedMovieKey == nil {
                // When already outside movie cards, only request global sidebar expansion.
                // Do not pull focus back to categories.
                if focusedCategoryKey != nil {
                    onMovieFocusChange?(false)
                }
                return
            }

            guard let focusedMovieKey,
                  let focusedIndex = viewModel.streams.firstIndex(where: { $0.cacheKey == focusedMovieKey }) else {
                return
            }

            if focusedIndex % movieGridColumnCount == 0 {
                // First left keeps focus in first column; second consecutive left exits to in-page categories.
                if pendingSidebarExitFromMovieKey == focusedMovieKey {
                    self.focusedMovieKey = nil
                    moviePaneHasFocus = false
                    pendingSidebarExitFromMovieKey = nil
                    if let selectedCategoryID = viewModel.selectedCategoryID,
                       let selectedCategory = viewModel.categories.first(where: { $0.categoryID == selectedCategoryID }) {
                        focusedCategoryKey = selectedCategory.cacheKey
                    } else {
                        focusedCategoryKey = viewModel.categories.first?.cacheKey
                    }
                } else {
                    pendingSidebarExitFromMovieKey = focusedMovieKey
                }
            } else {
                pendingSidebarExitFromMovieKey = nil
            }
        default:
            pendingSidebarExitFromMovieKey = nil
        }
    }

    private func streamBrowseDetails(_ stream: Stream) -> String? {
        var parts: [String] = []
        if let releaseYear = stream.releaseYear?.trimmingCharacters(in: .whitespacesAndNewlines), !releaseYear.isEmpty {
            parts.append(releaseYear)
        }
        if let genre = stream.genre?.trimmingCharacters(in: .whitespacesAndNewlines), !genre.isEmpty {
            parts.append(genre)
        }
        let header = parts.joined(separator: " · ")
        let synopsis = stream.synopsis?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let synopsis, !synopsis.isEmpty {
            if header.isEmpty {
                return synopsis
            }
            return "\(header)\n\(synopsis)"
        }

        return header.isEmpty ? nil : header
    }
}

private struct MovieDetailsView: View {
    @StateObject private var viewModel: MovieDetailsViewModel
    let onPlay: () -> Void

    @Environment(\.dismiss) private var dismiss

    init(repository: IPTVRepository, playlist: Playlist, movie: Stream, onPlay: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: MovieDetailsViewModel(
            repository: repository,
            playlist: playlist,
            movie: movie
        ))
        self.onPlay = onPlay
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                movieBackdrop
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()

                LinearGradient(
                    colors: [
                        Color.black.opacity(0.85),
                        Color.black.opacity(0.5),
                        Color.black.opacity(0.1)
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )

                // Content
                VStack(alignment: .leading, spacing: 16) {
                    Spacer()

                    // Title
                    Text(viewModel.movie.title.isEmpty ? "Title unavailable" : viewModel.movie.title)
                        .font(.system(size: 58, weight: .bold, design: .rounded))
                        .lineLimit(2)
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.8), radius: 12, y: 4)

                    // Metadata badges
                    metadataBadgesRow

                    // Synopsis
                    if viewModel.isEnriching && viewModel.displaySynopsis == nil {
                        ProgressView()
                            .tint(.white)
                    } else if let synopsis = viewModel.displaySynopsis, !synopsis.isEmpty {
                        Text(synopsis)
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.95))
                            .lineLimit(5)
                            .frame(maxWidth: 800, alignment: .leading)
                            .shadow(color: .black.opacity(0.6), radius: 6, y: 2)
                    }

                    // Play button
                    Button {
                        onPlay()
                    } label: {
                        Label("Play", systemImage: "play.fill")
                            .font(.title3.weight(.semibold))
                            .padding(.horizontal, 28)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.white)
                    .foregroundStyle(.black)
                    .shadow(color: .black.opacity(0.4), radius: 8, y: 2)

                    // Director & Cast
                    directorAndCastRow
                }
                .frame(maxWidth: 900, alignment: .leading)
                .padding(.leading, 80)
                .padding(.bottom, 80)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .bottomLeading)

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
                        .buttonStyle(.plain)
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
            await viewModel.enrichIfNeeded()
        }
    }

    // MARK: - Backdrop

    @ViewBuilder
    private var movieBackdrop: some View {
        let urlString = (viewModel.movie.backdropURL ?? viewModel.movie.logoURL)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
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

    // MARK: - Metadata Badges

    @ViewBuilder
    private var metadataBadgesRow: some View {
        let items = metadataBadgeItems
        if !items.isEmpty {
            HStack(spacing: 10) {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .foregroundStyle(.white.opacity(0.95))
                }
            }
            .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
        }
    }

    private var metadataBadgeItems: [String] {
        var items: [String] = []
        if let genre = viewModel.displayGenre, !genre.isEmpty {
            for g in genre.split(separator: ",").map({ $0.trimmingCharacters(in: .whitespaces) }) {
                if !g.isEmpty { items.append(g) }
            }
        }
        if let year = viewModel.displayYear, !year.isEmpty {
            items.append(year)
        }
        if let duration = viewModel.displayDuration, !duration.isEmpty {
            items.append(duration)
        }
        return items
    }

    // MARK: - Director & Cast

    @ViewBuilder
    private var directorAndCastRow: some View {
        if viewModel.displayDirector != nil || viewModel.displayCast != nil {
            VStack(alignment: .leading, spacing: 6) {
                if let director = viewModel.displayDirector {
                    Text("Director: \(director)")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }
                if let cast = viewModel.displayCast {
                    Text("Cast: \(cast)")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: 800, alignment: .leading)
            .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
        }
    }

    // MARK: - Fallback

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
}


