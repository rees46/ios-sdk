//
//  TrackingAPI+Banners.swift
//  REES46
//
//  The events of the banners of a slider (`sdk/contract/tracking.md`, `bannerView` and `bannerClick`;
//  `sdk/contract/sliders.md`): for the bridges, on the new core only.
//

import Foundation

/**
 A banner of a slider (`sliders.get`) shown or tapped. For the Flutter and React Native bridges:
 `@_spi(Bridge) import REES46` and a shop started with `Rees46.initializeBridge`.

 The event goes through the shop's queue (`sdk/core/queue.md`), as every event of `tracking` does on
 the new core: kept on the device and sent once the device is known to the server, after no network or
 a restart too. `completion` is called once, on the main thread, when the queue took the event — not when
 it was sent —, or with why it did not: `invalidArgument` for a `bannerId` that is not a positive whole
 number, or an empty `code`; `notInitialized` on the old core, which sends nothing, or after
 `release()`; `shopBlocked`.
 */
@_spi(Bridge)
extension TrackingAPI {

    /// A banner was shown (`POST track/slider`, `event=view`): once, when it first became visible in
    /// this showing of the slider. `bannerId` and `code` are the banner's `SliderBanner.id` and
    /// `SliderBanner.code`.
    public func bannerView(
        bannerId: String,
        code: String,
        completion: @escaping (Result<Void, Rees46.SdkError>) -> Void = { _ in }
    ) {
        BannerEvent.view.send(bannerId: bannerId, code: code, by: self, completion: completion)
    }

    /// A banner was tapped (`POST track/slider`, `event=click`). `bannerId` and `code` are the banner's
    /// `SliderBanner.id` and `SliderBanner.code`.
    public func bannerClick(
        bannerId: String,
        code: String,
        completion: @escaping (Result<Void, Rees46.SdkError>) -> Void = { _ in }
    ) {
        BannerEvent.click.send(bannerId: bannerId, code: code, by: self, completion: completion)
    }

    /// `bannerView(bannerId:code:completion:)` for `async` code: returns once the queue took the event,
    /// throws the `Rees46.SdkError` otherwise.
    public func bannerView(bannerId: String, code: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            bannerView(bannerId: bannerId, code: code) { continuation.resume(with: $0) }
        }
    }

    /// `bannerClick(bannerId:code:completion:)` for `async` code: returns once the queue took the event,
    /// throws the `Rees46.SdkError` otherwise.
    public func bannerClick(bannerId: String, code: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            bannerClick(bannerId: bannerId, code: code) { continuation.resume(with: $0) }
        }
    }
}

/// An event of a banner: its `event` on the wire.
enum BannerEvent: String {
    case view
    case click

    static let path = "track/slider"

    /// The method's name in the log.
    var call: String {
        switch self {
        case .view: return "tracking.bannerView"
        case .click: return "tracking.bannerClick"
        }
    }

    /// The largest `banner_id` the server takes: an unsigned 32-bit number.
    static let maxBannerId = 4_294_967_295

    /// The event's own fields: `banner_id` a number, `recommended_code` the slider's code. No
    /// `recommended_by`: the address does not read it. The queue adds the shop, the device and the
    /// session when the event goes.
    func body(bannerId: String, code: String) throws -> [String: Any] {
        guard !bannerId.isEmpty else {
            throw Rees46.SdkError.invalidArgument("the banner id must not be empty")
        }
        guard bannerId.allSatisfy({ ("0"..."9").contains($0) }), let id = Int(bannerId), (1...Self.maxBannerId).contains(id) else {
            throw Rees46.SdkError.invalidArgument("the banner id must be a positive whole number")
        }
        guard !ApiArguments.isBlank(code) else {
            throw Rees46.SdkError.invalidArgument("the code of the slider must not be empty")
        }
        return ["event": rawValue, "banner_id": id, "recommended_code": code]
    }

    /// Hands the event to the queue of the instance behind `api`; `completion` hears, on the main
    /// thread, when the queue took it or why not.
    func send(bannerId: String, code: String, by api: TrackingAPI, completion: @escaping (Result<Void, Rees46.SdkError>) -> Void) {
        let finish: (Rees46.SdkError?) -> Void = { error in
            DispatchQueue.main.async { completion(error.map { .failure($0) } ?? .success(())) }
        }
        let ours = (api as? TrackingAPIImpl)?.instance
        guard let instance = NamespaceRequests.onTheNewCore(ours, isTheSdks: false, call: call, owner: "TrackingAPI") else {
            finish(.notInitialized)
            return
        }
        let fields: [String: Any]
        do {
            fields = try body(bannerId: bannerId, code: code)
        } catch {
            let refusal = error as? Rees46.SdkError ?? .invalidArgument(String(describing: error))
            instance.logger.warning(LogCode.invalidArgument, "\(call): \(refusal.message)", ["call": call])
            finish(refusal)
            return
        }
        // `accepted`: the event is on disk, or why the queue refused it (released, a refused shop).
        guard instance.enqueueEvent(path: Self.path, body: fields, accepted: finish, completion: { _ in }) else {
            finish(.notInitialized)
            return
        }
    }
}
