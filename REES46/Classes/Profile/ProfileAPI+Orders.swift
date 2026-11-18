//
//  ProfileAPI+Orders.swift
//  REES46
//
//  `profile.getOrders`: a server method with the shop's secret, beside the contract's `profile`.
//

import Foundation

@_spi(Bridge)
extension ProfileAPI {

    /**
     The customer's orders since `dateFrom` (`GET orders/by_user`), oldest first, as the root
     `getUserOrders` reads them; the server takes the last month without `dateFrom`.

     A server method: it takes the shop's secret key, and a secret in an app's binary gives anyone who
     has the app the server's access to the shop. Whether the SDK keeps such methods is pending in
     DEV-4723. The SDK sends the secret the caller passes, and never stores or logs it.

     The request carries `shop_id`, the secret and the ids given, and none of the device's fields: the
     server finds the customer by `did`, `email`, `phone`, `loyaltyId` or `externalId` — one of them is
     needed. On the new core only, as the other methods of `profile`.

     `completion` is called once, on the main thread, with the orders or the error: `invalidArgument` —
     an empty `shopSecret` or id, no id at all, a `dateFrom` that is not `YYYY-MM-DD` — before anything
     is sent, `http(403)` for a wrong secret, `http(400)` for a customer the server does not know,
     `decoding` for an answer without `data.orders`, `notInitialized` on the old core, `shopBlocked`,
     `network`, `timeout`, `cancelled`.
     */
    public func getOrders(
        shopSecret: String,
        did: String? = nil,
        email: String? = nil,
        phone: String? = nil,
        loyaltyId: String? = nil,
        externalId: String? = nil,
        dateFrom: String? = nil,
        completion: @escaping (Result<[Order], Rees46.SdkError>) -> Void
    ) {
        guard let requests = (self as? ProfileAPIImpl)?.requests else {
            return SecretMethods.notImplemented(ProfileAPIImpl.getOrdersCall, owner: "ProfileAPI", completion)
        }
        requests.call(ProfileAPIImpl.getOrdersCall, completion: completion) {
            try ProfileAPIImpl.ordersRequest(
                shopSecret: shopSecret, did: did, email: email, phone: phone, loyaltyId: loyaltyId, externalId: externalId, dateFrom: dateFrom
            )
        }
    }

    /// `getOrders(shopSecret:…:completion:)` for `async` code: throws the `Rees46.SdkError`; cancelling the
    /// task ends the call as `cancelled`.
    public func getOrders(
        shopSecret: String,
        did: String? = nil,
        email: String? = nil,
        phone: String? = nil,
        loyaltyId: String? = nil,
        externalId: String? = nil,
        dateFrom: String? = nil
    ) async throws -> [Order] {
        guard let requests = (self as? ProfileAPIImpl)?.requests else {
            SecretMethods.notImplemented(ProfileAPIImpl.getOrdersCall, owner: "ProfileAPI")
            throw Rees46.SdkError.notInitialized
        }
        return try await requests.value(ProfileAPIImpl.getOrdersCall) {
            try ProfileAPIImpl.ordersRequest(
                shopSecret: shopSecret, did: did, email: email, phone: phone, loyaltyId: loyaltyId, externalId: externalId, dateFrom: dateFrom
            )
        }
    }
}

extension ProfileAPIImpl {

    static let getOrdersCall = "profile.getOrders"

    /// `GET orders/by_user` with the secret and the ids given. The answer is
    /// `{"status": "success", "data": {"orders": [...]}}`, an order with more fields than `Order` reads
    /// and its sums as strings; without the list it is `decoding`.
    static func ordersRequest(
        shopSecret: String,
        did: String?,
        email: String?,
        phone: String?,
        loyaltyId: String?,
        externalId: String?,
        dateFrom: String?
    ) throws -> ApiRequest<[Order]> {
        var query = try SecretQuery(shopSecret: shopSecret)
        try query.customer([
            ("did", "did", did), ("email", "email", email), ("phone", "phone", phone),
            ("loyaltyId", "loyalty_id", loyaltyId), ("externalId", "external_id", externalId),
        ])
        try query.date("date_from", dateFrom, "dateFrom")
        var request = ApiRequest<[Order]>(method: .get, path: "orders/by_user", query: query.fields) { body in
            guard let orders = (try SecretMethods.object(body)["data"] as? [String: Any])?["orders"] as? [[String: Any]] else {
                throw Rees46.SdkError.decoding
            }
            return orders.map(Order.init(json:))
        }
        request.secret = true
        return request
    }
}
