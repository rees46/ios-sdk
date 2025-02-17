import Foundation

enum WrongUrlError: Error {
  case failed(String)
    var localizedDescription: String {
        switch self {
        case .failed(let error):
            return "WebView error: \(error)"
        }
    }
}
