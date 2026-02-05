import SwiftUI

struct RecordingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Enregistrements")
                .font(.largeTitle)
                .bold()
            Text("Cette section sera disponible prochainement.")
                .foregroundStyle(.secondary)
        }
        .padding(60)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
