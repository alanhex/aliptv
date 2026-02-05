import Foundation

struct SeriesItem: Identifiable, Codable, Hashable {
    let id: Int
    let name: String
    let cover: String?
    let categoryId: String?

    enum CodingKeys: String, CodingKey {
        case id = "series_id"
        case name
        case cover
        case categoryId = "category_id"
    }
}
