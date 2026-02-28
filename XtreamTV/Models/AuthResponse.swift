import Foundation

struct PlaylistCredentials: Equatable {
    let baseURL: String
    let username: String
    let password: String

    var normalizedBaseURL: String {
        baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    func replacingBaseURL(_ newBaseURL: String?) -> PlaylistCredentials {
        guard let newBaseURL, !newBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return self
        }
        return PlaylistCredentials(baseURL: newBaseURL, username: username, password: password)
    }
}

struct XtreamAuthentication: Decodable {
    let isAuthenticated: Bool
    let statusMessage: String?
    let playbackBaseURL: String?
    let allowedOutputFormats: [String]

    private enum CodingKeys: String, CodingKey {
        case userInfo = "user_info"
        case serverInfo = "server_info"
        case message
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let userInfo = try container.decodeIfPresent(XtreamUserInfo.self, forKey: .userInfo)
        let serverInfo = try container.decodeIfPresent(XtreamServerInfo.self, forKey: .serverInfo)
        isAuthenticated = userInfo?.auth == true
        statusMessage = try container.decodeIfPresent(String.self, forKey: .message)
        allowedOutputFormats = userInfo?.allowedOutputFormats ?? []
        playbackBaseURL = serverInfo?.resolvedBaseURL
    }
}

private struct XtreamUserInfo: Decodable {
    let auth: Bool
    let allowedOutputFormats: [String]

    private enum CodingKeys: String, CodingKey {
        case auth
        case allowedOutputFormats = "allowed_output_formats"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        auth = container.decodeFlexibleBool(forKey: .auth) ?? false
        allowedOutputFormats = (try? container.decode([String].self, forKey: .allowedOutputFormats)) ?? []
    }
}

private struct XtreamServerInfo: Decodable {
    let url: String?
    let port: String?
    let httpsPort: String?
    let serverProtocol: String?

    private enum CodingKeys: String, CodingKey {
        case url
        case port
        case httpsPort = "https_port"
        case serverProtocol = "server_protocol"
    }

    var resolvedBaseURL: String? {
        guard let rawURL = url?.trimmingCharacters(in: .whitespacesAndNewlines), !rawURL.isEmpty else {
            return nil
        }

        let proto = (serverProtocol?.lowercased() == "https") ? "https" : "http"
        let preferredPort = proto == "https" ? (httpsPort ?? port) : (port ?? httpsPort)
        let cleanedPort = preferredPort?.trimmingCharacters(in: .whitespacesAndNewlines)

        var base: String
        if rawURL.hasPrefix("http://") || rawURL.hasPrefix("https://") {
            base = rawURL
        } else {
            base = "\(proto)://\(rawURL)"
        }

        guard
            let cleanedPort,
            !cleanedPort.isEmpty,
            var components = URLComponents(string: base),
            components.port == nil
        else {
            return base
        }

        if (proto == "http" && cleanedPort == "80") || (proto == "https" && cleanedPort == "443") {
            return base
        }

        components.port = Int(cleanedPort)
        return components.url?.absoluteString ?? base
    }
}

struct XtreamCategoryDTO: Decodable, Hashable {
    let id: String
    let name: String

    private enum CodingKeys: String, CodingKey {
        case id = "category_id"
        case name = "category_name"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = normalizedCategoryIdentifier(container.decodeFlexibleString(forKey: .id))
            ?? UUID().uuidString
        name = container.decodeFlexibleString(forKey: .name) ?? "Uncategorized"
    }
}

struct XtreamStreamDTO: Decodable, Hashable {
    let streamID: String
    let name: String
    let categoryID: String
    let categoryIDs: [String]
    let streamIcon: String?
    let containerExtension: String?
    let directSource: String?

