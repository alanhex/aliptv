import AVKit
import Combine
import Foundation

@MainActor
final class PlayerViewModel: ObservableObject {
    @Published var player = AVPlayer()
    @Published var currentTitle: String = ""
    @Published var playbackError: String?
    @Published var activePlaybackURL: URL?
    @Published var activeEngine: PlaybackEngine = .automatic

    private var statusObservation: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?
    private var candidateURLs: [URL] = []
    private var currentCandidateIndex = 0
    private var isAdvancingCandidate = false
    private var originalExtension: String?
    private var hasUnsupportedOriginalContainer = false
    private var preferredEngine: PlaybackEngine = .automatic
    private var resolvedEngine: PlaybackEngine = .avkit
    private var currentPlayable: PlayableItem?
    private var hasAttemptedExternalFallback = false

    func play(
        _ item: PlayableItem,
        preferredEngine: PlaybackEngine,
        resolvedEngine: PlaybackEngine,
        resetFallbackState: Bool = true
    ) {
        playbackError = nil
        currentTitle = item.title
        currentPlayable = item
        if resetFallbackState {
            hasAttemptedExternalFallback = false
        }
        self.preferredEngine = preferredEngine
        self.resolvedEngine = resolvedEngine
        activeEngine = resolvedEngine
        originalExtension = pathExtension(in: item.streamURL)
        if let originalExtension {
            hasUnsupportedOriginalContainer = !isLikelyPlayableExtension(originalExtension, for: item.mediaType)
        } else {
            hasUnsupportedOriginalContainer = false
        }

        candidateURLs = candidatePlaybackURLs(for: item, engine: resolvedEngine)
        currentCandidateIndex = 0
        activePlaybackURL = candidateURLs.first
        if candidateURLs.isEmpty {
            originalExtension = nil
            hasUnsupportedOriginalContainer = false
        }

        guard !candidateURLs.isEmpty else {
            playbackError = "Invalid playback URL."
            return
        }

        if usesExternalPlayer(resolvedEngine) {
            clearObservers()
            player.pause()
            player.replaceCurrentItem(with: nil)
            return
        }

        attemptPlaybackCurrentCandidate()
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        activePlaybackURL = nil
        activeEngine = .automatic
        candidateURLs = []
        currentCandidateIndex = 0
        isAdvancingCandidate = false
        originalExtension = nil
        hasUnsupportedOriginalContainer = false
        currentPlayable = nil
        hasAttemptedExternalFallback = false
        clearObservers()
    }

    func fallbackFromExternalEngine(for item: PlayableItem, failedEngine: PlaybackEngine, reason: String) {
        guard activeEngine != .avkit else { return }
        hasAttemptedExternalFallback = true
        playbackError = "External engine \(failedEngine.displayName) failed. Falling back to AVKit."
        play(item, preferredEngine: .avkit, resolvedEngine: .avkit, resetFallbackState: false)
        if playbackError == nil {
            playbackError = reason
        }
    }

    deinit {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
    }

    private func clearObservers() {
        statusObservation = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
    }

    private func attemptPlaybackCurrentCandidate() {
        guard currentCandidateIndex < candidateURLs.count else {
            playbackError = "Cannot open this stream."
            return
        }

        let playbackURL = candidateURLs[currentCandidateIndex]
        activePlaybackURL = playbackURL
        let playerItem = AVPlayerItem(url: playbackURL)
        observe(playerItem)
        player.replaceCurrentItem(with: playerItem)
        player.play()
    }

