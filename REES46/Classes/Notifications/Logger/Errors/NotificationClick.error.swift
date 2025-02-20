import Foundation

enum NotificationClickError: Error {
    case failed(Error)

    var error: Error {
        guard case .failed(let error) = self else { fatalError("Unexpected case") }
        return error
    }

    var localizedDescription: String {
        "❌ Notification Click Error: \(error.localizedDescription)"
    }
}
