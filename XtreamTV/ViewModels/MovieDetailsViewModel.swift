import Foundation

@MainActor
final class MovieDetailsViewModel: ObservableObject {
    @Published var isEnriching = false
    @Published var enrichmentFailed = false

    private let repository: IPTVRepository
    private let playlist: Playlist
    let movie: Stream

    init(repository: IPTVRepository, playlist: Playlist, movie: Stream) {
        self.repository = repository
        self.playlist = playlist
        self.movie = movie
    }

    func enrichIfNeeded() async {
        // Force re-enrichment if we have an old-style backdrop (not TMDb HD)
        let needsBackdropUpgrade = movie.enrichedAt != nil
            && (movie.backdropURL == nil || !(movie.backdropURL ?? "").contains("image.tmdb.org"))

        if !needsBackdropUpgrade, let enrichedAt = movie.enrichedAt {
            let age = Date.now.timeIntervalSince(enrichedAt)
            if age < 24 * 60 * 60 { return }
        }

        isEnriching = true
        enrichmentFailed = false

        do {
            try await repository.enrichVODInfo(playlist: playlist, stream: movie, force: needsBackdropUpgrade)
        } catch {
            enrichmentFailed = true
        }

        isEnriching = false
    }

    var displayBackdropURL: String? {
        movie.backdropURL ?? movie.logoURL
    }

    var displayDuration: String? {
        movie.duration
    }

    var displayDirector: String? {
        movie.director
    }

    var displayCast: String? {
        movie.cast
    }

    var displaySynopsis: String? {
        movie.synopsis?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var displayGenre: String? {
        movie.genre?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var displayYear: String? {
        movie.releaseYear?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var displayRating: String? {
        movie.rating?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
