import Foundation

/// The push service's log. It writes through the SDK's log, so `Rees46Config.logLevel` and
/// `Rees46.setLogHandler` apply to it; push content and tokens are never part of a message.
public class NotificationLogger{
  private let logTag = "PUSH"
  
  public init(){}
  
  /// A step of push handling, at `debug`. The text must not carry push values or tokens.
  public func log(_ message: String) {
    SdkLogger.process.debug(LogCode.pushReceived, "\(logTag): \(message)")
  }
  /// Logs the kind of the error, not its text: an error may carry what the server sent back.
  public func log(_ message: Error){
    SdkLogger.process.error(LogCode.pushFailed, "\(logTag): the push could not be handled", ["error": SdkLogger.errorKind(message)])
  }
  
  /// Logs the keys of a push, not their values: push content is personal data.
  @available(*, deprecated, message: "Logs the keys only: push content is never logged.")
  public func logAllPushKeysAndValues(userInfo: [AnyHashable: Any?]) {
    log("push keys: \(userInfo.keys.map { "\($0)" }.sorted().joined(separator: ", "))")
  }
}
