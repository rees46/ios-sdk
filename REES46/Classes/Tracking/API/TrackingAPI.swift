import Foundation

/// One product line in a tracking event.
///
/// `quantity` is the domain name for the line quantity; on the wire it is sent as `amount` —
/// the field the REES46 API has always consumed.
public struct TrackingItem {
    public let id: String
    public let quantity: Int
    public let price: Double?
    public let fashionSize: String?

    public init(
        id: String,
        quantity: Int = 1,
        price: Double? = nil,
        fashionSize: String? = nil
    ) {
        self.id = id
        self.quantity = quantity
        self.price = price
        self.fashionSize = fashionSize
    }
}

/// The tool an event is attributed to (`recommended_by` on the wire).
///
/// Mirrors Android's `TrackingSourceType` case for case, so the same source means the same thing on
/// both platforms. Distinct from the older ``RecommendedByCase``, which shipped without `stories` —
/// adding a case to that released public enum would break hosts that switch over it exhaustively.
public enum TrackingSourceType: String {
    case dynamic = "dynamic"
    case chain = "chain"
    case bulk = "bulk"
    case transactional = "transactional"
    case instantSearch = "instant_search"
    case fullSearch = "full_search"
    case stories = "stories"
    case webPushDigest = "web_push_digest"
}

/// Where a tracked action came from — a recommender block, a search result, a story.
///
/// Passed per call to attribute a single event, or stored for subsequent events with
/// ``TrackingAPI/setSource(_:)``.
public struct TrackingSource {
    public let type: TrackingSourceType
    public let code: String

    public init(type: TrackingSourceType, code: String) {
        self.type = type
        self.code = code
    }

    /// Convenience for hosts holding a ``RecommendedByCase`` — the type recommender responses and the
    /// deprecated `trackSource(source:code:)` speak. Labelled `legacy:` rather than overloading
    /// `type:`: the two enums share every case name, so an overload would make `.dynamic` ambiguous.
    public init(legacy type: RecommendedByCase, code: String) {
        self.init(type: TrackingSourceType(type), code: code)
    }
}

public extension TrackingSourceType {

    /// Every ``RecommendedByCase`` has an exact counterpart here — the raw values are the same wire
    /// strings — so the conversion is total.
    init(_ legacy: RecommendedByCase) {
        self = TrackingSourceType(rawValue: legacy.rawValue) ?? .dynamic
    }
}

/// Standard tracking events — the `tracking` namespace of the SDK.
///
/// Reached through an SDK instance: `Rees46.instance().tracking.productView(itemId: "sku-1")`.
public protocol TrackingAPI {

    /// Product page opened (`view`).
    func productView(
        itemId: String,
        source: TrackingSource?,
        completion: @escaping (Result<Void, SdkError>) -> Void
    )

    /// Category listing opened (`category`).
    func categoryView(
        categoryId: String,
        completion: @escaping (Result<Void, SdkError>) -> Void
    )

    /// Search query issued by the user (`search`).
    ///
    /// Pass `results` when the host runs its own search and knows the ids it showed. They go on the
    /// wire as one comma-separated field, so ids must not themselves contain a comma.
    func search(
        query: String,
        results: [String]?,
        completion: @escaping (Result<Void, SdkError>) -> Void
    )

    /// One product added to the cart (`cart`).
    func addToCart(
        item: TrackingItem,
        source: TrackingSource?,
        completion: @escaping (Result<Void, SdkError>) -> Void
    )

    /// Full cart contents after a change (`cart` with `full_cart`).
    ///
    /// Pass an empty array when the cart was emptied — the request then carries an empty `items`
    /// list, which is how the backend learns the cart is gone.
    func syncCart(
        items: [TrackingItem],
        completion: @escaping (Result<Void, SdkError>) -> Void
    )

    /// One product removed from the cart (`remove_from_cart`).
    func removeFromCart(
        itemId: String,
        completion: @escaping (Result<Void, SdkError>) -> Void
    )

    /// One product added to favorites (`wish`).
    func addToFavorites(
        itemId: String,
        source: TrackingSource?,
        completion: @escaping (Result<Void, SdkError>) -> Void
    )

    /// Full favorites contents after a change (`wish` with `full_wish`).
    func syncFavorites(
        itemIds: [String],
        completion: @escaping (Result<Void, SdkError>) -> Void
    )

    /// One product removed from favorites (`remove_wish`).
    func removeFromFavorites(
        itemId: String,
        completion: @escaping (Result<Void, SdkError>) -> Void
    )

    /// A story slide was shown (`track/stories`, `view`).
    ///
    /// `code` is the stories block code; when omitted the SDK uses the code of the block it
    /// last loaded. The block also becomes the attribution source for the events that follow.
    func storyView(
        storyId: String,
        slideId: String,
        code: String?,
        completion: @escaping (Result<Void, SdkError>) -> Void
    )

