//
//  TrackingAsyncAPI.swift
//  REES46
//
//  The `async` forms of the `tracking` namespace (`sdk/contract/tracking.md`).
//

import Foundation

/**
 The methods of ``TrackingAPI`` for `async` code, by the same names and arguments:
 `try await sdk.tracking.async.productView(itemId: id)`. `setSource(_:)` has none: it returns nothing.

 Each returns once the event was accepted — on the new core, the bridges', once the shop's queue has it
 on disk (`sdk/core/queue.md`), not when it was sent; on the old core, which keeps no queue, once the
 server answered — and throws the `Rees46.SdkError` otherwise: `invalidArgument` for an argument the SDK
 refuses — an empty id, a `source` of a mailing, a purchase without items —, `notInitialized`,
 `shopBlocked`; on the old core also `network`, `timeout`, `decoding`. A story slide the server does not
 take — a virtual one — is not sent and returns as accepted.

 Under ``TrackingAPI/async`` and not beside the methods with a `completion`: an `async` method by the same
 name would take over the calls an app already makes from `async` code without a `completion`, which then
 would not compile without `await` and `try`.
 */
public struct TrackingAsyncAPI {

    let tracking: TrackingAPI

    public func productView(itemId: String, source: TrackingSource? = nil) async throws {
        try await accepted { $0.productView(itemId: itemId, source: source, completion: $1) }
    }

    public func categoryView(categoryId: String) async throws {
        try await accepted { $0.categoryView(categoryId: categoryId, completion: $1) }
    }

    public func search(query: String) async throws {
        try await accepted { $0.search(query: query, results: nil, completion: $1) }
    }

    @available(*, deprecated, message: "The server does not read results, and the parameter goes in the major: use search(query:).")
    public func search(query: String, results: [String]?) async throws {
        try await accepted { $0.search(query: query, results: results, completion: $1) }
    }

    public func addToCart(item: TrackingItem, source: TrackingSource? = nil) async throws {
        try await accepted { $0.addToCart(item: item, source: source, completion: $1) }
    }

    public func syncCart(items: [TrackingItem]) async throws {
        try await accepted { $0.syncCart(items: items, completion: $1) }
    }

    public func removeFromCart(itemId: String) async throws {
        try await accepted { $0.removeFromCart(itemId: itemId, completion: $1) }
    }

    public func addToFavorites(itemId: String, source: TrackingSource? = nil) async throws {
        try await accepted { $0.addToFavorites(itemId: itemId, source: source, completion: $1) }
    }

    public func syncFavorites(itemIds: [String]) async throws {
        try await accepted { $0.syncFavorites(itemIds: itemIds, completion: $1) }
    }

    public func removeFromFavorites(itemId: String) async throws {
        try await accepted { $0.removeFromFavorites(itemId: itemId, completion: $1) }
    }

    public func storyView(storyId: String, slideId: String, code: String? = nil) async throws {
        try await accepted { $0.storyView(storyId: storyId, slideId: slideId, code: code, completion: $1) }
    }

    public func storyClick(storyId: String, slideId: String, code: String? = nil) async throws {
        try await accepted { $0.storyClick(storyId: storyId, slideId: slideId, code: code, completion: $1) }
    }

    public func purchase(_ request: PurchaseTrackingRequest, source: TrackingSource? = nil) async throws {
        try await accepted { $0.purchase(request, source: source, completion: $1) }
    }

    public func custom(
        event: String,
        time: Int? = nil,
        category: String? = nil,
        label: String? = nil,
        value: Int? = nil,
        customFields: [String: Any]? = nil
    ) async throws {
        try await accepted {
            $0.custom(event: event, time: time, category: category, label: label, value: value, customFields: customFields, completion: $1)
        }
    }

    public func popupShown(popupId: Int) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            tracking.popupShown(popupId: popupId) { continuation.resume(with: $0) }
        }
    }

    /// Calls `send` — a method of `tracking` with its old `completion` — and returns once the event was
    /// accepted. The SDK's own namespace tells it from the queue; another conformer of the protocol by
    /// the answer its `completion` hears.
    private func accepted(_ send: (TrackingAPI, @escaping (Result<Void, SdkError>) -> Void) -> Void) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let once = ResumeOnce(continuation)
            guard let ours = tracking as? TrackingAPIImpl else {
                send(tracking, TrackingAnswer.telling(once.resume) { _ in })
                return
            }
            send(ours.reporting(to: once.resume)) { _ in }
        }
    }
}

/// `bannerView` and `bannerClick` for `async` code, beside the others: for the bridges, on the new core.
@_spi(Bridge)
extension TrackingAsyncAPI {

    public func bannerView(bannerId: String, code: String) async throws {
        try await tracking.bannerView(bannerId: bannerId, code: code)
    }

    public func bannerClick(bannerId: String, code: String) async throws {
        try await tracking.bannerClick(bannerId: bannerId, code: code)
    }
}

/// Resumes a continuation with the first result it is told; the ones after it are dropped.
private final class ResumeOnce {

    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?

    init(_ continuation: CheckedContinuation<Void, Error>) {
        self.continuation = continuation
    }

    func resume(_ error: Rees46.SdkError?) {
        lock.lock()
        let waiting = continuation
        continuation = nil
        lock.unlock()
        if let error = error {
            waiting?.resume(throwing: error)
        } else {
            waiting?.resume()
        }
    }
}
