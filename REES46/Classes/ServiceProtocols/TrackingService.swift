
import Foundation

protocol TrackEventService {
    func track(event: Event, recommendedBy: RecomendedBy?, completion: @escaping (Result<Void, SDKError>) -> Void)
    func trackEvent(event: String, category: String?, label: String?, value: Int?, completion: @escaping (Result<Void, SDKError>) -> Void)
}

protocol TrackSourceService {
    func trackSource(source: RecommendedByCase, code: String)
}
