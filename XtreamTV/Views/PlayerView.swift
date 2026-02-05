import SwiftUI
import AVKit

struct PlayerView: View {
    let stream: Stream
    let streamURL: URL

    @StateObject private var viewModel: PlayerViewModel

    init(stream: Stream, streamURL: URL) {
        self.stream = stream
        self.streamURL = streamURL
        _viewModel = StateObject(wrappedValue: PlayerViewModel(streamURL: streamURL))
    }

    // Lecteur plein écran du flux .m3u8
    var body: some View {
        ZStack(alignment: .topLeading) {
            VideoPlayer(player: viewModel.player)
                .edgesIgnoringSafeArea(.all)

            Text(stream.name)
                .font(.title3)
                .bold()
                .padding(16)
                .background(.black.opacity(0.4))
                .cornerRadius(12)
                .padding(24)

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.headline)
                    .foregroundStyle(.red)
                    .padding(16)
                    .background(.black.opacity(0.6))
                    .cornerRadius(12)
                    .padding(.top, 80)
                    .padding(.leading, 24)
            }
        }
        .onAppear {
            viewModel.play()
        }
        .onDisappear {
            viewModel.stop()
        }
    }
}
