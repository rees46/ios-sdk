
public struct Redirect: Codable {
  public var query: String
  public var redirectUrl: String
  public var deeplink: String?
  public var deeplinkIos: String?
  
  public enum CodingKeys: String, CodingKey {
    case query = "query"
    case redirectUrl = "redirect_link"
    case deeplink = "deep_link"
    case deeplinkIos = "deeplink_ios"
  }
  
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    
    query = try container.decode(String.self, forKey: .query)
    redirectUrl = try container.decode(String.self, forKey: .redirectUrl)
    deeplink = try container.decode(String.self, forKey: .deeplink)
    deeplinkIos = try container.decode(String.self, forKey: .deeplinkIos)
  }
}
