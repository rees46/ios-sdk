import Foundation

public struct UserPayloadResponse {
  
  public var notifications: [UserNotificationsResponse]
  
  init(json: [String: Any]) {
    let notificationsArray = json["messages"] as? [[String: Any]] ?? []
    var notificationsTemp = [UserNotificationsResponse]()
    for item in notificationsArray {
      notificationsTemp.append(UserNotificationsResponse(json: item))
    }
    notifications = notificationsTemp
  }
}
