public class NotificationTracker{
  struct Constants{
    static let eventKey: String = "event"
    static let typeKey: String = "type"
    static let idKey: String = "id"
    static let srcKey: String = "src"
  }
  private let notificationLogger: NotificationLogger
  private let notificationService: NotificationService
  private let sdk: PersonalizationSDK
  
  public init(sdk: PersonalizationSDK) {
    self.sdk = sdk
    self.notificationLogger = NotificationLogger(sdk: sdk)
    self.notificationService = NotificationService(sdk: sdk)
  }
  
  public func notificationDelivered(userInfo: [AnyHashable: Any]) {
    notificationLogger.log("Notification delivered")
    notificationLogger.logAllPushKeysAndValues(userInfo: userInfo)
    
    guard let (eventType, srcID) = extractTypeAndCode(from: userInfo) else {
      notificationLogger.log("Failed to extract type and code, skipping notificationDelivered")
      return
    }
    notificationLogger.log("Extracted eventType: \(eventType), srcID: \(srcID)")
    
    sdk.notificationDelivered(type: eventType, code: srcID) { error in
      self.notificationLogger.log("Notification Delivered Error: \(error)")
    }
  }
  public func extractTypeAndCode(from userInfo: [AnyHashable: Any]) -> (type: String, code: String)? {
    if let eventJSON = parseDictionary(key: Constants.eventKey, userInfo: userInfo),
       let eventType = eventJSON[Constants.typeKey] as? String,
       let src = parseDictionary(key: Constants.srcKey, userInfo: userInfo) ?? (userInfo[Constants.idKey].map {
         [Constants.idKey: $0]
       } as? [String: Any]),
       let srcID = src[Constants.idKey] as? String {
      return (eventType, srcID)
    }
    
    if let type = userInfo[Constants.typeKey] as? String, let id = userInfo[Constants.idKey] as? String {
      return (type, id)
    }
    
    if let src = parseDictionary(key: Constants.srcKey, userInfo: userInfo),
       let type = src[Constants.typeKey] as? String, let id = src[Constants.idKey] as? String {
      return (type, id)
    }
    
    return nil
  }
  public func parseDictionary(key: String, userInfo: [AnyHashable: Any]) -> [String: Any]? {
    if let eventJSONString = userInfo[key] as? String,
       let data = eventJSONString.data(using: .utf8),
       let jsonObject = try? JSONSerialization.jsonObject(with: data),
       let jsonDict = jsonObject as? [String: Any] {
      return jsonDict
    }
    
    return userInfo[key] as? [String: Any]
  }
}