    /// A story slide was tapped (`track/stories`, `click`).
    func storyClick(
        storyId: String,
        slideId: String,
        code: String?,
        completion: @escaping (Result<Void, SdkError>) -> Void
    )

    /// Completed order (`purchase`).
    func purchase(
        _ request: PurchaseTrackingRequest,
        source: TrackingSource?,
        completion: @escaping (Result<Void, SdkError>) -> Void
    )

    /// Custom event defined by the shop (`push/custom`).
    ///
    /// `customFields` is the one deliberately free-form field: its entries are sent at the top
    /// level and duplicated under `payload`. Reserved keys are rejected.
    func custom(
        event: String,
        time: Int?,
        category: String?,
        label: String?,
        value: Int?,
        customFields: [String: Any]?,
        completion: @escaping (Result<Void, SdkError>) -> Void
    )

    /// Stores the attribution source and attaches it to every event for the next 48 hours.
    ///
    /// Use it when the source outlives a single call — a user entering the catalog from a recommender
    /// block. It is stored per shop and survives a cold start, and it travels in its own `source`
    /// field rather than the `recommended_by` a per-call `source` uses. For a single event prefer
    /// that per-call parameter.
    ///
    /// Same behaviour and same wire shape as Android.
    func setSource(_ source: TrackingSource)
}

/// Default arguments for ``TrackingAPI``. Protocol requirements cannot carry them, so the
/// callable shape lives here — the same pattern the root SDK protocol uses.
public extension TrackingAPI {

    func productView(
        itemId: String,
        source: TrackingSource? = nil,
        completion: @escaping (Result<Void, SdkError>) -> Void = { _ in }
    ) {
        productView(itemId: itemId, source: source, completion: completion)
    }

    func categoryView(
        categoryId: String,
        completion: @escaping (Result<Void, SdkError>) -> Void = { _ in }
    ) {
        categoryView(categoryId: categoryId, completion: completion)
    }

    func search(
        query: String,
        results: [String]? = nil,
        completion: @escaping (Result<Void, SdkError>) -> Void = { _ in }
    ) {
        search(query: query, results: results, completion: completion)
    }

    func addToCart(
        item: TrackingItem,
        source: TrackingSource? = nil,
        completion: @escaping (Result<Void, SdkError>) -> Void = { _ in }
    ) {
        addToCart(item: item, source: source, completion: completion)
    }

    func syncCart(
        items: [TrackingItem],
        completion: @escaping (Result<Void, SdkError>) -> Void = { _ in }
    ) {
        syncCart(items: items, completion: completion)
    }

    func removeFromCart(
        itemId: String,
        completion: @escaping (Result<Void, SdkError>) -> Void = { _ in }
    ) {
        removeFromCart(itemId: itemId, completion: completion)
    }

    func addToFavorites(
        itemId: String,
        source: TrackingSource? = nil,
        completion: @escaping (Result<Void, SdkError>) -> Void = { _ in }
    ) {
        addToFavorites(itemId: itemId, source: source, completion: completion)
    }

    func syncFavorites(
        itemIds: [String],
        completion: @escaping (Result<Void, SdkError>) -> Void = { _ in }
    ) {
        syncFavorites(itemIds: itemIds, completion: completion)
    }

    func removeFromFavorites(
        itemId: String,
        completion: @escaping (Result<Void, SdkError>) -> Void = { _ in }
    ) {
        removeFromFavorites(itemId: itemId, completion: completion)
    }

    func storyView(
        storyId: String,
        slideId: String,
        code: String? = nil,
        completion: @escaping (Result<Void, SdkError>) -> Void = { _ in }
    ) {
        storyView(storyId: storyId, slideId: slideId, code: code, completion: completion)
    }

    func storyClick(
        storyId: String,
        slideId: String,
        code: String? = nil,
        completion: @escaping (Result<Void, SdkError>) -> Void = { _ in }
    ) {
        storyClick(storyId: storyId, slideId: slideId, code: code, completion: completion)
    }

    func purchase(
        _ request: PurchaseTrackingRequest,
        source: TrackingSource? = nil,
        completion: @escaping (Result<Void, SdkError>) -> Void = { _ in }
    ) {
        purchase(request, source: source, completion: completion)
    }

    func custom(
        event: String,
        time: Int? = nil,
        category: String? = nil,
        label: String? = nil,
        value: Int? = nil,
        customFields: [String: Any]? = nil,
        completion: @escaping (Result<Void, SdkError>) -> Void = { _ in }
    ) {
        custom(
            event: event,
            time: time,
            category: category,
            label: label,
            value: value,
            customFields: customFields,
            completion: completion
        )
    }
}
