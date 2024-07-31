
import Foundation

protocol NotificationHandlingService {
    
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
        completion: @escaping(Result<UserPayloadResponse, SDKError>) -> Void
    )
    
    func trackNotification(
        path: String,
        type: String,
        code: String,
        completion: @escaping (Result<Void, SDKError>) -> Void
    )
}
