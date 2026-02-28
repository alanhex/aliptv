import Foundation

enum MediaType: String, CaseIterable, Codable, Hashable {
    case live
    case movie
    case series

    var displayName: String {
        switch self {
        case .live:
            return String(localized: "media_type.live", defaultValue: "Live TV")
        case .movie:
            return String(localized: "media_type.movie", defaultValue: "Movies")
        case .series:
            return String(localized: "media_type.series", defaultValue: "Series")
        }
    }

    var xtreamActionCategories: String {
        switch self {
        case .live: return "get_live_categories"
        case .movie: return "get_vod_categories"
        case .series: return "get_series_categories"
        }
    }

    var xtreamActionStreams: String {
        switch self {
        case .live: return "get_live_streams"
        case .movie: return "get_vod_streams"
        case .series: return "get_series"
        }
    }
}

enum PlaybackEngine: String, CaseIterable, Identifiable {
    case automatic
    case avkit
    case mpv
    case vlckit
    case ksplayer

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .automatic:
            return "Automatic"
        case .avkit:
            return "AVKit (Native)"
        case .mpv:
            return "MPV (Experimental)"
        case .vlckit:
            return "VLCKit (OpenGL)"
        case .ksplayer:
            return "KSPlayer (Metal)"
        }
    }

    var isAvailableInBuild: Bool {
        switch self {
        case .automatic, .avkit:
            return true
        case .mpv:
            #if canImport(KSPlayer)
            return true
            #else
            return false
            #endif
        case .vlckit:
            #if canImport(KSPlayer) || canImport(MobileVLCKit) || canImport(VLCKit)
            return true
            #else
            return false
            #endif
        case .ksplayer:
            #if canImport(KSPlayer)
            return true
            #else
            return false
            #endif
        }
    }

    var availabilityLabel: String {
        if isAvailableInBuild {
            return displayName
        }
        if self == .automatic || self == .avkit {
            return displayName
        }
        return "\(displayName) (Not linked)"
    }
}

enum PlaybackEngineResolver {
    static func resolve(preferred: PlaybackEngine, playable: PlayableItem) -> PlaybackEngine {
        switch preferred {
        case .automatic:
            return automaticResolution(for: playable)
        case .avkit:
            return .avkit
        case .mpv, .vlckit, .ksplayer:
            return preferred.isAvailableInBuild ? preferred : .avkit
        }
    }

    private static func automaticResolution(for playable: PlayableItem) -> PlaybackEngine {
        if playable.mediaType != .live, looksLikeHighResolutionContent(title: playable.title) {
            if PlaybackEngine.ksplayer.isAvailableInBuild { return .ksplayer }
            if PlaybackEngine.vlckit.isAvailableInBuild { return .vlckit }
            if PlaybackEngine.mpv.isAvailableInBuild { return .mpv }
        }

        let ext = pathExtension(from: playable.streamURL)
        if let ext, isLikelyUnsupportedByAVKit(ext: ext, mediaType: playable.mediaType) {
            if PlaybackEngine.ksplayer.isAvailableInBuild { return .ksplayer }
            if PlaybackEngine.vlckit.isAvailableInBuild { return .vlckit }
            if PlaybackEngine.mpv.isAvailableInBuild { return .mpv }
        }
        return .avkit
    }

    private static func looksLikeHighResolutionContent(title: String) -> Bool {
        let normalized = title.lowercased()
        return normalized.contains("4k") || normalized.contains("2160") || normalized.contains("uhd")
    }

    private static func pathExtension(from rawURL: String) -> String? {
        guard let components = URLComponents(string: rawURL) else { return nil }
        let ext = (components.path as NSString).pathExtension.lowercased()
        return ext.isEmpty ? nil : ext
    }

    private static func isLikelyUnsupportedByAVKit(ext: String, mediaType: MediaType) -> Bool {
        switch mediaType {
        case .live:
            return !["m3u8", "ts"].contains(ext)
        case .movie, .series:
            return !["m3u8", "mp4", "ts", "m4v", "mov"].contains(ext)
        }
    }
}
