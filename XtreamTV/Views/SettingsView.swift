import SwiftUI

struct SettingsView: View {
    @State private var selectedSection: SettingsSection = .playlists
    @State private var selectedPlaylist: Playlist?

    var body: some View {
        HStack(alignment: .top, spacing: 40) {
            Group {
                switch selectedSection {
                case .playlists:
                    PlaylistsView(selectedPlaylist: $selectedPlaylist)
                case .player:
                    SettingsPlaceholderView(title: "Lecteur vidéo", subtitle: "Réglages du lecteur à venir.")
                case .epg:
                    SettingsPlaceholderView(title: "EPG", subtitle: "Préférences du guide TV à venir.")
                case .backup:
                    SettingsPlaceholderView(title: "Sauvegarde", subtitle: "Options de sauvegarde à venir.")
                case .recordingServer:
                    SettingsPlaceholderView(title: "Serveur d'enregistrements", subtitle: "Configuration à venir.")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            SettingsMenu(selectedSection: $selectedSection)
        }
        .padding(60)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private enum SettingsSection: String, CaseIterable, Identifiable {
    case playlists
    case player
    case epg
    case backup
    case recordingServer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .playlists: return "Playlists"
        case .player: return "Lecteur vidéo"
        case .epg: return "EPG"
        case .backup: return "Sauvegarde"
        case .recordingServer: return "Serveur d'enregistrements"
        }
    }

    var systemImage: String {
        switch self {
        case .playlists: return "list.bullet.rectangle"
        case .player: return "play.rectangle"
        case .epg: return "book.closed"
        case .backup: return "tray.and.arrow.down"
        case .recordingServer: return "externaldrive"
        }
    }
}

private struct SettingsMenu: View {
    @Binding var selectedSection: SettingsSection
    @FocusState private var focusedSection: SettingsSection?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Menu")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 6)

            ForEach(SettingsSection.allCases) { section in
                Button {
                    selectedSection = section
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: section.systemImage)
                            .frame(width: 28)
                        Text(section.title)
                            .font(.title3)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(selectedSection == section ? Color.primary.opacity(0.1) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
                .focused($focusedSection, equals: section)
            }

            Spacer()
        }
        .padding(18)
        .frame(width: 580)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.black.opacity(0.08))
        )
        .focusSection()
    }
}

private struct SettingsPlaceholderView: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.largeTitle)
                .bold()
            Text(subtitle)
                .foregroundStyle(.secondary)
        }
        .padding(60)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
