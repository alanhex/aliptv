import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case url
        case username
        case password
        case login
    }

    // Formulaire de connexion compatible Siri Remote
    var body: some View {
        VStack(spacing: 24) {
            Text("Connexion Xtream")
                .font(.largeTitle)
                .bold()

            VStack(spacing: 16) {
                TextField("URL du serveur", text: $authViewModel.baseURLString)
                    .textContentType(.URL)
                    .focused($focusedField, equals: .url)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.08))
                    )

                TextField("Nom d'utilisateur", text: $authViewModel.username)
                    .textContentType(.username)
                    .focused($focusedField, equals: .username)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.08))
                    )

                SecureField("Mot de passe", text: $authViewModel.password)
                    .focused($focusedField, equals: .password)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.08))
                    )
            }
            .padding(.horizontal, 80)

            Button {
                Task { await authViewModel.login() }
            } label: {
                Text(authViewModel.isLoading ? "Connexion..." : "Se connecter")
                    .frame(maxWidth: 320)
            }
            .buttonStyle(.borderedProminent)
            .focused($focusedField, equals: .login)
            .disabled(authViewModel.isLoading)

            if let errorMessage = authViewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(60)
        .onAppear {
            focusedField = .url
        }
    }
}
