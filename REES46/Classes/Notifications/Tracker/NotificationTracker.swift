import Foundation

/// Superseded by `Rees46.handlePush`, which tracks against the shop the push names (`shop_id`) instead
/// of a single captured `sdk`. `NotificationService` no longer drives this delegate, so constructing a
/// `NotificationTracker` is now a no-op kept for source compatibility. New code should not rely on it.
public class NotificationTracker: NotificationTrackerDelegate{
  
  private let notificationLogger: NotificationLogger
  public var notificationService: NotificationService?
  
  public init(notificationLogger: NotificationLogger, notificationService: NotificationService) {
    self.notificationLogger = notificationLogger
    self.notificationService = notificationService
    self.notificationService?.notificationTrackerDelegate = self
  }
  
  public func notificationClicked(type: String, code: String) {
    guard let notificationService = notificationService else {
      notificationLogger.log(NotificationServiceUnavailable.serviceNotAvailable)
      return
    }
    notificationService.sdk.notificationClicked(type: type, code: code) { [weak self] result in
      switch result {
      case .success:
        self?.notificationLogger.log("Notification Clicked Successfully")
      case .failure(let error):
        self?.notificationLogger.log(NotificationClickError.failed(error))
      }
    }
  }
  
  public func notificationReceived(type: String, code: String) {
    guard let notificationService = notificationService else {
      notificationLogger.log(NotificationServiceUnavailable.serviceNotAvailable)
      return
    }
    notificationService.sdk.notificationReceived(type: type, code: code) { [weak self] result in
      switch result {
      case .success:
        self?.notificationLogger.log("Notification Received Successfully")
      case .failure(let error):
        self?.notificationLogger.log(NotificationReceiveError.failed(error))
      }
    }
  }
  
  public func notificationDelivered(userInfo: [AnyHashable: Any]) {
    guard let notificationService = notificationService else {
      notificationLogger.log(NotificationServiceUnavailable.serviceNotAvailable)
      return
    }
    notificationLogger.log("Notification delivered")
    
    guard let (eventType, srcID) = notificationService.extractTypeAndCode(from: userInfo) else {
      notificationLogger.log("Failed to extract type and code, skipping notificationDelivered")
      return
    }
    // The type and code of the push are its content: they are not logged.
    notificationLogger.log("Extracted the type and code of the push")
    
    notificationService.sdk.notificationDelivered(type: eventType, code: srcID) { [weak self] result in
      switch result {
      case .success:
        self?.notificationLogger.log("Notification Delivered Successfully")
      case .failure(let error):
        // The kind of the error only: `.custom` carries the server's message.
        self?.notificationLogger.log(error)
      }
    }
  }
}
