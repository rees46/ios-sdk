import Foundation

public class StoryContent: Codable {
  var id: String
  let ids: Int
  let settings: StoriesSettings
  let stories: [Story]
  
  private enum CodingKeys: String, CodingKey {
    case id,settings, stories
  }
  
  required public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decodeIfPresent(String.self, forKey: .id) ?? "-1"
    ids = try container.decodeIfPresent(Int.self, forKey: .id) ?? -1
    if let ids = try container.decodeIfPresent(Int.self, forKey: .id) {
     id = String(ids)
   }
    settings = try container.decode(StoriesSettings.self, forKey: .settings)
    stories = try container.decode([Story].self, forKey: .stories)
  }
}
