import SwiftUI

struct CategoryCardView: View {
    let category: Category
    var isSelected: Bool = false
    var isFocused: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "square.grid.2x2")
                .frame(width: 20)
            Text(category.name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .foregroundStyle(isFocused ? Color.black.opacity(0.78) : Color.white.opacity(0.9))
        .background(backgroundColor)
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(isFocused ? 0.2 : 0.08), lineWidth: isFocused ? 0.7 : 0.5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var backgroundColor: Color {
        if isFocused {
            return Color.white.opacity(0.78)
        }
        return isSelected ? Color.white.opacity(0.14) : Color.white.opacity(0.06)
    }
}
