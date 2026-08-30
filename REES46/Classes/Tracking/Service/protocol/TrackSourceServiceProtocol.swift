
import Foundation

protocol TrackSourceServiceProtocol {
    func trackSource(source: RecommendedByCase, code: String)
    /// Stores a raw `recommended_by` value. Needed for the sources ``RecommendedByCase`` has no case
    /// for — `stories` — which cannot be added to that released public enum without breaking hosts
    /// that switch over it. See ``TrackingSourceType``.
    func trackSource(type: String, code: String)
}
