import Foundation

class Story: Codable {
  var id: String
  let ids: Int
  let avatar: String
  let viewed: Bool
  let startPosition: Int
  let name: String
  let pinned: Bool
  let slides: [Slide]
  private enum CodingKeys: String, CodingKey {
    case id, avatar, viewed, name, pinned, slides
    case startPosition = "start_position"
  
  }
  required public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decodeIfPresent(String.self, forKey: .id) ?? "-1"
    ids = try container.decodeIfPresent(Int.self, forKey: .id) ?? -1
     if let ids = try container.decodeIfPresent(Int.self, forKey: .id) {
      id = String(ids)
    }
    avatar = try container.decode(String.self, forKey: .avatar)
    viewed = try container.decode(Bool.self, forKey: .viewed)
    startPosition = try container.decode(Int.self, forKey: .startPosition)
    name = try container.decode(String.self, forKey: .name)
    pinned = try container.decode(Bool.self, forKey: .pinned)
    slides = try container.decode([Slide].self, forKey: .slides)
    }
  }