    private enum CodingKeys: String, CodingKey {
        case streamID = "stream_id"
        case name
        case categoryID = "category_id"
        case categoryIDs = "category_ids"
        case streamIcon = "stream_icon"
        case containerExtension = "container_extension"
        case directSource = "direct_source"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        streamID = (container.decodeFlexibleString(forKey: .streamID) ?? UUID().uuidString)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        name = container.decodeFlexibleString(forKey: .name) ?? "Untitled Stream"
        let primaryCategoryID = normalizedCategoryIdentifier(container.decodeFlexibleString(forKey: .categoryID))
        let secondaryCategoryID = normalizedCategoryIdentifier(container.decodeFirstCategoryID(forKey: .categoryIDs))
        let parsedCategoryIDs = container.decodeCategoryIDList(forKey: .categoryIDs)
        categoryIDs = mergedCategoryIDs(primary: primaryCategoryID, secondary: secondaryCategoryID, parsed: parsedCategoryIDs)
        categoryID = categoryIDs.first ?? selectBestCategoryID(primary: primaryCategoryID, secondary: secondaryCategoryID)
        streamIcon = container.decodeFlexibleString(forKey: .streamIcon)
        containerExtension = container.decodeFlexibleString(forKey: .containerExtension)
        directSource = container.decodeFlexibleString(forKey: .directSource)
    }
}

struct XtreamSeriesDTO: Decodable, Hashable {
    let seriesID: String
    let name: String
    let categoryID: String
    let categoryIDs: [String]
    let coverURL: String?
    let synopsis: String?

    private enum CodingKeys: String, CodingKey {
        case seriesID = "series_id"
        case name
        case categoryID = "category_id"
        case categoryIDs = "category_ids"
        case coverURL = "cover"
        case synopsis = "plot"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        seriesID = (container.decodeFlexibleString(forKey: .seriesID) ?? UUID().uuidString)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        name = container.decodeFlexibleString(forKey: .name) ?? "Untitled Series"
        let primaryCategoryID = normalizedCategoryIdentifier(container.decodeFlexibleString(forKey: .categoryID))
        let secondaryCategoryID = normalizedCategoryIdentifier(container.decodeFirstCategoryID(forKey: .categoryIDs))
        let parsedCategoryIDs = container.decodeCategoryIDList(forKey: .categoryIDs)
        categoryIDs = mergedCategoryIDs(primary: primaryCategoryID, secondary: secondaryCategoryID, parsed: parsedCategoryIDs)
        categoryID = categoryIDs.first ?? selectBestCategoryID(primary: primaryCategoryID, secondary: secondaryCategoryID)
        coverURL = container.decodeFlexibleString(forKey: .coverURL)
        synopsis = container.decodeFlexibleString(forKey: .synopsis)
    }
}

struct XtreamEpisodeDTO: Hashable {
    let id: String
    let title: String
    let season: Int
    let episodeNumber: Int
    let streamURL: String?
    let overview: String?
}

enum PlaylistValidationStep: String, CaseIterable, Identifiable {
    case authenticate
    case live
    case vod
    case series

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .authenticate:
            return String(localized: "validation_step.authenticate", defaultValue: "Authentication")
        case .live:
            return String(localized: "validation_step.live", defaultValue: "Live TV")
        case .vod:
            return String(localized: "validation_step.vod", defaultValue: "Movies")
        case .series:
            return String(localized: "validation_step.series", defaultValue: "Series")
        }
    }
}

enum XtreamAPIError: LocalizedError, Equatable {
    case invalidURL
    case timeout
    case unauthorized
    case server(String)
    case emptyResponse
    case decoding(String)
    case network(String)
    case validation(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL. Check the server address."
        case .timeout:
            return "Request timed out. The server did not respond in time."
        case .unauthorized:
            return "Authentication failed. Check username and password."
        case .server(let message):
            return "Server error: \(message)"
        case .emptyResponse:
            return "The server returned an empty response."
        case .decoding(let detail):
            return "Unexpected server response: \(detail)"
        case .network(let detail):
            return "Network error: \(detail)"
        case .validation(let detail):
            return detail
        }
    }
}

extension KeyedDecodingContainer {
    func decodeFlexibleString(forKey key: Key) -> String? {
        if let value = try? decode(String.self, forKey: key) {
            return value
        }
        if let value = try? decode(Int.self, forKey: key) {
            return String(value)
        }
        if let value = try? decode(Double.self, forKey: key) {
            return String(value)
        }
        if let value = try? decode(Bool.self, forKey: key) {
            return value ? "1" : "0"
        }
        return nil
    }

