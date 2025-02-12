import Foundation

public struct Category: Codable {
  public var id: String
  public var name: String
  public var url: String?
  public var alias: String?
  public var parentId: String?
  public var count: Int?
  
  enum CodingKeys: String, CodingKey {
    case id,name ,url ,alias ,count
    case parentId = "parent"

  }
  
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    
    id = try container.decode(String.self, forKey: .id)
    name = try container.decode(String.self, forKey: .name)
    url = try container.decodeIfPresent(String.self, forKey: .url)
    alias = try container.decodeIfPresent(String.self, forKey: .alias)
    parentId = try container.decodeIfPresent(String.self, forKey: .parentId)
    count = try container.decode(Int.self, forKey: .count)
  }
}
