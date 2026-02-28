import SwiftUI

struct CategoryCardView: View {
    let category: Category
    var isSelected: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "square.grid.2x2")
                .frame(width: 20)
            Text(category.name)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(isSelected ? Color.accentColor.opacity(0.26) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contentShape(Rectangle())
    }
}
