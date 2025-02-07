import Foundation

class Story {
  var id: String
  let ids: Int
  let avatar: String
  let viewed: Bool
  let startPosition: Int
  let name: String
  let pinned: Bool
  let slides: [Slide]
  
  public init(json: [String: Any]) {
    self.id = json["id"] as? String ?? "-1"
    self.ids = json["id"] as? Int ?? -1
    self.avatar = json["avatar"] as? String ?? ""
    self.viewed = json["viewed"] as? Bool ?? false
    self.startPosition = json["start_position"] as? Int ?? 0
    self.name = json["name"] as? String ?? ""
    self.pinned = json["pinned"] as? Bool ?? false
    let _slides = json["slides"] as? [[String: Any]] ?? []
    self.slides = _slides.map({Slide(json: $0)})
    
    if let ids = json["id"] as? Int {
      self.id = String(ids)
    }
  }
}
