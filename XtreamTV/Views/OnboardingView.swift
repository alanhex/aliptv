import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var name: String = ""
    @State private var baseURL: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var errorMessage: String?

    let onComplete: (Playlist) -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("Bienvenue")
                .font(.largeTitle)
                .bold()

            Text("Ajoutez votre première liste Xtream pour commencer.")
                .font(.title3)
                .foregroundStyle(.secondary)

            PlaylistFormFields(
                name: $name,
                baseURL: $baseURL,
                username: $username,
                password: $password
            )
            .padding(.horizontal, 80)

            Button("Créer la liste") {
                createPlaylist()
            }
            .buttonStyle(.borderedProminent)

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(60)
    }

    private func createPlaylist() {
        errorMessage = nil
        guard !name.isEmpty, !baseURL.isEmpty, !username.isEmpty, !password.isEmpty else {
            errorMessage = "Tous les champs sont obligatoires."
            return
        }
        let playlist = Playlist(name: name, baseURL: baseURL, username: username, password: password)
        modelContext.insert(playlist)
        onComplete(playlist)
    }
}
