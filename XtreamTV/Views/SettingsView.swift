import SwiftUI
import SwiftData

struct SettingsView: View {
    private enum SettingsSubmenu: String, CaseIterable, Identifiable {
        case playlists
        case playbackEngine

        var id: String { rawValue }

        var title: String {
            switch self {
            case .playlists: return "Playlists"
            case .playbackEngine: return "Playback Engine"
            }
        }

        var icon: String {
            switch self {
            case .playlists: return "list.bullet.rectangle"
            case .playbackEngine: return "play.rectangle"
            }
        }
    }

    @EnvironmentObject private var repository: IPTVRepository
    @Query(sort: [SortDescriptor(\Playlist.name, order: .forward)]) private var playlists: [Playlist]
    @AppStorage("playback.engine") private var playbackEngineRaw = PlaybackEngine.automatic.rawValue

    @State private var authViewModel: AuthViewModel?
    @State private var selectedSubmenu: SettingsSubmenu = .playlists
    @State private var playlistToDelete: Playlist?
    @State private var editingPlaylist: Playlist?
    @State private var isPresentingForm = false
    @State private var showReloadSuccess = false
    @State private var reloadSuccessMessage = ""
    @FocusState private var focusedSubmenu: SettingsSubmenu?
    @State private var didPrimeFocus = false

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Settings")
                    .font(.largeTitle.bold())

