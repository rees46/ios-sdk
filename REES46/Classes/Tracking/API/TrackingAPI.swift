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
    /// The tool. For a source a bridge made from a value this enum gets only in the major — `slider`,
    /// `agent_search` (``init(rawType:code:)``) — it is `dynamic`, and `rawType` holds the value.
    public let type: TrackingSourceType
    public let code: String
    /// `recommended_by` on the wire: the raw value of `type`, or the one a bridge passed.
    @_spi(Bridge) public let rawType: String

    public init(type: TrackingSourceType, code: String) {
        self.init(type: type, code: code, rawType: type.rawValue)
    }

    private init(type: TrackingSourceType, code: String, rawType: String) {
        self.type = type
        self.code = code
        self.rawType = rawType
    }

    /// Convenience for hosts holding a ``RecommendedByCase`` — the type recommender responses and the
    /// deprecated `trackSource(source:code:)` speak. Labelled `legacy:` rather than overloading
    /// `type:`: the two enums share every case name, so an overload would make `.dynamic` ambiguous.
    public init(legacy type: RecommendedByCase, code: String) {
        self.init(type: TrackingSourceType(type), code: code)
    }
}

@_spi(Bridge)
extension TrackingSource {

    /// The values of `TrackingSourceType` in the contract (`sdk/contract/tracking.md`) that the public
    /// enum gets only in the major: a banner of a slider and an answer of the AI search agent.
    public static let bridgeOnlyRawTypes: Set<String> = ["slider", "agent_search"]

    /**
     A source by the wire value of its type, for the Flutter and React Native bridges: any value of the
     contract's `TrackingSourceType` — the cases of the public enum and `slider`, `agent_search`, which it
     gets with the major. Goes through `tracking` and `tracking.async` as a source of the public type does:
     `recommended_by` is `rawType`, `setSource(_:)` stores it, and a source of a mailing (`transactional`,
     `web_push_digest`) is refused with an event.

     Throws `invalidArgument` for a value the contract does not have, also a case name such as
     `instantSearch`: the wire value is `instant_search`.
     */
    public init(rawType: String, code: String) throws {
        if let type = TrackingSourceType(rawValue: rawType) {
            self.init(type: type, code: code, rawType: type.rawValue)
        } else if Self.bridgeOnlyRawTypes.contains(rawType) {
            self.init(type: .dynamic, code: code, rawType: rawType)
        } else {
            throw Rees46.SdkError.invalidArgument("the source type \(rawType) is not one of the contract's TrackingSourceType")
        }
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
///
/// On the new core, the bridges', an event goes through the shop's queue (`sdk/core/queue.md`): it is
/// kept on the device and sent when it can be, also after no network or a restart. Its `completion` is
/// called when the event was sent — or failed for good, or was refused at once —, and is kept until
/// then: up to seven days, the time an event lives, and not past the instance (`release()`) or the
/// process. Do not hold a screen or another short-lived object in it.
///
/// A `source` of a mailing — `transactional`, `webPushDigest` — is refused with an event: the server
/// refuses the whole event with it in `recommended_by`. The event is not sent, and `completion` hears
/// the refusal; `setSource(_:)` takes these types.
///
/// `popupShown(popupId:completion:)` and the `async` forms under ``async`` return the contract's
/// result instead: that the queue took the event.
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

/// `popupShown` of the contract. An extension, not a requirement: the app's own conformers of
/// ``TrackingAPI`` keep compiling.
public extension TrackingAPI {

    /**
     A popup was shown (`POST popup/showed`): the app calls it for a popup it shows with its own
     interface; the SDK tells the popups it shows itself. `popupId` is the popup's id.

     `completion` is called once, on the main thread. On the new core, the bridges', the event goes
     through the shop's queue and is sent once the device and its session are known: `completion` hears
     when the queue took it — not when it was sent —, or why it did not: `notInitialized` after
     `release()`, `shopBlocked`. On the old core the event is sent at once and `completion` hears the
     server's answer: `network`, `timeout`, `decoding`. An instance the SDK did not make sends nothing:
     `notInitialized`.
     */
    func popupShown(popupId: Int, completion: @escaping (Result<Void, Rees46.SdkError>) -> Void = { _ in }) {
        let finish: TrackingAccepted = { error in
            DispatchQueue.main.async { completion(error.map { .failure($0) } ?? .success(())) }
        }
        guard let ours = self as? TrackingAPIImpl else {
            SdkLogger.process.error(LogCode.notImplemented, "tracking.popupShown is not implemented by this TrackingAPI", ["call": "tracking.popupShown"])
            finish(.notInitialized)
            return
        }
        ours.sendPopupShown(popupId: popupId, accepted: finish)
    }

    /// The `async` forms of these methods: `try await sdk.tracking.async.productView(itemId: id)`.
    var async: TrackingAsyncAPI {
        TrackingAsyncAPI(tracking: self)
    }
}
