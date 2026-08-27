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

/// Where a tracked action came from — a recommender block, a search result, a story.
///
/// Passed per call to attribute a single event, or stored for subsequent events with
/// ``TrackingAPI/setSource(_:)``.
public struct TrackingSource {
    public let type: RecommendedByCase
    public let code: String

    public init(type: RecommendedByCase, code: String) {
        self.type = type
        self.code = code
    }
}

/// Standard tracking events — the `tracking` namespace of the SDK.
///
/// Reached through an SDK instance: `Rees46.instance().tracking.productView(id: "sku-1")`.
public protocol TrackingAPI {

    /// Product page opened (`view`).
    func productView(
        id: String,
        source: TrackingSource?,
        completion: @escaping (Result<Void, SdkError>) -> Void
    )

    /// Category listing opened (`category`).
    func categoryView(
        id: String,
        completion: @escaping (Result<Void, SdkError>) -> Void
    )

    /// Search query issued by the user (`search`).
    ///
    /// Pass `results` when the host runs its own search and knows the ids it showed.
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
    func syncCart(
        items: [TrackingItem],
        completion: @escaping (Result<Void, SdkError>) -> Void
    )

    /// One product removed from the cart (`remove_from_cart`).
    func removeFromCart(
        id: String,
        completion: @escaping (Result<Void, SdkError>) -> Void
    )

    /// One product added to favorites (`wish`).
    func addToFavorites(
        id: String,
        source: TrackingSource?,
        completion: @escaping (Result<Void, SdkError>) -> Void
    )

    /// Full favorites contents after a change (`wish` with `full_wish`).
    func syncFavorites(
        ids: [String],
        completion: @escaping (Result<Void, SdkError>) -> Void
    )

    /// One product removed from favorites (`remove_wish`).
    func removeFromFavorites(
        id: String,
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

    /// Stores the attribution source for subsequent events (48 hours).
    ///
    /// Use it when the source outlives a single call — a user entering the catalog from a
    /// recommender block. For a single event prefer the `source` parameter.
    func setSource(_ source: TrackingSource)
}

/// Default arguments for ``TrackingAPI``. Protocol requirements cannot carry them, so the
/// callable shape lives here — the same pattern the root SDK protocol uses.
public extension TrackingAPI {

    func productView(
        id: String,
        source: TrackingSource? = nil,
        completion: @escaping (Result<Void, SdkError>) -> Void = { _ in }
    ) {
        productView(id: id, source: source, completion: completion)
    }

    func categoryView(
        id: String,
        completion: @escaping (Result<Void, SdkError>) -> Void = { _ in }
    ) {
        categoryView(id: id, completion: completion)
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
        id: String,
        completion: @escaping (Result<Void, SdkError>) -> Void = { _ in }
    ) {
        removeFromCart(id: id, completion: completion)
    }

    func addToFavorites(
        id: String,
        source: TrackingSource? = nil,
        completion: @escaping (Result<Void, SdkError>) -> Void = { _ in }
    ) {
        addToFavorites(id: id, source: source, completion: completion)
    }

    func syncFavorites(
        ids: [String],
        completion: @escaping (Result<Void, SdkError>) -> Void = { _ in }
    ) {
        syncFavorites(ids: ids, completion: completion)
    }

    func removeFromFavorites(
        id: String,
        completion: @escaping (Result<Void, SdkError>) -> Void = { _ in }
    ) {
        removeFromFavorites(id: id, completion: completion)
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
