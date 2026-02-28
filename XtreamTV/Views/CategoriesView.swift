import SwiftUI

struct CategoriesView: View {
    let playlist: Playlist
    let mediaType: MediaType
    let onPlay: (PlayableItem) -> Void

    var body: some View {
        StreamListView(playlist: playlist, mediaType: mediaType, onPlay: onPlay)
    }
}
