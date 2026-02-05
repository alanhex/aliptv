import SwiftUI

struct SeriesCardView: View {
    let item: SeriesItem

    var body: some View {
        VStack(spacing: 12) {
            if let cover = item.cover, let url = URL(string: cover) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFit()
                } placeholder: {
                    Color.gray.opacity(0.2)
                }
                .frame(height: 100)
            } else {
                Image(systemName: "tv")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.blue)
            }

            Text(item.name)
                .font(.headline)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(16)
        .frame(height: 200)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.blue.opacity(0.15))
        )
    }
}
