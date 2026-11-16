//
//  SdkError.swift
//  REES46
//
//  The SDK's failures as `sdk/core/errors.md` defines them, and the one mapping to the error the
//  old methods return.
//

import Foundation

extension Rees46 {

    /// A failure of the SDK, as the new core classifies it (`sdk/core/errors.md`).
    ///
    /// Nested in the facade: the old top-level `SdkError`, which the existing methods return, stays as
    /// it is — a new case in a public enum breaks an app's exhaustive `switch`. The old methods get
    /// this error mapped by `SdkError.legacy(_:serverMessage:)`.
    public enum SdkError: Error, Equatable {
        /// The method was called on an instance that was not created or was released.
        case notInitialized
        /// The shop refused (`refused`): the SDK does not send anything for it.
        case shopBlocked
        /// A parameter was rejected before anything was sent; the text says which one.
        case invalidArgument(String)
        /// No network, or the connection was not established.
        case network
        /// No answer within the timeout, a body cut by it included.
        case timeout
        /// The server answered outside `2xx`. `serverCode` is the machine code of the error body,
        /// once the backend sends one (it does not yet).
        case http(code: Int, serverCode: String?)
        /// A `2xx` answer that does not parse.
        case decoding
        /// The request was cancelled: the instance was released.
        case cancelled

        /// A line for the log: English, without personal data and without the answer's body.
        public var message: String {
            switch self {
            case .notInitialized: return "the SDK instance is not initialized"
            case .shopBlocked: return "the shop is blocked"
            case .invalidArgument(let what): return "invalid argument: \(what)"
            case .network: return "no network"
            case .timeout: return "the request timed out"
            case .http(let code, _): return "HTTP \(code)"
            case .decoding: return "the answer did not parse"
            case .cancelled: return "the request was cancelled"
            }
        }

        /// The case without what it carries.
        var logKind: String {
            switch self {
            case .notInitialized: return "notInitialized"
            case .shopBlocked: return "shopBlocked"
            case .invalidArgument: return "invalidArgument"
            case .network: return "network"
            case .timeout: return "timeout"
            case .http(let code, _): return "http \(code)"
            case .decoding: return "decoding"
            case .cancelled: return "cancelled"
            }
        }
    }
}

extension SdkError {

    /// The error an old method returns for `error`, whichever core sent its request. The one mapping
    /// of the SDK; `serverMessage` is the `message` of an error body, which the old `postRequest`
    /// handed to the app as `.custom`.
    static func legacy(_ error: Rees46.SdkError, serverMessage: String? = nil) -> SdkError {
        switch error {
        case .http:
            return serverMessage.map { .custom(error: $0) } ?? .invalidResponse
        case .network:
            return .networkOfflineError
        case .timeout:
            return .invalidResponse
        case .decoding:
            return .decodeError
        case .shopBlocked:
            return .custom(error: "shop blocked")
        case .notInitialized:
            return .initializationFailed
        case .invalidArgument(let what):
            return .custom(error: what)
        case .cancelled:
            // The old sessions answered a cancelled task the way they answered any lost request.
            return .invalidResponse
        }
    }

    /// What the old push token methods get when the token waits for the device id: it goes once
    /// `/init` stores one.
    static let pushTokenWaitsForDeviceId = SdkError.custom(error: "the push token is sent once the device has an id")

    var isPushTokenWaitingForDeviceId: Bool {
        if case let .custom(message) = self, case let .custom(waiting) = Self.pushTokenWaitsForDeviceId {
            return message == waiting
        }
        return false
    }

    /// The `message` of an error body in the shape most of the API answers with:
    /// `{"status": "error", "message": "…"}`.
    static func serverMessage(in body: Data) -> String? {
        guard !body.isEmpty,
              let json = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any],
              json["status"] as? String == "error" else {
            return nil
        }
        return json["message"] as? String
    }
}
