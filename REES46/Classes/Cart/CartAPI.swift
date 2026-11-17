//
//  CartAPI.swift
//  REES46
//
//  The `cart` namespace of the contract (`sdk/contract/cart.md`).
//

import Foundation

/**
 The customer's cart as the server keeps it: the server puts it together from the cart events of
 `tracking` (`addToCart`, `syncCart`, `removeFromCart`). For showing a cart filled on another device or
 on the site, or checking it against the app's own.

 For the Flutter and React Native bridges, as every namespace but `tracking`: `@_spi(Bridge) import
 REES46` and a shop started with `Rees46.initializeBridge`. On the old core every method ends as
 `notInitialized` and sends nothing.
 */
@_spi(Bridge)
public protocol CartAPI {

    /**
     What the cart holds (`GET products/cart`): one `CartItem` per product, with its `id` and
     `quantity`; an empty cart is an empty list. The server finds the cart by the device id alone.

     `completion` is called once, on the main thread, with the list or the error: `notInitialized` on
     the old core or after `release()`, `shopBlocked`, `network`, `timeout`, `http(code:serverCode:)` —
     `404` for a device the server does not know —, `decoding` for an answer in neither shape of the
     API, `cancelled` for a call `release()` ended. Nothing is repeated: the app decides.
     */
    func get(completion: @escaping (Result<[CartItem], Rees46.SdkError>) -> Void)

    /// `get(completion:)` for `async` code: throws the `Rees46.SdkError`; cancelling the task ends the
    /// call as `cancelled`.
    func get() async throws -> [CartItem]
}

@_spi(Bridge)
extension PersonalizationSDK {

    /// The customer's cart on the server (`CartAPI`): on the new core only.
    public var cart: CartAPI {
        CartAPIImpl(requests: NamespaceRequests(self))
    }
}

@_spi(Bridge)
extension CartItem {

    /// The product's id (`uniqid` of the answer): the name `cart.get` gives `productId`.
    public var id: String {
        productId
    }
}
