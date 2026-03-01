import SwiftUI

struct PosterTile: View {
    let title: String
    let posterURL: String?
    let isFocused: Bool
    var systemImageFallback: String = "film"

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            poster
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(isFocused ? Color.white.opacity(0.95) : Color.white.opacity(0.08), lineWidth: isFocused ? 3 : 0.6)
                }

            Text(title)
                .font(.headline)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(isFocused ? Color.white : Color.white.opacity(0.9))
        }
        .animation(.easeOut(duration: 0.14), value: isFocused)
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
                Image(systemName: systemImageFallback)
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
    }
}
