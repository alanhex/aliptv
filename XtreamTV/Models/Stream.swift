import Foundation

struct Stream: Identifiable, Codable, Hashable {
    let id: Int
    let name: String
    let streamIcon: String?
    let streamType: String?
    let categoryId: String?
    let containerExtension: String?

    enum CodingKeys: String, CodingKey {
        case id = "stream_id"
        case name
        case streamIcon = "stream_icon"
        case streamType = "stream_type"
        case categoryId = "category_id"
        case containerExtension = "container_extension"
    }
}
