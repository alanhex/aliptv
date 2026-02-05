import Foundation
import AVKit
import AVFoundation

@MainActor
final class PlayerViewModel: ObservableObject {
    @Published private(set) var player: AVPlayer
    @Published var errorMessage: String?

    private var statusObserver: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?

    init(streamURL: URL) {
        let item = AVPlayerItem(url: streamURL)
        self.player = AVPlayer(playerItem: item)

        // Observe l'état de l'item pour détecter les erreurs de décodage
        statusObserver = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            guard let self else { return }
            if item.status == .failed {
                Task { @MainActor in
                    self.errorMessage = item.error?.localizedDescription ?? "Erreur de lecture inconnue."
                }
            } else if item.status == .readyToPlay {
                // Vérifie la présence d'une piste vidéo
                Task {
                    do {
                        let videoTracks = try await item.asset.loadTracks(withMediaType: .video)
                        if videoTracks.isEmpty {
                            await MainActor.run {
                                self.errorMessage = "Flux sans piste vidéo détectée ou codec non supporté (simulateur)."
                            }
                        }
                    } catch {
                        await MainActor.run {
                            self.errorMessage = "Impossible d'inspecter le flux vidéo."
                        }
                    }
                }
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] notification in
            let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? NSError
            self?.errorMessage = error?.localizedDescription ?? "Lecture interrompue."
        }
    }

    // Lance la lecture du flux
    func play() {
        player.play()
    }

    // Stoppe la lecture
    func stop() {
        player.pause()
    }

    deinit {
        statusObserver?.invalidate()
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
    }
}
