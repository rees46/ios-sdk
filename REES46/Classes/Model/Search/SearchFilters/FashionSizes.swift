import Foundation

public struct FashionSizes {
  public var count: Int
  public var size: String
  
  init(json: [String: Any]) {
    self.count = json["count"] as? Int  ?? 0
    self.size = json["size"] as? String ?? ""
  }
}
