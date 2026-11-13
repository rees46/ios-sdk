//
//  SdkLogMessage.swift
//  REES46
//

import Foundation

/// One message of the SDK, as `Rees46.setLogHandler` hands it to the app — to forward to Crashlytics
/// or Sentry, say. It never carries request data, response bodies, contacts, the push token, push
/// content or the `/init` answer.
public struct SdkLogMessage {
    /// The level of the message.
    public let level: LogLevel
    /// A stable code of the event, `snake_case`: `request_failed`, `decoding_failed`, …
    public let code: String
    /// Text in English, without personal data.
    public let message: String
    /// The shop the message is about; `nil` for messages about the SDK as a whole.
    public let shopId: String?
    /// Details without personal data: the request path, the HTTP code, the number of attempts.
    public let context: [String: String]

    public init(level: LogLevel, code: String, message: String, shopId: String?, context: [String: String] = [:]) {
        self.level = level
        self.code = code
        self.message = message
        self.shopId = shopId
        self.context = context
    }
}
