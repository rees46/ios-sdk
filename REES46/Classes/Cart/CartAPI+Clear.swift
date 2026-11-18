//
//  CartAPI+Clear.swift
//  REES46
//
//  `cart.clear`: a server method with the shop's secret, beside the contract's `cart`.
//

import Foundation

@_spi(Bridge)
extension CartAPI {

    /**
     Empties the customer's cart on the server (`GET products/cart/clear`: the API takes no other verb
     there).

     A server method: it takes the shop's secret key, and a secret in an app's binary gives anyone who
     has the app the server's access to the shop. Whether the SDK keeps such methods is pending in
     DEV-4723. The SDK sends the secret the caller passes, and never stores or logs it.

     The request carries `shop_id`, the secret and the ids given, and none of the device's fields: the
     server finds the customer by `email`, `phone`, `loyaltyId`, `externalId` or `telegramId` only, never
     by the device — one of them is needed. On the new core only, as `cart.get`.

     `completion` is called once, on the main thread: success for the answer `{"status": "success"}`, or
     the error — `invalidArgument` for an empty `shopSecret` or id, or no id at all, before anything is
     sent, `http(403)` for a wrong secret, `http(400)` for a customer the server does not know,
     `decoding` for another `2xx`, `notInitialized` on the old core, `shopBlocked`, `network`, `timeout`,
     `cancelled`.
     */
    public func clear(
        shopSecret: String,
        email: String? = nil,
        phone: String? = nil,
        loyaltyId: String? = nil,
        externalId: String? = nil,
        telegramId: String? = nil,
        completion: @escaping (Result<Void, Rees46.SdkError>) -> Void
    ) {
        guard let requests = (self as? CartAPIImpl)?.requests else {
            return SecretMethods.notImplemented(CartAPIImpl.clearCall, owner: "CartAPI", completion)
        }
        requests.call(CartAPIImpl.clearCall, completion: completion) {
            try CartAPIImpl.clearRequest(
                shopSecret: shopSecret, email: email, phone: phone, loyaltyId: loyaltyId, externalId: externalId, telegramId: telegramId
            )
        }
    }

    /// `clear(shopSecret:…:completion:)` for `async` code: throws the `Rees46.SdkError`; cancelling the
    /// task ends the call as `cancelled`.
    public func clear(
        shopSecret: String,
        email: String? = nil,
        phone: String? = nil,
        loyaltyId: String? = nil,
        externalId: String? = nil,
        telegramId: String? = nil
    ) async throws {
        guard let requests = (self as? CartAPIImpl)?.requests else {
            SecretMethods.notImplemented(CartAPIImpl.clearCall, owner: "CartAPI")
            throw Rees46.SdkError.notInitialized
        }
        try await requests.value(CartAPIImpl.clearCall) {
            try CartAPIImpl.clearRequest(
                shopSecret: shopSecret, email: email, phone: phone, loyaltyId: loyaltyId, externalId: externalId, telegramId: telegramId
            )
        }
    }
}

extension CartAPIImpl {

    static let clearCall = "cart.clear"

    /// `GET products/cart/clear` with the secret and the ids given; a success is `{"status": "success"}`.
    static func clearRequest(
        shopSecret: String,
        email: String?,
        phone: String?,
        loyaltyId: String?,
        externalId: String?,
        telegramId: String?
    ) throws -> ApiRequest<Void> {
        var query = try SecretQuery(shopSecret: shopSecret)
        try query.customer([
            ("email", "email", email), ("phone", "phone", phone), ("loyaltyId", "loyalty_id", loyaltyId),
            ("externalId", "external_id", externalId), ("telegramId", "telegram_id", telegramId),
        ])
        var request = ApiRequest<Void>(method: .get, path: "products/cart/clear", query: query.fields) { body in
            guard try SecretMethods.object(body)["status"] as? String == "success" else {
                throw Rees46.SdkError.decoding
            }
        }
        request.secret = true
        return request
    }
}
