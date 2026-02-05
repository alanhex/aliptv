import SwiftUI

struct StreamCardView: View {
    let stream: Stream

    var body: some View {
        VStack(spacing: 12) {
            if let icon = stream.streamIcon, let url = URL(string: icon) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFit()
                } placeholder: {
                    Color.gray.opacity(0.2)
                }
                .frame(height: 80)
            } else {
                Image(systemName: "tv")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.blue)
            }

            Text(stream.name)
                .font(.headline)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(16)
        .frame(height: 180)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.blue.opacity(0.15))
        )
    }
}
