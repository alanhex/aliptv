import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject private var repository: IPTVRepository

    let onPlay: (PlayableItem) -> Void

    @State private var favorites: [FavoriteItem] = []
    @State private var errorMessage: String?
    @State private var favoriteToDelete: FavoriteItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Favorites")
                .font(.largeTitle.bold())

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }

            if favorites.isEmpty {
                ContentUnavailableView("No favorites", systemImage: "star")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(favorites) { favorite in
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(favorite.title)
                                .font(.headline)
                                .lineLimit(1)
                            Text(favorite.mediaType.displayName)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Button("Play") {
                            onPlay(favorite.asPlayable)
                        }
                        .buttonStyle(.borderedProminent)

                        Button(role: .destructive) {
                            favoriteToDelete = favorite
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 6)
                }
                .listStyle(.plain)
            }
        }
        .onAppear(perform: loadFavorites)
        .alert("Delete favorite?", isPresented: Binding(get: {
            favoriteToDelete != nil
        }, set: { value in
            if !value {
                favoriteToDelete = nil
            }
        })) {
            Button("Delete", role: .destructive) {
                if let favoriteToDelete {
                    removeFavorite(favoriteToDelete)
                }
                favoriteToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                favoriteToDelete = nil
            }
        } message: {
            Text("This will remove the selected item from favorites.")
        }
    }

    private func loadFavorites() {
        do {
            favorites = try repository.favorites()
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func removeFavorite(_ favorite: FavoriteItem) {
        do {
            try repository.removeFavorite(favorite)
            loadFavorites()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
