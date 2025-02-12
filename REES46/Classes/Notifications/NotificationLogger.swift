public class NotificationLogger{
  private let logTag = "PUSH"
  private var sdk: PersonalizationSDK?
  private weak var notificationService: NotificationService?

  public init(sdk: PersonalizationSDK) {
    self.sdk = sdk
  }
  
  public func log(_ message: String) {
    print("📩\(logTag): \(message)")
  }
  public func notificationClicked(type: String, code: String) {
    notificationService?.sdk.notificationClicked(type: type, code: code) { error in
      self.log("Notification Clicked: \(error)")
    }
  }
  
  public func notificationReceived(type: String, code: String) {
    notificationService?.sdk.notificationReceived(type: type, code: code) { error in
      self.log("Notification Received: \(error)")
    }
  }
  
  public func logAllPushKeysAndValues(userInfo: [AnyHashable: Any]) {
    log("Logging all keys and values from push:")
    for (key, value) in userInfo {
      log("Key: \(key), Value: \(value)")
    }
    log("End of logging keys and values.")
  }
}
