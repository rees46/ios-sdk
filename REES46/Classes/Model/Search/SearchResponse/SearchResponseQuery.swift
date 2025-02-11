import Foundation

public struct Query: Codable {
  public var name: String
  public var url: String
  public var deeplinkIos: String
  
  public enum CodingKeys: String, CodingKey {
    case name = "name"
    case url = "url"
    case deeplinkIos = "deeplinkIos"
  }
  
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    
    name = try container.decode(String.self, forKey: .name)
    url = try container.decode(String.self, forKey: .url)
    deeplinkIos = try container.decode(String.self, forKey: .deeplinkIos)
  }
}
