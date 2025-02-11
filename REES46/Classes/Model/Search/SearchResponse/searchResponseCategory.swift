import Foundation

public struct Category {
  public var id: String = ""
  public var name: String = ""
  public var url: String?
  public var alias: String?
  public var parentId: String?
  public var count: Int?
  
  init(json: [String: Any]) {
    id = json["id"] as? String ?? ""
    name = json["name"] as? String ?? ""
    url = json["url"] as? String
    alias = json["alias"] as? String
    parentId = json["parent"] as? String
    count = json["count"] as? Int
  }
}