    func decodeFlexibleBool(forKey key: Key) -> Bool? {
        if let value = try? decode(Bool.self, forKey: key) {
            return value
        }
        if let value = try? decode(Int.self, forKey: key) {
            return value == 1
        }
        if let value = try? decode(String.self, forKey: key) {
            let lowered = value.lowercased()
            return lowered == "1" || lowered == "true" || lowered == "yes"
        }
        return nil
    }

    func decodeFirstCategoryID(forKey key: Key) -> String? {
        if let values = try? decode([String].self, forKey: key),
           let first = values.first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            return first
        }
        if let values = try? decode([Int].self, forKey: key),
           let first = values.first {
            return String(first)
        }
        if let raw = try? decode(String.self, forKey: key) {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return nil }

            if trimmed.hasPrefix("["),
               let data = trimmed.data(using: .utf8),
               let array = try? JSONSerialization.jsonObject(with: data) as? [Any] {
                for element in array {
                    if let value = element as? String {
                        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !clean.isEmpty { return clean }
                    } else if let value = element as? Int {
                        return String(value)
                    } else if let value = element as? NSNumber {
                        return value.stringValue
                    }
                }
            }

            let split = trimmed.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            if let first = split.first(where: { !$0.isEmpty }) {
                return first
            }
            return trimmed
        }
        return nil
    }

    func decodeCategoryIDList(forKey key: Key) -> [String] {
        var output: [String] = []

        if let values = try? decode([String].self, forKey: key) {
            output.append(contentsOf: values)
        } else if let values = try? decode([Int].self, forKey: key) {
            output.append(contentsOf: values.map(String.init))
        } else if let raw = try? decode(String.self, forKey: key) {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("["),
               let data = trimmed.data(using: .utf8),
               let array = try? JSONSerialization.jsonObject(with: data) as? [Any] {
                for element in array {
                    if let value = element as? String {
                        output.append(value)
                    } else if let value = element as? Int {
                        output.append(String(value))
                    } else if let value = element as? NSNumber {
                        output.append(value.stringValue)
                    }
                }
            } else if !trimmed.isEmpty {
                output.append(contentsOf: trimmed.split(separator: ",").map(String.init))
            }
        }

        var normalized: [String] = []
        for value in output {
            guard let clean = normalizedCategoryIdentifier(value) else { continue }
            if normalized.contains(clean) == false {
                normalized.append(clean)
            }
        }

        return normalized
    }
}

private func normalizedCategoryIdentifier(_ raw: String?) -> String? {
    guard let raw else { return nil }
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    let lowered = trimmed.lowercased()
    if lowered == "null" || lowered == "nil" || lowered == "none" || lowered == "undefined" {
        return nil
    }

    if let intValue = Int(trimmed) {
        return String(intValue)
    }

    if let doubleValue = Double(trimmed),
       doubleValue.rounded(.towardZero) == doubleValue {
        return String(Int(doubleValue))
    }

    return trimmed
}

private func selectBestCategoryID(primary: String?, secondary: String?) -> String {
    if let primary, !isFallbackCategoryID(primary) {
        return primary
    }
    if let secondary {
        return secondary
    }
    if let primary {
        return primary
    }
    return "0"
}

private func isFallbackCategoryID(_ value: String) -> Bool {
    value == "0" || value == "-1"
}

private func mergedCategoryIDs(primary: String?, secondary: String?, parsed: [String]) -> [String] {
    var output: [String] = []

    if let primary, !isFallbackCategoryID(primary) {
        output.append(primary)
    }

    for value in parsed where output.contains(value) == false {
        output.append(value)
    }

    if let secondary, output.contains(secondary) == false {
        output.append(secondary)
    }

    if output.isEmpty {
        output.append(selectBestCategoryID(primary: primary, secondary: secondary))
    }

    return output
}
