import Foundation

public struct Suggest {
  public var name: String
  public var url: String
  public var deeplinkIos: String
  
  init(json: [String: Any]) {
    self.name = json["name"] as? String ?? ""
    self.url = json["url"] as? String ?? ""
    self.deeplinkIos = json["deeplink_ios"] as? String ?? ""
  }
}
