import SwiftUI

struct OnboardingView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "tv.music.note")
                .font(.system(size: 72))
            Text("Welcome")
                .font(.largeTitle.bold())
            Text("Add an Xtream playlist to get started.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
