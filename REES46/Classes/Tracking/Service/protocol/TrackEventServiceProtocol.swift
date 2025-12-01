
import Foundation

protocol TrackEventServiceProtocol {
    func track(event: Event, recommendedBy: RecomendedBy?, completion: @escaping (Result<Void, SdkError>) -> Void)
    func trackEvent(event: String, category: String?, label: String?, value: Int?, completion: @escaping (Result<Void, SdkError>) -> Void)
    func trackPopupShown(popupId: Int, completion: @escaping (Result<Void, SdkError>) -> Void)
}
