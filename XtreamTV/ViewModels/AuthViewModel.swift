import Foundation
import SwiftUI

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var baseURLString: String = ""
    @Published var username: String = ""
    @Published var password: String = ""

    @Published private(set) var isAuthenticated: Bool = false
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String?

    private(set) var authResponse: AuthResponse?

    // Construit un client API à partir des champs saisis
    var client: XtreamAPIClient? {
        guard let url = URL(string: baseURLString) else { return nil }
        return XtreamAPIClient(baseURL: url, username: username, password: password)
    }

    // Tente l'authentification Xtream Codes
    func login() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        guard let client else {
            errorMessage = "URL invalide. Exemple: https://monserveur.com"
            return
        }

        do {
            let response = try await client.authenticate()
            authResponse = response
            isAuthenticated = response.userInfo.status.lowercased() == "active"
            if !isAuthenticated {
                errorMessage = "Compte inactif ou expiré."
            }
        } catch {
            errorMessage = "Échec de la connexion : \(error.localizedDescription)"
        }
    }

    // Réinitialise l'état de session
    func logout() {
        isAuthenticated = false
        authResponse = nil
        baseURLString = ""
        username = ""
        password = ""
        errorMessage = nil
    }
}
