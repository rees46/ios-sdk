import Foundation

public class StoriesSettings:Codable {
  let color: String
  let fontSize: Int
  let avatarSize: Int
  let closeColor: String
  let borderViewed, backgroundPin, borderNotViewed: String
  let backgroundProgress: String
  let pinSymbol: String
  
  public enum CodingKeys: String, CodingKey {
    case color
    case fontSize = "font_size"
    case avatarSize = "avatar_size"
    case closeColor = "close_color"
    case borderViewed = "border_viewed"
    case backgroundPin = "background_pin"
    case borderNotViewed = "border_not_viewed"
    case backgroundProgress = "background_progress"
    case pinSymbol = "pin_symbol"
  }
  required public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    color = try container.decode(String.self, forKey: .color)
    fontSize = try container.decode(Int.self, forKey: .fontSize)
    avatarSize = try container.decode(Int.self, forKey: .avatarSize)
    closeColor = try container.decode(String.self, forKey: .closeColor)
    borderViewed = try container.decode(String.self, forKey: .borderViewed)
    backgroundPin = try container.decode(String.self, forKey: .backgroundPin)
    borderNotViewed = try container.decode(String.self, forKey: .borderNotViewed)
    backgroundProgress = try container.decode(String.self, forKey: .backgroundProgress)
    pinSymbol = try container.decode(String.self, forKey: .pinSymbol)
  }
}
