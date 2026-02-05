import SwiftUI

struct PlaylistCardView: View {
    let playlist: Playlist

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(playlist.name)
                .font(.title3)
                .bold()

            Text(playlist.baseURL)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(playlist.username)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.blue.opacity(0.15))
        )
        .frame(height: 140)
    }
}
