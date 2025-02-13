import Foundation

public class NotificationLogger{
  private let logTag = "PUSH"
  
  public init(){}
  
  public func log(_ message: String) {
    print("\(logTag): \(message)")
  }
  
  public func logAllPushKeysAndValues(userInfo: [AnyHashable: Any?]) {
    log("Logging all keys and values from push:")
    for (key, value) in userInfo {
      if let value = value {
        log("Key: \(key), Value: \(value)")
      }else {
        log("Error: Value is nil.")
      }
    }
    log("End of logging keys and values.")
  }
}
