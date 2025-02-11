import Foundation

public class StoryContent {
  var id: String
  let ids: Int
  let settings: StoriesSettings
  let stories: [Story]
  
  public init(json: [String: Any]) {
    self.id = json["id"] as? String ?? "-1"
    self.ids = json["id"] as? Int ?? -1
    let _settings = json["settings"] as? [String: Any] ?? [:]
    self.settings = StoriesSettings(json: _settings)
    let _stories = json["stories"] as? [[String: Any]] ?? []
    self.stories = _stories.map({Story(json: $0)})
    
    if let ids = json["id"] as? Int {
      self.id = String(ids)
    }
  }
}
