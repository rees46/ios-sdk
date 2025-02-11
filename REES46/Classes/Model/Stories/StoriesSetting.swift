import Foundation

public class StoriesSettings {
  let color: String
  let fontSize: Int
  let avatarSize: Int
  let closeColor: String
  let borderViewed, backgroundPin, borderNotViewed: String
  let backgroundProgress: String
  let pinSymbol: String
  
  public init(json: [String: Any]) {
    self.color = json["color"] as? String ?? ""
    self.fontSize = json["font_size"] as? Int ?? 12
    self.avatarSize = json["avatar_size"] as? Int ?? 20
    self.closeColor = json["close_color"] as? String ?? ""
    self.borderViewed = json["border_viewed"] as? String ?? ""
    self.backgroundPin = json["background_pin"] as? String ?? ""
    self.borderNotViewed = json["border_not_viewed"] as? String ?? ""
    self.backgroundProgress = json["background_progress"] as? String ?? ""
    self.pinSymbol = json["pin_symbol"] as? String ?? ""
  }
}
