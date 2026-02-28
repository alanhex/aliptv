import SwiftUI
import UIKit

struct PlaylistFormView: View {
    private enum FormField: Hashable {
        case name
        case baseURL
        case username
        case password
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var repository: IPTVRepository

    let editingPlaylist: Playlist?

    @State private var draft: PlaylistDraft
    @State private var viewModel: AuthViewModel?
    @FocusState private var focusedField: FormField?

    init(editingPlaylist: Playlist?) {
        self.editingPlaylist = editingPlaylist
        _draft = State(initialValue: editingPlaylist.map(PlaylistDraft.init(playlist:)) ?? PlaylistDraft())
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.11, blue: 0.14),
                    Color(red: 0.06, green: 0.07, blue: 0.09)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    statusCard
                    detailsCard
                    credentialsCard
                    endpointPreviewCard
                }
                .frame(maxWidth: 1040, alignment: .leading)
                .padding(.horizontal, 42)
                .padding(.vertical, 34)
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = AuthViewModel(repository: repository)
            }
            focusedField = .name
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(editingPlaylist == nil ? "Add Playlist" : "Edit Playlist")
                    .font(.system(size: 50, weight: .bold))
                    .lineLimit(1)

                Text("Provide Xtream Codes credentials. Validation will run before saving.")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 20)

            Button("Close") {
                dismiss()
            }
            .buttonStyle(.bordered)
            .tint(.gray)
            .disabled(isSaving)

            Button {
                Task { await savePlaylist() }
            } label: {
                HStack(spacing: 10) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                    }
                    Text(isSaving ? "Validating..." : "Save Playlist")
                        .lineLimit(1)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canSubmit || isSaving)
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            if isSaving || repository.currentValidationStep != nil {
                Text("Validation Progress")
                    .font(.title3.bold())

                ProgressView(value: validationProgress, total: 1.0)
                    .progressViewStyle(.linear)

                ForEach(PlaylistValidationStep.allCases) { step in
                    HStack(spacing: 10) {
                        Image(systemName: statusIcon(for: step))
                            .foregroundStyle(statusColor(for: step))
                        Text(step.displayName)
                            .lineLimit(1)
                        Spacer()
                    }
                    .font(.subheadline)
                }
            }

            if let error = viewModel?.validationError {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(18)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Playlist Details")
                .font(.title3.bold())
            Text("This name appears in the left sidebar.")
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                formField(
                    title: "Name",
                    placeholder: "e.g. Home IPTV",
                    text: $draft.name,
                    field: .name,
                    keyboardType: .default,
                    autocapitalization: .words,
                    isSecure: false
                )

                formField(
                    title: "Base URL",
                    placeholder: "https://provider.example.com",
                    text: $draft.baseURL,
                    field: .baseURL,
                    keyboardType: .URL,
                    autocapitalization: .never,
                    isSecure: false
                )
            }
        }
        .padding(18)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var credentialsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Credentials")
                .font(.title3.bold())
            Text("Used to authenticate against the Xtream API.")
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                formField(
                    title: "Username",
                    placeholder: "username",
                    text: $draft.username,
                    field: .username,
                    keyboardType: .default,
                    autocapitalization: .never,
                    isSecure: false
                )

                formField(
                    title: "Password",
                    placeholder: "password",
                    text: $draft.password,
                    field: .password,
                    keyboardType: .default,
                    autocapitalization: .never,
                    isSecure: true
                )
            }
        }
        .padding(18)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var endpointPreviewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Connection Preview")
                .font(.title3.bold())

            Text(previewEndpoint)
                .font(.footnote.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Text("Save runs: Authentication, Live TV fetch, Movies fetch, Series fetch.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private func formField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        field: FormField,
        keyboardType: UIKeyboardType,
        autocapitalization: TextInputAutocapitalization,
        isSecure: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)

            if isSecure {
                SecureField(placeholder, text: text)
                    .focused($focusedField, equals: field)
                    .textInputAutocapitalization(autocapitalization)
                    .autocorrectionDisabled(true)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .disabled(isSaving)
            } else {
                TextField(placeholder, text: text)
                    .focused($focusedField, equals: field)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(autocapitalization)
                    .autocorrectionDisabled(true)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .disabled(isSaving)
            }
        }
    }

    private var isSaving: Bool {
        viewModel?.isSaving ?? false
    }

    private var canSubmit: Bool {
        let cleaned = draft.trimmed()
        return !cleaned.name.isEmpty && !cleaned.baseURL.isEmpty && !cleaned.username.isEmpty && !cleaned.password.isEmpty
    }

    private var previewEndpoint: String {
        let cleaned = draft.trimmed()
        let base = cleaned.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if base.isEmpty {
            return "https://provider.example.com/player_api.php?username=<user>&password=<password>&action=get_live_streams"
        }
        return "\(base)/player_api.php?username=\(cleaned.username.isEmpty ? "<user>" : cleaned.username)&password=<password>&action=get_live_streams"
    }

    private var validationProgress: Double {
        let steps = PlaylistValidationStep.allCases
        guard let step = repository.currentValidationStep else { return 0.05 }
        guard let index = steps.firstIndex(of: step) else { return 0.05 }
        return Double(index + 1) / Double(steps.count)
    }

    private func statusIcon(for step: PlaylistValidationStep) -> String {
        guard let current = repository.currentValidationStep else { return "circle" }
        let steps = PlaylistValidationStep.allCases
        guard
            let currentIndex = steps.firstIndex(of: current),
            let stepIndex = steps.firstIndex(of: step)
        else {
            return "circle"
        }

        if stepIndex < currentIndex {
            return "checkmark.circle.fill"
        }
        if stepIndex == currentIndex {
            return "arrow.triangle.2.circlepath.circle.fill"
        }
        return "circle"
    }

    private func statusColor(for step: PlaylistValidationStep) -> Color {
        guard let current = repository.currentValidationStep else { return .secondary }
        let steps = PlaylistValidationStep.allCases
        guard
            let currentIndex = steps.firstIndex(of: current),
            let stepIndex = steps.firstIndex(of: step)
        else {
            return .secondary
        }

        if stepIndex < currentIndex {
            return .green
        }
        if stepIndex == currentIndex {
            return .accentColor
        }
        return .secondary
    }

    private func savePlaylist() async {
        let success = await viewModel?.savePlaylist(draft: draft, editing: editingPlaylist) ?? false
        if success {
            dismiss()
        }
    }
}
