//
//  SlidersAPI.swift
//  REES46
//
//  The `sliders` namespace of the contract (`sdk/contract/sliders.md`).
//

import Foundation

/**
 Banner sliders: the banners of a slider of the shop's account, for a carousel the app draws. A banner
 shown or tapped is an event of `tracking`: `bannerView(bannerId:code:)` and
 `bannerClick(bannerId:code:)`, with the banner's `id` and `code`.

 For the Flutter and React Native bridges, as every namespace but `tracking`: `@_spi(Bridge) import
 REES46` and a shop started with `Rees46.initializeBridge`. On the old core every method ends as
 `notInitialized` and sends nothing.
 */
@_spi(Bridge)
public protocol SlidersAPI {

    /**
     The banners of the slider `code` for the customer of this device (`GET slider`), chosen by the
     account's settings: the time they show, segments and locations. `tags` narrows them to the
     account's tags; `locationId` is the customer's location (its `external_id`) — a banner for some
     locations is not given without it. A slider without banners is one with an empty list.

     `completion` is called once, on the main thread, with the slider or the error: `invalidArgument`
     for an empty `code`, or a tag that is empty or has a comma — the tags go joined by commas —,
     nothing sent; `notInitialized` on the old core or after `release()`, `shopBlocked`, `network`,
     `timeout`, `http(code:serverCode:)` — `404` for an unknown or inactive slider, `402` for a shop
     without the service, `403` for an unknown or disabled shop —, `decoding` for an answer that is not
     a slider, `cancelled` for a call `release()` ended. Nothing is repeated: the app decides.
     */
    func get(code: String, tags: [String]?, locationId: String?, completion: @escaping (Result<Slider, Rees46.SdkError>) -> Void)

    /// `get(code:tags:locationId:completion:)` for `async` code: throws the `Rees46.SdkError`; cancelling
    /// the task ends the call as `cancelled`.
    func get(code: String, tags: [String]?, locationId: String?) async throws -> Slider
}

/// The default arguments of `SlidersAPI`: a requirement of a protocol cannot have them.
@_spi(Bridge)
extension SlidersAPI {

    public func get(
        code: String,
        tags: [String]? = nil,
        locationId: String? = nil,
        completion: @escaping (Result<Slider, Rees46.SdkError>) -> Void
    ) {
        get(code: code, tags: tags, locationId: locationId, completion: completion)
    }

    public func get(code: String, tags: [String]? = nil, locationId: String? = nil) async throws -> Slider {
        try await get(code: code, tags: tags, locationId: locationId)
    }
}

/// A slider and its banners.
@_spi(Bridge)
public struct Slider {
    public let code: String
    /// The width of the block, in pixels.
    public let width: Int
    /// The height of the block, in pixels.
    public let height: Int
    public let banners: [SliderBanner]
}

/// A banner of a slider.
@_spi(Bridge)
public struct SliderBanner {
    /// The banner's id (`banner_id`) for `tracking.bannerView` and `bannerClick`.
    public let id: String
    /// The slider's code (`recommended_code`), the same for every banner of it: the `code` of the
    /// banner's events.
    public let code: String
    public let imageUrl: String?
    /// The landing page.
    public let url: String?
    public let deeplinkIos: String?
    public let deeplinkAndroid: String?
    /// The banner's own markup.
    public let html: String?
}

@_spi(Bridge)
extension PersonalizationSDK {

    /// Banner sliders (`SlidersAPI`): on the new core only.
    public var sliders: SlidersAPI {
        SlidersAPIImpl(requests: NamespaceRequests(self))
    }
}
