import Foundation

public struct Query {
  public var name: String
  public var url: String
  public var deeplinkIos: String
  
  init(json: [String: Any]) {
    name = json["name"] as? String ?? ""
    url = json["url"] as? String ?? ""
    deeplinkIos = json["deeplink_ios"] as? String ?? ""
  }
}
