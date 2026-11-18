//
//  NotificationsAPI+History.swift
//  REES46
//
//  `notifications.getHistory`: a server method with the shop's secret, beside the contract's
//  `notifications`.
//

import Foundation

@_spi(Bridge)
extension NotificationsAPI {

    /**
     The messages the customer was sent (`GET notifications`, the history of the notification centre),
     read as the root `getAllNotifications` reads them: `type` is the kind of mailing (`bulk`, `trigger`,
     `chain`, `transactional`), `channel` its channel, `dateFrom` the first day `YYYY-MM-DD`.

     A server method: it takes the shop's secret key, and a secret in an app's binary gives anyone who
     has the app the server's access to the shop. Whether the SDK keeps such methods is pending in
     DEV-4723. The SDK sends the secret the caller passes, and never stores or logs it.

     The request carries `shop_id`, the secret, the filters and the ids given, under the root method's
     names, and none of the device's fields: the server finds the customer by `phone`, `email`,
     `externalId`, `loyaltyId` or `did` — one of them is needed. On the new core only, as the other
     methods of `notifications`.

     `completion` is called once, on the main thread, with the history or the error: `invalidArgument` —
     an empty `shopSecret`, `type`, `channel` or id, no id at all, no `dateFrom` or one that is not
     `YYYY-MM-DD` (the server needs it), `limit` or `page` below 1 — before anything is sent,
     `http(400)` for a wrong secret, `http(404)` for a customer the server does not know, `decoding` for
     an answer without `payload.messages`, `notInitialized` on the old core, `shopBlocked`, `network`,
     `timeout`, `cancelled`.
     */
    public func getHistory(
        shopSecret: String,
        type: String,
        phone: String? = nil,
        email: String? = nil,
        externalId: String? = nil,
        loyaltyId: String? = nil,
        channel: String? = nil,
        limit: Int? = nil,
        page: Int? = nil,
        dateFrom: String? = nil,
        did: String? = nil,
        completion: @escaping (Result<UserPayloadResponse, Rees46.SdkError>) -> Void
    ) {
        guard let requests = (self as? NotificationsAPIImpl)?.requests else {
            return SecretMethods.notImplemented(NotificationsAPIImpl.getHistoryCall, owner: "NotificationsAPI", completion)
        }
        requests.call(NotificationsAPIImpl.getHistoryCall, completion: completion) {
            try NotificationsAPIImpl.historyRequest(
                shopSecret: shopSecret, type: type, phone: phone, email: email, externalId: externalId, loyaltyId: loyaltyId,
                channel: channel, limit: limit, page: page, dateFrom: dateFrom, did: did
            )
        }
    }

    /// `getHistory(shopSecret:type:…:completion:)` for `async` code: throws the `Rees46.SdkError`;
    /// cancelling the task ends the call as `cancelled`.
    public func getHistory(
        shopSecret: String,
        type: String,
        phone: String? = nil,
        email: String? = nil,
        externalId: String? = nil,
        loyaltyId: String? = nil,
        channel: String? = nil,
        limit: Int? = nil,
        page: Int? = nil,
        dateFrom: String? = nil,
        did: String? = nil
    ) async throws -> UserPayloadResponse {
        guard let requests = (self as? NotificationsAPIImpl)?.requests else {
            SecretMethods.notImplemented(NotificationsAPIImpl.getHistoryCall, owner: "NotificationsAPI")
            throw Rees46.SdkError.notInitialized
        }
        return try await requests.value(NotificationsAPIImpl.getHistoryCall) {
            try NotificationsAPIImpl.historyRequest(
                shopSecret: shopSecret, type: type, phone: phone, email: email, externalId: externalId, loyaltyId: loyaltyId,
                channel: channel, limit: limit, page: page, dateFrom: dateFrom, did: did
            )
        }
    }
}

extension NotificationsAPIImpl {

    static let getHistoryCall = "notifications.getHistory"

    /// `GET notifications` under the root method's names. The answer is
    /// `{"status": "success", "payload": {"messages": [...]}}`; without the list it is `decoding`.
    static func historyRequest(
        shopSecret: String,
        type: String,
        phone: String?,
        email: String?,
        externalId: String?,
        loyaltyId: String?,
        channel: String?,
        limit: Int?,
        page: Int?,
        dateFrom: String?,
        did: String?
    ) throws -> ApiRequest<UserPayloadResponse> {
        var query = try SecretQuery(shopSecret: shopSecret)
        guard !ApiArguments.isBlank(type) else {
            throw Rees46.SdkError.invalidArgument("type is empty")
        }
        try query.set("type", type, "type")
        try query.customer([
            ("phone", "phone", phone), ("email", "email", email), ("externalId", "external_id", externalId),
            ("loyaltyId", "loyalty_id", loyaltyId), ("did", "did", did),
        ])
        guard dateFrom != nil else {
            throw Rees46.SdkError.invalidArgument("dateFrom must be a date YYYY-MM-DD")
        }
        try query.date("date_from", dateFrom, "dateFrom")
        try query.set("channel", channel, "channel")
        try query.positive("limit", limit, "limit")
        try query.positive("page", page, "page")
        var request = ApiRequest<UserPayloadResponse>(method: .get, path: "notifications", query: query.fields) { body in
            guard let payload = try SecretMethods.object(body)["payload"] as? [String: Any], payload["messages"] is [Any] else {
                throw Rees46.SdkError.decoding
            }
            return UserPayloadResponse(json: payload)
        }
        request.secret = true
        return request
    }
}
