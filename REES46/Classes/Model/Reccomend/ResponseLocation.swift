import Foundation

public struct Location {
  public var id: String = ""
  public var name: String = ""
  
  init(json: [String: Any]) {
    id = json["id"] as? String ?? ""
    name = json["name"] as? String ?? ""
  }
}
