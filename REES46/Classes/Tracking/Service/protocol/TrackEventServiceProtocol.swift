
import Foundation

protocol TrackEventServiceProtocol {
    func track(event: Event, recommendedBy: RecomendedBy?, completion: @escaping (Result<Void, SdkError>) -> Void)
    func trackPurchase(_ request: PurchaseTrackingRequest, recommendedBy: RecomendedBy?, completion: @escaping (Result<Void, SdkError>) -> Void)
    func trackEvent(event: String, time: Int?, category: String?, label: String?, value: Int?, customFields: [String: Any]?, completion: @escaping (Result<Void, SdkError>) -> Void)
    func trackPopupShown(popupId: Int, completion: @escaping (Result<Void, SdkError>) -> Void)
}
