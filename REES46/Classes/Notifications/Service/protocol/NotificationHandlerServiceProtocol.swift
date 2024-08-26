
import Foundation

protocol NotificationHandlerServiceProtocol {
    
    func getAllNotifications(
        type: String,
        phone: String?,
        email: String?,
        userExternalId: String?,
        userLoyaltyId: String?,
        channel: String?,
        limit: Int?,
        page: Int?,
        dateFrom: String?,
        completion: @escaping(Result<UserPayloadResponse, SdkError>) -> Void
    )
    
    func trackNotification(
        path: String,
        type: String,
        code: String,
        completion: @escaping (Result<Void, SdkError>) -> Void
    )
}
