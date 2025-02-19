import Foundation

enum SdkNotInitialized: Error {
    case SdkNotInitialized

    var localizedDescription: String {
        return "SDK is not initialized"
    }
}
