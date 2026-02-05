import SwiftUI
import SwiftData

struct PlaylistFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let playlist: Playlist?

    @State private var name: String = ""
    @State private var baseURL: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var errorMessage: String?

    init(playlist: Playlist? = nil) {
        self.playlist = playlist
    }

    var body: some View {
        VStack(spacing: 24) {
            Text(playlist == nil ? "Nouvelle liste" : "Modifier la liste")
                .font(.largeTitle)
                .bold()

            PlaylistFormFields(
                name: $name,
                baseURL: $baseURL,
                username: $username,
                password: $password
            )
            .padding(.horizontal, 80)

            HStack(spacing: 16) {
                Button("Annuler") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button(playlist == nil ? "Ajouter" : "Enregistrer") {
                    save()
                }
                .buttonStyle(.borderedProminent)
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(60)
        .onAppear {
            if let playlist {
                name = playlist.name
                baseURL = playlist.baseURL
                username = playlist.username
                password = playlist.password
            }
        }
    }

    private func save() {
        errorMessage = nil
        guard !name.isEmpty, !baseURL.isEmpty, !username.isEmpty, !password.isEmpty else {
            errorMessage = "Tous les champs sont obligatoires."
            return
        }

        if let playlist {
            playlist.name = name
            playlist.baseURL = baseURL
            playlist.username = username
            playlist.password = password
        } else {
            let newPlaylist = Playlist(name: name, baseURL: baseURL, username: username, password: password)
            modelContext.insert(newPlaylist)
        }

        dismiss()
    }
}

struct PlaylistFormFields: View {
    @Binding var name: String
    @Binding var baseURL: String
    @Binding var username: String
    @Binding var password: String

    var body: some View {
        VStack(spacing: 16) {
            TextField("Nom de la liste", text: $name)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)
                .tvFieldStyle()

            TextField("URL du serveur", text: $baseURL)
                .textContentType(.URL)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .tvFieldStyle()

            TextField("Nom d'utilisateur", text: $username)
                .textContentType(.username)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .tvFieldStyle()

            SecureField("Mot de passe", text: $password)
                .tvFieldStyle()
        }
    }
}

private extension View {
    func tvFieldStyle() -> some View {
        padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.08))
            )
    }
}
