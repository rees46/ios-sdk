import Foundation

enum NotificationReceiveError: Error {
    case failed(Error)

    var localizedDescription: String {
        switch self {
        case .failed(let error):
            return "❌ Notification Receive Error: \(error.localizedDescription)"
        }
    }
}
