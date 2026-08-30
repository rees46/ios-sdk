import Foundation

/// Implementation of the `tracking` namespace.
///
/// A lightweight value wrapper that owns no state: every call is routed through the same
/// `TrackEventService` / `TrackSourceService` instances the (deprecated) root-level tracking methods
/// use — `SimplePersonalizationSDK` hands its own lazy services to this type — so behaviour (popup
/// handling, stored-source attribution, session queueing) is one code path, not two.
struct TrackingAPIImpl: TrackingAPI {

    private let trackService: TrackEventServiceProtocol
    private let sourceService: TrackSourceServiceProtocol

    /// Fallback used by the `PersonalizationSDK.tracking` default, which sees only the public protocol
    /// and so has to build its own services. `SimplePersonalizationSDK` overrides `tracking` and uses
    /// the initializer below instead.
    init(sdk: PersonalizationSDK) {
        self.init(
            trackService: TrackEventServiceImpl(sdk: sdk),
            sourceService: TrackSourceServiceImpl(store: sdk.trackingSourceStore)
        )
    }

    init(
        trackService: TrackEventServiceProtocol,
        sourceService: TrackSourceServiceProtocol
    ) {
        self.trackService = trackService
        self.sourceService = sourceService
    }

    func productView(
        itemId: String,
        source: TrackingSource?,
        completion: @escaping (Result<Void, SdkError>) -> Void
    ) {
        trackService.track(
            event: .productView(id: itemId),
            source: source?.wire,
            details: .none,
            completion: completion
        )
    }

    func categoryView(
        categoryId: String,
        completion: @escaping (Result<Void, SdkError>) -> Void
    ) {
        trackService.track(
            event: .categoryView(id: categoryId),
            source: nil,
            details: .none,
            completion: completion
        )
    }

    func search(
        query: String,
        results: [String]?,
        completion: @escaping (Result<Void, SdkError>) -> Void
    ) {
        trackService.track(
            event: .search(query: query),
            source: nil,
            details: TrackEventDetails(results: results),
            completion: completion
        )
    }

    func addToCart(
        item: TrackingItem,
        source: TrackingSource?,
        completion: @escaping (Result<Void, SdkError>) -> Void
    ) {
        trackService.track(
            event: .productAddedToCart(id: item.id, amount: item.quantity),
            source: source?.wire,
            details: TrackEventDetails(price: item.price),
            completion: completion
        )
    }

    func syncCart(
        items: [TrackingItem],
        completion: @escaping (Result<Void, SdkError>) -> Void
    ) {
        trackService.track(
            event: .synchronizeCart(items: items.map(\.cartItem)),
            source: nil,
            details: .none,
            completion: completion
        )
    }

    func removeFromCart(
        itemId: String,
        completion: @escaping (Result<Void, SdkError>) -> Void
    ) {
        trackService.track(
            event: .productRemovedFromCart(id: itemId),
            source: nil,
            details: .none,
            completion: completion
        )
    }

    func addToFavorites(
        itemId: String,
        source: TrackingSource?,
        completion: @escaping (Result<Void, SdkError>) -> Void
    ) {
        trackService.track(
            event: .productAddedToFavorites(id: itemId),
            source: source?.wire,
            details: .none,
            completion: completion
        )
    }

    func syncFavorites(
        itemIds: [String],
        completion: @escaping (Result<Void, SdkError>) -> Void
    ) {
        trackService.track(
            event: .synchronizeFavorites(ids: itemIds),
            source: nil,
            details: .none,
            completion: completion
        )
    }

    func removeFromFavorites(
        itemId: String,
        completion: @escaping (Result<Void, SdkError>) -> Void
    ) {
        trackService.track(
            event: .productRemovedFromFavorites(id: itemId),
            source: nil,
            details: .none,
            completion: completion
        )
    }

    func storyView(
        storyId: String,
        slideId: String,
        code: String?,
        completion: @escaping (Result<Void, SdkError>) -> Void
    ) {
        trackService.track(
            event: .slideView(storyId: storyId, slideId: slideId),
            source: nil,
            details: TrackEventDetails(storiesCode: code),
            completion: completion
        )
    }

    func storyClick(
        storyId: String,
        slideId: String,
        code: String?,
        completion: @escaping (Result<Void, SdkError>) -> Void
    ) {
        trackService.track(
            event: .slideClick(storyId: storyId, slideId: slideId),
            source: nil,
            details: TrackEventDetails(storiesCode: code),
            completion: completion
        )
    }

    func purchase(
        _ request: PurchaseTrackingRequest,
        source: TrackingSource?,
        completion: @escaping (Result<Void, SdkError>) -> Void
    ) {
        trackService.trackPurchase(
            request,
            source: source?.wire,
            completion: completion
        )
    }

    func custom(
        event: String,
        time: Int?,
        category: String?,
        label: String?,
        value: Int?,
        customFields: [String: Any]?,
        completion: @escaping (Result<Void, SdkError>) -> Void
    ) {
        trackService.trackEvent(
            event: event,
            time: time,
            category: category,
            label: label,
            value: value,
            customFields: customFields,
            completion: completion
        )
    }

    func setSource(_ source: TrackingSource) {
        sourceService.trackSource(type: source.type.rawValue, code: source.code)
    }
}

private extension TrackingSource {
    var wire: TrackingSourceWire {
        TrackingSourceWire(type: type.rawValue, code: code)
    }
}

private extension TrackingItem {
    var cartItem: CartItem {
        CartItem(productId: id, quantity: quantity, price: price)
    }
}
