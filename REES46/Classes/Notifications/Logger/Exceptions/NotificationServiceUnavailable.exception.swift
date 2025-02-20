import Foundation

enum NotificationServiceUnavailable: Error {
    case serviceNotAvailable

    var localizedDescription: String {
        return "Notification Service is not available."
    }
}