    private func observe(_ item: AVPlayerItem) {
        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor in
                guard let self else { return }
                guard self.player.currentItem === item else { return }
                if item.status == .failed {
                    self.handlePlaybackFailure(item.error?.localizedDescription ?? "Playback failed.")
                } else if item.status == .readyToPlay {
                    self.playbackError = nil
                }
            }
        }

        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] notification in
            let nsError = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? NSError
            Task { @MainActor in
                guard let self else { return }
                guard self.player.currentItem === item else { return }
                self.handlePlaybackFailure(nsError?.localizedDescription ?? "Playback interrupted.")
            }
        }
    }

    private func handlePlaybackFailure(_ message: String) {
        guard !isAdvancingCandidate else { return }

        let nextIndex = currentCandidateIndex + 1
        guard nextIndex < candidateURLs.count else {
            if attemptExternalFallback(after: message) {
                return
            }
            playbackError = mappedFinalPlaybackError(from: message)
            return
        }

        isAdvancingCandidate = true
        currentCandidateIndex = nextIndex
        attemptPlaybackCurrentCandidate()
        isAdvancingCandidate = false
    }

    private func candidatePlaybackURLs(for item: PlayableItem, engine: PlaybackEngine) -> [URL] {
        let trimmed = item.streamURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        if usesExternalPlayer(engine) {
            guard let url = URL(string: trimmed) else { return [] }
            return [url]
        }

        let originalExtension = pathExtension(in: trimmed)
        let originalSeemsPlayable = originalExtension.map { isLikelyPlayableExtension($0, for: item.mediaType) } ?? true

        var candidates: [String] = []
        candidates.append(trimmed)

        let alternateExtensions = alternateExtensions(for: item.mediaType)

        for ext in alternateExtensions {
            if let alternative = replacingPathExtension(in: trimmed, with: ext) {
                candidates.append(alternative)
            }
        }

        if !originalSeemsPlayable {
            let preferredFirst = ["m3u8", "mp4", "ts", "m4v", "mov"]
            candidates.sort { lhs, rhs in
                let lhsExt = pathExtension(in: lhs) ?? ""
                let rhsExt = pathExtension(in: rhs) ?? ""
                let lhsScore = preferredFirst.firstIndex(of: lhsExt) ?? Int.max
                let rhsScore = preferredFirst.firstIndex(of: rhsExt) ?? Int.max
                return lhsScore < rhsScore
            }
        }

        let unique = Array(NSOrderedSet(array: candidates).compactMap { $0 as? String })
        return unique.compactMap(URL.init(string:))
    }

    private func alternateExtensions(for mediaType: MediaType) -> [String] {
        switch mediaType {
        case .live:
            return []
        case .movie, .series:
            return ["m3u8", "mp4", "ts", "m4v", "mov", "mkv", "avi"]
        }
    }

    private func replacingPathExtension(in rawURL: String, with extensionValue: String) -> String? {
        guard var components = URLComponents(string: rawURL) else { return nil }
        let currentPath = components.path
        guard !currentPath.isEmpty else { return nil }

        let nsPath = currentPath as NSString
        let currentExt = nsPath.pathExtension.lowercased()
        let newExt = extensionValue.lowercased()

        var basePath = nsPath.deletingPathExtension
        if currentExt.isEmpty {
            basePath = currentPath
        }

        let nextPath = "\(basePath).\(newExt)"
        guard nextPath != currentPath else { return nil }

        components.path = nextPath
        return components.url?.absoluteString
    }

    private func pathExtension(in rawURL: String) -> String? {
        guard let components = URLComponents(string: rawURL) else { return nil }
        let ext = (components.path as NSString).pathExtension.lowercased()
        return ext.isEmpty ? nil : ext
    }

    private func attemptExternalFallback(after rawMessage: String) -> Bool {
        guard activeEngine == .avkit else { return false }
        guard !hasAttemptedExternalFallback else { return false }
        guard preferredEngine == .automatic || preferredEngine == .avkit else { return false }
        guard let item = currentPlayable else { return false }
        guard let fallbackEngine = preferredExternalEngine() else { return false }

        hasAttemptedExternalFallback = true
        let reason = mappedFinalPlaybackError(from: rawMessage)
        playbackError = "\(reason) Retrying with \(fallbackEngine.displayName)."
        play(item, preferredEngine: fallbackEngine, resolvedEngine: fallbackEngine, resetFallbackState: false)
        return true
    }

    private func preferredExternalEngine() -> PlaybackEngine? {
        let candidates: [PlaybackEngine] = [.ksplayer, .vlckit, .mpv]
        for engine in candidates where engine.isAvailableInBuild {
            return engine
        }
        return nil
    }

    private func isLikelyPlayableExtension(_ ext: String, for mediaType: MediaType) -> Bool {
        switch mediaType {
        case .live:
            return ["m3u8", "ts"].contains(ext)
        case .movie, .series:
            return ["m3u8", "mp4", "ts", "m4v", "mov"].contains(ext)
        }
    }

    private func mappedFinalPlaybackError(from rawMessage: String) -> String {
        let lowered = rawMessage.lowercased()

        if lowered.contains("resource unavailable") || lowered.contains("404") || lowered.contains("403") {
            if hasUnsupportedOriginalContainer, let originalExtension {
                return "Provider resource unavailable. Original stream is .\(originalExtension). \(engineSuggestionSuffix())"
            }
            return "Provider resource unavailable for this stream."
        }

        if lowered.contains("cannot open") || lowered.contains("failed") {
            if hasUnsupportedOriginalContainer, let originalExtension {
                return "Stream format .\(originalExtension) is likely unsupported by tvOS AVPlayer (container/codec issue). \(engineSuggestionSuffix())"
            }
            return "Cannot open stream. The codec/container may be unsupported on tvOS. \(engineSuggestionSuffix())"
        }

        if hasUnsupportedOriginalContainer, let originalExtension {
            return "Playback failed. Original stream .\(originalExtension) is likely unsupported by tvOS AVPlayer. \(engineSuggestionSuffix())"
        }

        return rawMessage
    }

    private func engineSuggestionSuffix() -> String {
        if resolvedEngine != .avkit {
            return "Current resolved engine: \(resolvedEngine.displayName)."
        }

        if preferredEngine == .automatic {
            return "Link KSPlayer/VLCKit/MPV to improve codec support."
        }

        if preferredEngine.isAvailableInBuild {
            return "Try Automatic mode in Settings."
        }

        return "\(preferredEngine.displayName) is not linked in this build. Link it or switch to Automatic."
    }

    private func usesExternalPlayer(_ engine: PlaybackEngine) -> Bool {
        switch engine {
        case .ksplayer, .mpv, .vlckit:
            return true
        case .automatic, .avkit:
            return false
        }
    }
}
