import Foundation

enum WrongUrlError: Error {
    case invalidURL
    case unsupportedURL

    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "WebView error: String is not URL"
        case .unsupportedURL:
            return "WebView error: Unsupported URL"
        }
    }
}
