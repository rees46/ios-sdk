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
    /// Hears the contract's result of each event the copy `reporting(to:)` made sends: what
    /// `popupShown` and the `async` forms return. `nil`: only the old completion hears.
    private var accepted: TrackingAccepted?

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

    /// This namespace with every event it sends telling `accepted` the contract's result as well.
    func reporting(to accepted: @escaping TrackingAccepted) -> TrackingAPIImpl {
        var copy = self
        copy.accepted = accepted
        return copy
    }

    func productView(
        itemId: String,
        source: TrackingSource?,
        completion: @escaping (Result<Void, SdkError>) -> Void
    ) {
        guard admits(source, call: "tracking.productView", completion) else { return }
        trackService.track(
            event: .productView(id: itemId),
            source: source?.wire,
            details: .none,
            accepted: accepted,
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
            accepted: accepted,
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
            accepted: accepted,
            completion: completion
        )
    }

    func addToCart(
        item: TrackingItem,
        source: TrackingSource?,
        completion: @escaping (Result<Void, SdkError>) -> Void
    ) {
        guard admits(source, call: "tracking.addToCart", completion) else { return }
        trackService.track(
            event: .productAddedToCart(id: item.id, amount: item.quantity),
            source: source?.wire,
            details: TrackEventDetails(price: item.price, fashionSize: item.fashionSize),
            accepted: accepted,
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
            accepted: accepted,
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
            accepted: accepted,
            completion: completion
        )
    }

    func addToFavorites(
        itemId: String,
        source: TrackingSource?,
        completion: @escaping (Result<Void, SdkError>) -> Void
    ) {
        guard admits(source, call: "tracking.addToFavorites", completion) else { return }
        trackService.track(
            event: .productAddedToFavorites(id: itemId),
            source: source?.wire,
            details: .none,
            accepted: accepted,
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
            accepted: accepted,
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
            accepted: accepted,
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
            accepted: accepted,
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
            accepted: accepted,
            completion: completion
        )
    }

    func purchase(
        _ request: PurchaseTrackingRequest,
        source: TrackingSource?,
        completion: @escaping (Result<Void, SdkError>) -> Void
    ) {
        guard admits(source, call: "tracking.purchase", completion) else { return }
        trackService.trackPurchase(
            request,
            source: source?.wire,
            accepted: accepted,
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
            accepted: accepted,
            completion: completion
        )
    }

    func setSource(_ source: TrackingSource) {
        sourceService.trackSource(type: source.type.rawValue, code: source.code)
    }

    /// `tracking.popupShown`: `popup/showed` as the root `trackPopupShown` sends it, through the queue on
    /// the new core; `accepted` hears the contract's result.
    func sendPopupShown(popupId: Int, accepted: @escaping TrackingAccepted) {
        trackService.trackPopupShown(popupId: popupId, accepted: accepted) { _ in }
    }

    /// The types of a source that name where a stored source came from — a mailing — and not where an
    /// event did: in `recommended_by` the server refuses the whole event (`sdk/contract/tracking.md`).
    /// `setSource` takes them.
    static let notOfAnEvent: Set<TrackingSourceType> = [.transactional, .webPushDigest]

    /// Whether `source` may go with an event. An event with a source of a mailing is not sent: the old
    /// completion and `accepted` hear `invalidArgument` later, as of the core's other refusals.
    private func admits(_ source: TrackingSource?, call: String, _ completion: @escaping (Result<Void, SdkError>) -> Void) -> Bool {
        guard let type = source?.type, Self.notOfAnEvent.contains(type) else { return true }
        let problem = "\(call): \(type.rawValue) is not a source of an event, setSource takes it"
        instance?.logger.warning(LogCode.invalidArgument, problem, ["call": call])
        let accepted = self.accepted
        DispatchQueue.global(qos: .utility).async {
            accepted?(.invalidArgument(problem))
            completion(.failure(.custom(error: problem)))
        }
        return false
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

extension TrackingAPIImpl {

    /// The SDK's own instance behind the services, for the events only its new core sends
    /// (`bannerView`, `bannerClick`); `nil` when the services are another's.
    var instance: SimplePersonalizationSDK? {
        (trackService as? TrackEventServiceImpl)?.instance
    }
}
