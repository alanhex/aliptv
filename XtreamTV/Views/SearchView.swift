import SwiftUI

struct SearchView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recherche")
                .font(.largeTitle)
                .bold()
            Text("La recherche globale arrive bientôt.")
                .foregroundStyle(.secondary)
        }
        .padding(60)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
