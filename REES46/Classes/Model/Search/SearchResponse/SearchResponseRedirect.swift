
public struct Redirect {
  public var query: String = ""
  public var redirectUrl: String = ""
  public var deeplink: String?
  public var deeplinkIos: String?
  
  init(json: [String: Any]) {
    self.query = json["query"] as? String ?? ""
    self.redirectUrl = json["redirect_link"] as? String ?? ""
    self.deeplink = json["deep_link"] as? String
    self.deeplinkIos = json["deeplink_ios"] as? String
  }
}
