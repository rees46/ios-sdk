public struct UserNotificationsStatistics {
  
  let opened: Bool?
  let clicked: Bool?
  let hardBounced: Bool?
  let softBounced: Bool?
  let complained: Bool?
  let unsubscribed: Bool?
  let purchased: Bool?
  
  init(json: [String: Any]) {
    opened = json["opened"] as? Bool
    clicked = json["clicked"] as? Bool
    hardBounced = json["hardBounced"] as? Bool
    softBounced = json["softBounced"] as? Bool
    complained = json["complained"] as? Bool
    unsubscribed = json["unsubscribed"] as? Bool
    purchased = json["purchased"] as? Bool
  }
}
