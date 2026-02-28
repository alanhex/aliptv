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
    }

    private var header: some View {
        HStack {
            Text("\(playlist.name) · \(mediaType.displayName)")
                .font(.largeTitle.bold())
                .lineLimit(1)

            Spacer()

            if viewModel?.isRefreshing == true {
                ProgressView()
            }

            Button {
                guard let viewModel else { return }
                Task { await viewModel.refresh() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
    }

    private func categoryPane(viewModel: StreamListViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Categories")
                .font(.title3.bold())

            if mediaType == .movie {
                HStack(spacing: 10) {
                    quickChip("R")
                    quickChip("L")
                    quickChip("F")
                    quickChip("T")
                }
                .padding(.bottom, 4)
            }

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
        .frame(width: mediaType == .movie ? 304 : 332)
        .animation(.easeOut(duration: 0.2), value: moviePaneHasFocus)
    }

    private func quickChip(_ title: String) -> some View {
        Text(title)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.8)
            }
    }

    private func moviePane(viewModel: StreamListViewModel) -> some View {
        let selected = selectedMovie(in: viewModel)

        return VStack(alignment: .leading, spacing: 12) {
            if let selected {
                VStack(alignment: .leading, spacing: 6) {
                    Text(selected.title)
                        .font(.title2.bold())
                        .lineLimit(1)
                    if let details = streamBrowseDetails(selected), !details.isEmpty {
                        Text(details)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
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
                                onPlay(stream.asPlayable)
                            } label: {
                                MoviePosterTile(
                                    title: stream.title,
                                    posterURL: stream.logoURL,
                                    isSelected: selectedMovieKey == stream.cacheKey
                                )
                            }
                            .buttonStyle(.plain)
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
        moviePaneHasFocus ? 6 : 5
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
        if let rating = stream.rating?.trimmingCharacters(in: .whitespacesAndNewlines), !rating.isEmpty {
            parts.append("Rating: \(rating)")
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

private struct MoviePosterTile: View {
    let title: String
    let posterURL: String?
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            poster
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(isSelected ? Color.accentColor.opacity(0.85) : Color.white.opacity(0.08), lineWidth: isSelected ? 1.2 : 0.6)
                }
                .scaleEffect(isSelected ? 1.008 : 1)

            Text(title)
                .font(.headline)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .animation(.easeOut(duration: 0.16), value: isSelected)
    }

    @ViewBuilder
    private var poster: some View {
        if let posterURL,
           let url = URL(string: posterURL.trimmingCharacters(in: .whitespacesAndNewlines)),
           !posterURL.isEmpty {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    placeholder
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.white.opacity(0.08))
            .overlay {
                Image(systemName: "film")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
    }
}

