import Foundation

struct AuthResponse: Codable, Hashable {
    let userInfo: UserInfo
    let serverInfo: ServerInfo

    enum CodingKeys: String, CodingKey {
        case userInfo = "user_info"
        case serverInfo = "server_info"
    }
}

struct UserInfo: Codable, Hashable {
    let username: String
    let password: String
    let status: String
    let expDate: String?

    enum CodingKeys: String, CodingKey {
        case username
        case password
        case status
        case expDate = "exp_date"
    }
}

struct ServerInfo: Codable, Hashable {
    let url: String?
    let port: String?
    let httpsPort: String?
    let serverProtocol: String?

    enum CodingKeys: String, CodingKey {
        case url
        case port
        case httpsPort = "https_port"
        case serverProtocol = "server_protocol"
    }
}
