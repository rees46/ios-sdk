
import Foundation

/**
 Attribution as it travels on the wire: the raw `recommended_by` value plus its code.

 Deliberately a raw string rather than ``RecommendedByCase``: the public enum shipped without a
 `stories` case, and adding one to a released public enum breaks any host that switches over it
 exhaustively. Keeping the wire form separate lets ``TrackingSourceType`` carry the full set the API
 accepts without touching ``RecommendedByCase``.
 */
struct TrackingSourceWire {

    let type: String
    let code: String

    init(type: String, code: String) {
        self.type = type
        self.code = code
    }

    init(_ recommendedBy: RecomendedBy) {
        self.init(type: recommendedBy.type.rawValue, code: recommendedBy.code)
    }

    /// The parameter a code goes under — `web_push_digest` names its own field, everything else uses
    /// `recommended_code`. Mirrors `RecommendedByCase.getCodeField()`.
    private var codeField: String {
        type == RecommendedByCase.webPushDigest.rawValue
            ? Constants.RecommendedBy.webPushDigestCode
            : Constants.RecommendedBy.recommendedCode
    }

    func params() -> [String: String] {
        [
            Constants.RecommendedBy.recommendedBy: type,
            codeField: code
        ]
    }
}

/**
 Payload that belongs to a tracked event but not to the public ``Event`` enum.

 ``Event`` is public, deprecated and frozen — see the note on it — so the fields the `tracking`
 namespace adds ride alongside instead of inside it. Every field is optional and applies to exactly
 one family of events; the rest ignore it:

 - `price` — the cart line's price (`.productAddedToCart`)
 - `results` — the ids a host-run search displayed (`.search`)
 - `storiesCode` — an explicit stories block code (`.slideView` / `.slideClick`), overriding the code
   of the block the SDK last loaded
 */
struct TrackEventDetails {

    var price: Double?
    var results: [String]?
    var storiesCode: String?

    init(price: Double? = nil, results: [String]? = nil, storiesCode: String? = nil) {
        self.price = price
        self.results = results
        self.storiesCode = storiesCode
    }

    /// Nothing extra — what the deprecated `track(event:)` path sends.
    static let none = TrackEventDetails()
}

protocol TrackEventServiceProtocol {
    func track(event: Event, recommendedBy: RecomendedBy?, completion: @escaping (Result<Void, SdkError>) -> Void)
    /// Same request as `track(event:recommendedBy:completion:)`, with the namespace-only payload.
    func track(event: Event, source: TrackingSourceWire?, details: TrackEventDetails, completion: @escaping (Result<Void, SdkError>) -> Void)
    func trackPurchase(_ request: PurchaseTrackingRequest, recommendedBy: RecomendedBy?, completion: @escaping (Result<Void, SdkError>) -> Void)
    func trackPurchase(_ request: PurchaseTrackingRequest, source: TrackingSourceWire?, completion: @escaping (Result<Void, SdkError>) -> Void)
    func trackEvent(event: String, time: Int?, category: String?, label: String?, value: Int?, customFields: [String: Any]?, completion: @escaping (Result<Void, SdkError>) -> Void)
    func trackPopupShown(popupId: Int, completion: @escaping (Result<Void, SdkError>) -> Void)
}
