import Foundation

/// The push service's log. It writes through the SDK's log at `debug`, so `Rees46Config.logLevel`
/// and `Rees46.setLogHandler` apply to it; push content and tokens are never part of a message.
public class NotificationLogger{
  private let logTag = "PUSH"
  
  public init(){}
  
  public func log(_ message: String) {
    SdkLogger.process.debug("push", "\(logTag): \(message)")
  }
  /// Logs the kind of the error, not its text: an error may carry what the server sent back.
  public func log(_ message: Error){
    SdkLogger.process.warning("push_error", "\(logTag): \(String(describing: type(of: message)))")
  }
  
  /// Logs the keys of a push, not their values: push content is personal data.
  @available(*, deprecated, message: "Logs the keys only: push content is never logged.")
  public func logAllPushKeysAndValues(userInfo: [AnyHashable: Any?]) {
    log("push keys: \(userInfo.keys.map { "\($0)" }.sorted().joined(separator: ", "))")
  }
}
