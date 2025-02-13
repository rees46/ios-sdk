import Foundation

public class NotificationTracker{
  struct Constants{
    static let eventKey: String = "event"
    static let typeKey: String = "type"
    static let idKey: String = "id"
    static let srcKey: String = "src"
  }
  private let notificationLogger: NotificationLogger
  public var notificationService: NotificationService?
  
  public init(notificationLogger: NotificationLogger) {
    self.notificationLogger = notificationLogger
  }
  public func setNotificationService(service: NotificationService?){
    self.notificationService = service
  }
  
  public func notificationClicked(type: String, code: String) {
    notificationService?.sdk.notificationClicked(type: type, code: code) { [weak self] result in
      switch result {
        
      case .success:
        self?.notificationLogger.log("Notification Clicked Successfully")
      case .failure(let error):
        self?.notificationLogger.log(NotificationClickError.failed(error).localizedDescription)
      }
    }
  }
  
  public func notificationReceived(type: String, code: String) {
    notificationService?.sdk.notificationReceived(type: type, code: code) { [weak self] result in
      switch result {
      case .success:
        self?.notificationLogger.log("Notification Received Successfully")
      case .failure(let error):
        self?.notificationLogger.log(NotificationReceiveError.failed(error).localizedDescription)
      }
    }
  }
  public func notificationDelivered(userInfo: [AnyHashable: Any]) {
    notificationLogger.log("Notification delivered")
    notificationLogger.logAllPushKeysAndValues(userInfo: userInfo)
    
    guard let (eventType, srcID) = extractTypeAndCode(from: userInfo) else {
      notificationLogger.log("Failed to extract type and code, skipping notificationDelivered")
      return
    }
    notificationLogger.log("Extracted eventType: \(eventType), srcID: \(srcID)")
    
    notificationService?.sdk.notificationDelivered(type: eventType, code: srcID) { error in
      self.notificationLogger.log("Notification Delivered Error: \(error)")
    }
  }

  
  public func extractTypeAndCode(from userInfo: [AnyHashable: Any]) -> (type: String, code: String)? {
      if let eventJSON = parseDictionary(key: Constants.eventKey, userInfo: userInfo),
         let eventType = eventJSON[Constants.typeKey] as? String {
          if let src = parseDictionary(key: Constants.srcKey, userInfo: userInfo) ??
              (userInfo[Constants.idKey] as? String).map({ [Constants.idKey: $0] }) {
              if let srcID = src[Constants.idKey] as? String {
                  return (eventType, srcID)
              }
          }
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
//  private func extractValue(for key:String) -> String?{
//    
//    return value
//  }

  
  public func parseDictionary(key: String, userInfo: [AnyHashable: Any]) -> [String: Any]? {
    if let eventJSONString = userInfo[key] as? String{
      do{
        if let data = eventJSONString.data(using: .utf8) {
          let jsonObject = try JSONSerialization.jsonObject(with: data)
          if let jsonDict = jsonObject as? [String: Any] {
            return jsonDict
          }
        }
      } catch {
        notificationLogger.log("JSON parsing error for key \(key): \(error.localizedDescription)")
      }
    }
    return userInfo[key] as? [String : Any]
  }
}
