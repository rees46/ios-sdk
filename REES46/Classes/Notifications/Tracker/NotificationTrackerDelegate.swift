public protocol NotificationTrackerDelegate: AnyObject {
  func notificationClicked(type: String, code: String)
  func notificationReceived(type: String, code: String)
  func notificationDelivered(userInfo: [AnyHashable: Any]) 
}
