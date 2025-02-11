import Foundation

public struct PriceRange {
  public var min: Double
  public var max: Double
  
  init(json: [String: Any]) {
    self.min = json["min"] as? Double ?? 0
    self.max = json["max"] as? Double ?? 0
  }
}
