import Foundation
import UIKit

public enum SdkError: Error, CustomStringConvertible {
    case noError
    case incorrectAPIKey
    case initializationFailed
    case responseError
    case invalidResponse
    case decodeError
    case networkOfflineError
    case airplaneModeError
    case custom(error: String)
}
