import Foundation

public struct IPTVCredentials: Equatable, Sendable {
    public let baseURL: String
    public let username: String
    public let password: String

    public init(baseURL: String, username: String, password: String) {
        self.baseURL = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.username = username
        self.password = password
    }
}

public struct ParsedEpisode: Equatable, Sendable {
    public let id: String
    public let title: String
    public let season: Int
    public let number: Int
    public let streamURL: String
}

public enum EpisodeParserError: Error, Equatable {
    case invalidJSON
    case invalidRoot
}

public enum XtreamEpisodeParser {
    public static func parse(from data: Data, credentials: IPTVCredentials, fallbackSeriesID: String) throws -> [ParsedEpisode] {
        let jsonObject: Any
        do {
            jsonObject = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw EpisodeParserError.invalidJSON
        }

        guard let root = jsonObject as? [String: Any] else {
            throw EpisodeParserError.invalidRoot
        }

        return parseNode(root["episodes"], seasonHint: nil, credentials: credentials, fallbackSeriesID: fallbackSeriesID)
    }

    private static func parseNode(
        _ node: Any?,
        seasonHint: Int?,
        credentials: IPTVCredentials,
        fallbackSeriesID: String
    ) -> [ParsedEpisode] {
        guard let node else { return [] }

        if let dict = node as? [String: Any], looksLikeEpisode(dict) {
            return [makeEpisode(dict: dict, seasonHint: seasonHint, credentials: credentials, fallbackSeriesID: fallbackSeriesID)]
        }

        if let dict = node as? [String: Any] {
            return dict.flatMap { key, value in
                let nextSeason = Int(key) ?? seasonHint
                return parseNode(value, seasonHint: nextSeason, credentials: credentials, fallbackSeriesID: fallbackSeriesID)
            }
        }

        if let array = node as? [Any] {
            return array.flatMap { parseNode($0, seasonHint: seasonHint, credentials: credentials, fallbackSeriesID: fallbackSeriesID) }
        }

        return []
    }

    private static func looksLikeEpisode(_ dict: [String: Any]) -> Bool {
        dict["id"] != nil || dict["episode_num"] != nil || dict["stream_id"] != nil || dict["title"] != nil
    }

    private static func makeEpisode(
        dict: [String: Any],
        seasonHint: Int?,
        credentials: IPTVCredentials,
        fallbackSeriesID: String
    ) -> ParsedEpisode {
        let id = asString(dict["id"]) ?? asString(dict["stream_id"]) ?? fallbackSeriesID
        let season = asInt(dict["season"]) ?? seasonHint ?? 0
        let number = asInt(dict["episode_num"]) ?? asInt(dict["episode"]) ?? 0
        let title = asString(dict["title"]) ?? "S\(season) E\(number)"

        let ext = asString(dict["container_extension"]) ?? "mp4"
        let directSource = asString(dict["direct_source"])
        let streamURL = directSource ?? "\(credentials.baseURL)/series/\(credentials.username)/\(credentials.password)/\(id).\(ext)"

        return ParsedEpisode(id: id, title: title, season: season, number: number, streamURL: streamURL)
    }

    private static func asString(_ value: Any?) -> String? {
        switch value {
        case let value as String:
            return value
        case let value as Int:
            return String(value)
        case let value as Double:
            return String(value)
        case let value as NSNumber:
            return value.stringValue
        default:
            return nil
        }
    }

    private static func asInt(_ value: Any?) -> Int? {
        switch value {
        case let value as Int:
            return value
        case let value as String:
            return Int(value)
        case let value as Double:
            return Int(value)
        case let value as NSNumber:
            return value.intValue
        default:
            return nil
        }
    }
}
