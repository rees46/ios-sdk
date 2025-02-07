import Foundation

public struct FashionColors {
  public var count: Int
  public var color: String
  
  init(json: [String: Any]) {
    self.count = json["count"] as? Int ?? 0
    self.color = json["color"] as? String ?? ""
  }
}

