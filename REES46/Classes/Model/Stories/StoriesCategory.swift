import Foundation

class StoriesCategory {
  let name: String
  let url: String
  
  public init(json: [String: Any]) {
    self.name = json["name"] as? String ?? ""
    self.url = json["url"] as? String ?? ""
  }
}

