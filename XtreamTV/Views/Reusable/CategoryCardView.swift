import SwiftUI

struct CategoryCardView: View {
    let title: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.blue.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.blue.opacity(0.4), lineWidth: 2)
                )

            Text(title)
                .font(.title3)
                .bold()
                .multilineTextAlignment(.center)
                .padding(24)
        }
        .frame(height: 160)
    }
}
