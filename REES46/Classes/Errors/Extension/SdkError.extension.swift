import Foundation

extension SdkError: SdkErrorDescription {
    public var description: String {
        switch self {
        case .noError:
            return "No Errors"
        case .incorrectAPIKey:
            return "Incorrect API Key"
        case .initializationFailed:
            return "Initialization Failed"
        case .responseError:
            return "Response Error"
        case .invalidResponse:
            return "Invalid Response"
        case .decodeError:
            return "Decode Error"
        case .networkOfflineError:
            return "Network Offline"
        case .airplaneModeError:
            return "Airplane Mode Error"
        case .custom(let error):
            return "Custom Error: \(error)"
        }
    }
}
