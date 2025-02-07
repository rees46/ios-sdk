import Foundation

public struct Filter {
  public var count: Int
  public var values: [String: Int]
  
  init(json: [String: Any]) {
    self.count = json["count"] as? Int ?? 0
    self.values = json["values"] as? [String: Int] ?? [:]
  }
}
