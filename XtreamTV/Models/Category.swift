import Foundation

struct Category: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let parentId: Int?

    enum CodingKeys: String, CodingKey {
        case id = "category_id"
        case name = "category_name"
        case parentId = "parent_id"
    }
}