                HStack(spacing: 20) {
                    submenuPane

                    Divider()

                    contentPane
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .focusSection()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .allowsHitTesting(!isReloading)

            if isReloading {
                reloadProgressOverlay
            }
        }
        .sheet(isPresented: $isPresentingForm) {
            PlaylistFormView(editingPlaylist: editingPlaylist)
                .environmentObject(repository)
        }
        .alert("Delete playlist?", isPresented: Binding(get: {
            playlistToDelete != nil
        }, set: { value in
            if !value {
                playlistToDelete = nil
            }
        })) {
            Button("Delete", role: .destructive) {
                if let playlistToDelete {
                    _ = authViewModel?.delete(playlistToDelete)
                }
                self.playlistToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                playlistToDelete = nil
            }
        } message: {
            Text("This action clears all cached data for this playlist.")
        }
        .alert("Reload Complete", isPresented: $showReloadSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(reloadSuccessMessage)
        }
        .onAppear {
            if authViewModel == nil {
                authViewModel = AuthViewModel(repository: repository)
            }
            if !didPrimeFocus {
                didPrimeFocus = true
                DispatchQueue.main.async {
                    focusedSubmenu = selectedSubmenu
                }
            }
        }
        .onChange(of: selectedSubmenu) { _, newValue in
            focusedSubmenu = newValue
        }
        .onChange(of: isPresentingForm) { _, isPresented in
            if !isPresented {
                DispatchQueue.main.async {
                    focusedSubmenu = selectedSubmenu
                }
            }
        }
    }

    private var submenuPane: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(SettingsSubmenu.allCases) { submenu in
                Button {
                    selectedSubmenu = submenu
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: submenu.icon)
                            .frame(width: 20)
                        Text(submenu.title)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                    .background(
                        selectedSubmenu == submenu || focusedSubmenu == submenu
                            ? Color.accentColor.opacity(focusedSubmenu == submenu ? 0.33 : 0.25)
                            : Color.white.opacity(0.02)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .focused($focusedSubmenu, equals: submenu)
            }
            Spacer()
        }
        .frame(width: 280)
        .focusSection()
    }

    @ViewBuilder
    private var contentPane: some View {
        switch selectedSubmenu {
        case .playlists:
            playlistsPane
        case .playbackEngine:
            playbackEnginePane
        }
    }

    private var playlistsPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Playlists")
                        .font(.title2.bold())
                    Text("Manage credentials, reload cache, and keep your sources up to date.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    editingPlaylist = nil
                    isPresentingForm = true
                } label: {
                    Label("Add Playlist", systemImage: "plus.circle.fill")
                        .lineLimit(1)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isReloading)
            }

            if let authViewModel, let error = authViewModel.validationError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(error)
                        .lineLimit(2)
                }
                .foregroundStyle(.red)
            }

            if playlists.isEmpty {
                ContentUnavailableView(
                    "No playlists",
                    systemImage: "tray",
                    description: Text("Add a playlist to start browsing Live TV, Movies, and Series.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        ForEach(playlists) { playlist in
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(playlist.name)
                                            .font(.headline)
                                            .lineLimit(1)
                                        Text(playlist.baseURL)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }

                                    Spacer()

                                    Button {
                                        Task {
                                            let success = await authViewModel?.reload(playlist) ?? false
                                            if success {
                                                reloadSuccessMessage = "\"\(playlist.name)\" reloaded successfully."
                                                showReloadSuccess = true
                                            }
                                        }
                                    } label: {
                                        HStack(spacing: 8) {
                                            if authViewModel?.isReloadingPlaylistID == playlist.id {
                                                ProgressView()
                                            } else {
                                                Image(systemName: "arrow.clockwise")
                                            }
                                            Text("Reload")
                                                .lineLimit(1)
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(isReloading)

                                    Button("Edit") {
                                        editingPlaylist = playlist
                                        isPresentingForm = true
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(isReloading)

                                    Button(role: .destructive) {
                                        playlistToDelete = playlist
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                            .lineLimit(1)
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(isReloading)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.white.opacity(0.06))
                            )
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
    }

    private var playbackEnginePane: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Playback Engine")
                .font(.title2.bold())

            Text("Choose a specific player engine or keep Automatic.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            List(PlaybackEngine.allCases) { engine in
                Button {
                    guard engine.isAvailableInBuild || engine == .automatic || engine == .avkit else { return }
                    playbackEngineRaw = engine.rawValue
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: selectedPlaybackEngine == engine ? "largecircle.fill.circle" : "circle")
                            .foregroundStyle(selectedPlaybackEngine == engine ? Color.accentColor : Color.secondary)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(engine.displayName)
                                .lineLimit(1)
                            if !engine.isAvailableInBuild && engine != .automatic && engine != .avkit {
                                Text("Not linked in this build.")
                                    .font(.footnote)
                                    .foregroundStyle(.orange.opacity(0.9))
                                    .lineLimit(2)
                            }
                        }
                        Spacer()
                        Text(engine.isAvailableInBuild || engine == .automatic || engine == .avkit ? "Available" : "Not linked")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(engine.isAvailableInBuild || engine == .automatic || engine == .avkit ? .green : .orange)
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .disabled(!engine.isAvailableInBuild && engine != .automatic && engine != .avkit)
            }
            .listStyle(.plain)
        }
    }

    private var isReloading: Bool {
        authViewModel?.isReloadingPlaylistID != nil
    }

    private var selectedPlaybackEngine: PlaybackEngine {
        PlaybackEngine(rawValue: playbackEngineRaw) ?? .automatic
    }

    private var reloadProgress: Double {
        let steps = PlaylistValidationStep.allCases
        guard let step = repository.currentValidationStep else { return 0.05 }
        guard let index = steps.firstIndex(of: step) else { return 0.05 }
        return Double(index + 1) / Double(steps.count)
    }

    private var reloadProgressOverlay: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Reloading Playlist")
                .font(.title2.bold())
                .lineLimit(1)

            if let playlistName = reloadingPlaylistName {
                Text(playlistName)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            ProgressView(value: reloadProgress, total: 1.0)
                .progressViewStyle(.linear)

            ForEach(PlaylistValidationStep.allCases) { step in
                HStack(spacing: 10) {
                    Image(systemName: iconName(for: step))
                        .foregroundStyle(iconColor(for: step))
                    Text(step.displayName)
                    Spacer()
                }
                .font(.subheadline)
            }
        }
        .padding(24)
        .frame(width: 560)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 24, x: 0, y: 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.36).ignoresSafeArea())
    }

    private var reloadingPlaylistName: String? {
        guard let reloadingID = authViewModel?.isReloadingPlaylistID else { return nil }
        return playlists.first(where: { $0.id == reloadingID })?.name
    }

    private func iconName(for step: PlaylistValidationStep) -> String {
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

    private func iconColor(for step: PlaylistValidationStep) -> Color {
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
}
