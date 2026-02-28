import AVKit
import SwiftUI
#if canImport(KSPlayer)
import KSPlayer
#endif

struct PlayerView: View {
    let playable: PlayableItem
    @ObservedObject var viewModel: PlayerViewModel
    @AppStorage("playback.engine") private var playbackEngineRaw = PlaybackEngine.automatic.rawValue

    private var preferredEngine: PlaybackEngine {
        PlaybackEngine(rawValue: playbackEngineRaw) ?? .automatic
    }

    private var resolvedEngine: PlaybackEngine {
        PlaybackEngineResolver.resolve(preferred: preferredEngine, playable: playable)
    }

    private var displayEngine: PlaybackEngine {
        viewModel.activeEngine == .automatic ? resolvedEngine : viewModel.activeEngine
    }

    var body: some View {
        ZStack {
            playerSurface

            if let playbackError = viewModel.playbackError {
                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.currentTitle)
                        .font(.headline)
                        .lineLimit(1)
                    Text(playbackError)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.top, 26)
                .padding(.leading, 34)
            }

            VStack {
                HStack {
                    Spacer()
                    Text(engineBadgeText)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                .padding(.top, 28)
                .padding(.trailing, 34)
                Spacer()
            }
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            viewModel.play(
                playable,
                preferredEngine: preferredEngine,
                resolvedEngine: resolvedEngine
            )
        }
        .onDisappear {
            viewModel.stop()
        }
    }

    private var engineBadgeText: String {
        if preferredEngine == .automatic {
            return "Engine: \(displayEngine.displayName)"
        }
        if preferredEngine == displayEngine {
            return "Engine: \(preferredEngine.displayName)"
        }
        return "Engine: AVKit fallback (\(preferredEngine.displayName) unavailable or failed)"
    }

    @ViewBuilder
    private var playerSurface: some View {
        if usesKSPlayerSurface(displayEngine) {
            ksPlayerSurface
        } else {
            TVFullscreenPlayerController(player: viewModel.player)
                .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var ksPlayerSurface: some View {
        #if canImport(KSPlayer)
        if let playbackURL = viewModel.activePlaybackURL {
            TVKSPlayerContainer(url: playbackURL, title: playable.title) { reason in
                viewModel.fallbackFromExternalEngine(for: playable, failedEngine: resolvedEngine, reason: reason)
            }
                .id(playbackURL.absoluteString)
        } else {
            Color.black.ignoresSafeArea()
        }
        #else
        TVFullscreenPlayerController(player: viewModel.player)
            .ignoresSafeArea()
        #endif
    }

    private func usesKSPlayerSurface(_ engine: PlaybackEngine) -> Bool {
        switch engine {
        case .ksplayer, .mpv, .vlckit:
            return true
        case .automatic, .avkit:
            return false
        }
    }
}

private struct TVFullscreenPlayerController: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        if uiViewController.player !== player {
            uiViewController.player = player
        }
    }
}

#if canImport(KSPlayer)
@available(tvOS 16.0, *)
private struct TVKSPlayerContainer: View {
    let url: URL
    let title: String
    let onFailure: (String) -> Void

    @StateObject private var coordinator = KSVideoPlayer.Coordinator()
    @State private var watchdogID = UUID()
    @State private var hasBecomePlayable = false
    @State private var hasReportedFailure = false
    @State private var statePollTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            KSVideoPlayerView(
                coordinator: coordinator,
                url: url,
                options: configuredOptions,
                title: title
            )
                .ignoresSafeArea()

            if !hasBecomePlayable {
                ProgressView("Loading stream...")
                    .padding(12)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .onAppear {
            resetWatchdog()
            startStatePolling()
        }
        .onChange(of: url) { _, _ in
            resetWatchdog()
            startStatePolling()
        }
        .onDisappear {
            watchdogID = UUID()
            statePollTask?.cancel()
            statePollTask = nil
        }
    }

    private var configuredOptions: KSOptions {
        let options = KSOptions()
        // Balance compatibility and 4K performance.
        options.isSecondOpen = false
        options.autoDeInterlace = false
        options.hardwareDecode = true
        options.asynchronousDecompression = false
        options.videoAdaptable = false
        options.maxBufferDuration = 25
        return options
    }

    private func resetWatchdog() {
        hasBecomePlayable = false
        hasReportedFailure = false

        let id = UUID()
        watchdogID = id
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 12_000_000_000)
            guard watchdogID == id else { return }
            guard !hasBecomePlayable else { return }
            reportFailure("External player timed out while opening this stream.")
        }
    }

    private func startStatePolling() {
        statePollTask?.cancel()
        statePollTask = Task { @MainActor in
            while !Task.isCancelled {
                switch coordinator.state {
                case .readyToPlay, .bufferFinished:
                    hasBecomePlayable = true
                case .error:
                    reportFailure("External player reported a decoding/playback error.")
                    return
                default:
                    break
                }
                try? await Task.sleep(nanoseconds: 350_000_000)
            }
        }
    }

    private func reportFailure(_ reason: String) {
        guard !hasReportedFailure else { return }
        hasReportedFailure = true
        onFailure(reason)
    }
}
#endif
