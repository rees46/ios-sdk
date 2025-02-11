import Foundation

public struct Filter: Codable {
  public var count: Int
  public var values: [String: Int]
  
  public enum CodingKeys: String, CodingKey {
    case count = "count"
    case values = "values"
  }
  
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    
    count = try container.decode(Int.self, forKey: .count)
    values = try container.decode([String:Int].self, forKey: .values)
  }
}
