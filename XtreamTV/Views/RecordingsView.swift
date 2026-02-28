import SwiftUI

struct RecordingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Recordings")
                .font(.largeTitle.bold())

            ContentUnavailableView(
                "Feature in progress",
                systemImage: "record.circle",
                description: Text("DVR support depends on your provider. This section is ready for future backend integration.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
