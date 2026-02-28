import SwiftUI

struct LoginView: View {
    var body: some View {
        ContentUnavailableView(
            "Manual sign-in not required",
            systemImage: "person.badge.key",
            description: Text("Use Xtream playlist management in Settings.")
        )
    }
}
