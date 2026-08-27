import Foundation

/// Implementation of the `tracking` namespace.
///
/// A lightweight value wrapper that owns no state: every call is routed through the same
/// services the (deprecated) root-level tracking methods use, so behaviour — popup handling,
/// stored-source attribution, session queueing — is byte-for-byte what it was.
struct TrackingAPIImpl: TrackingAPI {

    private let trackService: TrackEventServiceProtocol
    private let sourceService: TrackSourceServiceProtocol

    init(sdk: PersonalizationSDK) {
        self.init(
            trackService: TrackEventServiceImpl(sdk: sdk),
            sourceService: TrackSourceServiceImpl()
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
        id: String,
        source: TrackingSource?,
        completion: @escaping (Result<Void, SdkError>) -> Void
    ) {
        trackService.track(
            event: .productView(id: id),
            recommendedBy: source?.recommendedBy,
            completion: completion
        )
    }

    func categoryView(
        id: String,
        completion: @escaping (Result<Void, SdkError>) -> Void
    ) {
        trackService.track(
            event: .categoryView(id: id),
            recommendedBy: nil,
            completion: completion
        )
    }

    func search(
        query: String,
        results: [String]?,
        completion: @escaping (Result<Void, SdkError>) -> Void
    ) {
        trackService.track(
            event: .search(query: query, results: results),
            recommendedBy: nil,
            completion: completion
        )
    }

    func addToCart(
        item: TrackingItem,
        source: TrackingSource?,
        completion: @escaping (Result<Void, SdkError>) -> Void
    ) {
        trackService.track(
            event: .productAddedToCart(
                id: item.id,
                amount: item.quantity,
                price: item.price
            ),
            recommendedBy: source?.recommendedBy,
            completion: completion
        )
    }

    func syncCart(
        items: [TrackingItem],
        completion: @escaping (Result<Void, SdkError>) -> Void
    ) {
        trackService.track(
            event: .synchronizeCart(items: items.map(\.cartItem)),
            recommendedBy: nil,
            completion: completion
        )
    }

    func removeFromCart(
        id: String,
        completion: @escaping (Result<Void, SdkError>) -> Void
    ) {
        trackService.track(
            event: .productRemovedFromCart(id: id),
            recommendedBy: nil,
            completion: completion
        )
    }

    func addToFavorites(
        id: String,
        source: TrackingSource?,
        completion: @escaping (Result<Void, SdkError>) -> Void
    ) {
        trackService.track(
            event: .productAddedToFavorites(id: id),
            recommendedBy: source?.recommendedBy,
            completion: completion
        )
    }

    func syncFavorites(
        ids: [String],
        completion: @escaping (Result<Void, SdkError>) -> Void
    ) {
        trackService.track(
            event: .synchronizeFavorites(ids: ids),
            recommendedBy: nil,
            completion: completion
        )
    }

    func removeFromFavorites(
        id: String,
        completion: @escaping (Result<Void, SdkError>) -> Void
    ) {
        trackService.track(
            event: .productRemovedFromFavorites(id: id),
            recommendedBy: nil,
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
            event: .slideView(storyId: storyId, slideId: slideId, code: code),
            recommendedBy: nil,
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
            event: .slideClick(storyId: storyId, slideId: slideId, code: code),
            recommendedBy: nil,
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
            recommendedBy: source?.recommendedBy,
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
        sourceService.trackSource(source: source.type, code: source.code)
    }
}

private extension TrackingSource {
    var recommendedBy: RecomendedBy {
        RecomendedBy(type: type, code: code)
    }
}

private extension TrackingItem {
    var cartItem: CartItem {
        CartItem(productId: id, quantity: quantity, price: price)
    }
}
