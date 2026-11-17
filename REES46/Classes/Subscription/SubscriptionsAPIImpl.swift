//
//  SubscriptionsAPIImpl.swift
//  REES46
//

import Foundation

struct SubscriptionsAPIImpl: SubscriptionsAPI {

    let requests: NamespaceRequests
    /// The instance whose popups v3 hear that the subscriptions changed.
    weak var popups: SimplePersonalizationSDK?

    func manage(_ request: Rees46.SubscriptionsUpdateRequest, completion: @escaping (Result<Void, Rees46.SdkError>) -> Void) {
        requests.call("subscriptions.manage", completion: completion) { try changing(Self.manageRequest(request)) }
    }

    func manage(_ request: Rees46.SubscriptionsUpdateRequest) async throws {
        try await requests.value("subscriptions.manage") { try changing(Self.manageRequest(request)) }
    }

    func check(completion: @escaping (Result<Rees46.SubscriptionStatus, Rees46.SdkError>) -> Void) {
        requests.call("subscriptions.check", completion: completion) { Self.checkRequest }
    }

    func check() async throws -> Rees46.SubscriptionStatus {
        try await requests.value("subscriptions.check") { Self.checkRequest }
    }

    func subscribeForPriceDrop(
        itemId: String,
        currentPrice: Double,
        email: String?,
        phone: String?,
        completion: @escaping (Result<Void, Rees46.SdkError>) -> Void
    ) {
        requests.call("subscriptions.subscribeForPriceDrop", completion: completion) {
            try Self.priceDropRequest(itemId: itemId, currentPrice: currentPrice, email: email, phone: phone)
        }
    }

    func subscribeForPriceDrop(itemId: String, currentPrice: Double, email: String?, phone: String?) async throws {
        try await requests.value("subscriptions.subscribeForPriceDrop") {
            try Self.priceDropRequest(itemId: itemId, currentPrice: currentPrice, email: email, phone: phone)
        }
    }

    func unsubscribeFromPriceDrop(
        itemIds: [String],
        email: String?,
        phone: String?,
        completion: @escaping (Result<Void, Rees46.SdkError>) -> Void
    ) {
        requests.call("subscriptions.unsubscribeFromPriceDrop", completion: completion) {
            try Self.unsubscribeRequest("subscriptions/unsubscribe_from_product_price", itemIds: itemIds, email: email, phone: phone)
        }
    }

    func unsubscribeFromPriceDrop(itemIds: [String], email: String?, phone: String?) async throws {
        try await requests.value("subscriptions.unsubscribeFromPriceDrop") {
            try Self.unsubscribeRequest("subscriptions/unsubscribe_from_product_price", itemIds: itemIds, email: email, phone: phone)
        }
    }

    func subscribeForBackInStock(
        itemId: String,
        properties: Rees46.BackInStockProperties?,
        email: String?,
        phone: String?,
        completion: @escaping (Result<Void, Rees46.SdkError>) -> Void
    ) {
        requests.call("subscriptions.subscribeForBackInStock", completion: completion) {
            try Self.backInStockRequest(itemId: itemId, properties: properties, email: email, phone: phone)
        }
    }

    func subscribeForBackInStock(itemId: String, properties: Rees46.BackInStockProperties?, email: String?, phone: String?) async throws {
        try await requests.value("subscriptions.subscribeForBackInStock") {
            try Self.backInStockRequest(itemId: itemId, properties: properties, email: email, phone: phone)
        }
    }

    func unsubscribeFromBackInStock(
        itemIds: [String],
        email: String?,
        phone: String?,
        completion: @escaping (Result<Void, Rees46.SdkError>) -> Void
    ) {
        requests.call("subscriptions.unsubscribeFromBackInStock", completion: completion) {
            try Self.unsubscribeRequest("subscriptions/unsubscribe_from_product_available", itemIds: itemIds, email: email, phone: phone)
        }
    }

    func unsubscribeFromBackInStock(itemIds: [String], email: String?, phone: String?) async throws {
        try await requests.value("subscriptions.unsubscribeFromBackInStock") {
            try Self.unsubscribeRequest("subscriptions/unsubscribe_from_product_available", itemIds: itemIds, email: email, phone: phone)
        }
    }

    /// `request` once it is on its way: popups v3 load their list anew for subscriptions new in the
    /// session, as for the old `manageSubscription`.
    private func changing(_ request: ApiRequest<Void>) -> ApiRequest<Void> {
        popups?.popupsV3.contextChanged("subscription", signature: ClientBody.signature(request.body))
        return request
    }

    // MARK: - Requests

    /// The flags of `SubscriptionsUpdateRequest` and `SubscriptionStatus` by their names on the wire.
    static let flags: [(name: String, request: KeyPath<Rees46.SubscriptionsUpdateRequest, Bool?>)] = [
        ("email_bulk", \.emailBulk), ("email_chain", \.emailChain), ("email_transactional", \.emailTransactional),
        ("sms_bulk", \.smsBulk), ("sms_chain", \.smsChain), ("sms_transactional", \.smsTransactional),
        ("web_push_bulk", \.webPushBulk), ("web_push_chain", \.webPushChain), ("web_push_transactional", \.webPushTransactional),
        ("mobile_push_bulk", \.mobilePushBulk), ("mobile_push_chain", \.mobilePushChain),
        ("mobile_push_transactional", \.mobilePushTransactional),
        ("telegram_bulk", \.telegramBulk), ("telegram_chain", \.telegramChain), ("telegram_transactional", \.telegramTransactional),
        ("whatsapp_bulk", \.whatsappBulk), ("whatsapp_chain", \.whatsappChain), ("whatsapp_transactional", \.whatsappTransactional),
        ("max_bulk", \.maxBulk), ("max_chain", \.maxChain), ("max_transactional", \.maxTransactional),
        ("wallet_bulk", \.walletBulk), ("wallet_chain", \.walletChain), ("wallet_transactional", \.walletTransactional)
    ]

    /// `POST subscriptions/manage` with the contacts and the flags given; without a flag there is
    /// nothing to change.
    static func manageRequest(_ request: Rees46.SubscriptionsUpdateRequest) throws -> ApiRequest<Void> {
        var body = ClientBody()
        try body.identifier("email", request.email, "email")
        try body.identifier("phone", request.phone, "phone")
        try body.identifier("external_id", request.externalId, "externalId")
        try body.identifier("loyalty_id", request.loyaltyId, "loyaltyId")
        try body.identifier("telegram_id", request.telegramId, "telegramId")
        var changes = 0
        for flag in flags {
            if let value = request[keyPath: flag.request] {
                body.set(flag.name, value)
                changes += 1
            }
        }
        guard changes > 0 else {
            throw Rees46.SdkError.invalidArgument("the request changes no subscription")
        }
        return ApiRequest(method: .post, path: "subscriptions/manage", body: body.fields) { _ in () }
    }

    /// `GET subscriptions/check`: the customer of the device. An answer without a body has no
    /// subscription.
    static var checkRequest: ApiRequest<Rees46.SubscriptionStatus> {
        ApiRequest(method: .get, path: "subscriptions/check") { body in
            try Readable<Rees46.SubscriptionStatus>.read(body.isEmpty ? Data("{}".utf8) : body)
        }
    }

    /// `POST subscriptions/subscribe_for_product_price`: the product as `item_id`; the price goes as
    /// `price`, which the server takes from the catalog instead.
    static func priceDropRequest(itemId: String, currentPrice: Double, email: String?, phone: String?) throws -> ApiRequest<Void> {
        let id = try CatalogQuery.identifier(itemId, "itemId")
        var body = ClientBody(["item_id": id])
        guard currentPrice.isFinite, currentPrice > 0 else {
            throw Rees46.SdkError.invalidArgument("currentPrice must be above 0")
        }
        body.set("price", currentPrice)
        try body.identifier("email", email, "email")
        try body.identifier("phone", phone, "phone")
        return ApiRequest(method: .post, path: "subscriptions/subscribe_for_product_price", body: body.fields) { _ in () }
    }

    /// `POST subscriptions/subscribe_for_product_available`: the product as `item_id`, its variant in
    /// `properties` when it has a field.
    static func backInStockRequest(
        itemId: String,
        properties: Rees46.BackInStockProperties?,
        email: String?,
        phone: String?
    ) throws -> ApiRequest<Void> {
        let id = try CatalogQuery.identifier(itemId, "itemId")
        var body = ClientBody(["item_id": id])
        var variant = ClientBody()
        variant.set("fashion_size", properties?.fashionSize.flatMap(Self.nonEmpty))
        variant.set("fashion_color", properties?.fashionColor.flatMap(Self.nonEmpty))
        variant.set("barcode", properties?.barcode.flatMap(Self.nonEmpty))
        if !variant.fields.isEmpty {
            body.set("properties", variant.fields)
        }
        try body.identifier("email", email, "email")
        try body.identifier("phone", phone, "phone")
        return ApiRequest(method: .post, path: "subscriptions/subscribe_for_product_available", body: body.fields) { _ in () }
    }

    /// A request of `path` that unsubscribes from the products of `itemIds`, one value joined by `,` —
    /// the only form the server reads —; an empty list is every product.
    static func unsubscribeRequest(_ path: String, itemIds: [String], email: String?, phone: String?) throws -> ApiRequest<Void> {
        guard itemIds.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw Rees46.SdkError.invalidArgument("itemIds has an empty id")
        }
        var body = ClientBody(["item_ids": itemIds.joined(separator: ",")])
        try body.identifier("email", email, "email")
        try body.identifier("phone", phone, "phone")
        return ApiRequest(method: .post, path: path, body: body.fields) { _ in () }
    }

    private static func nonEmpty(_ value: String) -> String? {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : value
    }
}

extension Rees46.SubscriptionStatus: AnswerReadable {

    init(answer: KeyedDecodingContainer<AnswerKey>) throws {
        func flag(_ name: AnswerKey) -> Bool {
            answer.lenientBool(name) ?? false
        }
        exists = flag("exists")
        emailBulk = flag("email_bulk")
        emailChain = flag("email_chain")
        emailTransactional = flag("email_transactional")
        smsBulk = flag("sms_bulk")
        smsChain = flag("sms_chain")
        smsTransactional = flag("sms_transactional")
        webPushBulk = flag("web_push_bulk")
        webPushChain = flag("web_push_chain")
        webPushTransactional = flag("web_push_transactional")
        mobilePushBulk = flag("mobile_push_bulk")
        mobilePushChain = flag("mobile_push_chain")
        mobilePushTransactional = flag("mobile_push_transactional")
        telegramBulk = flag("telegram_bulk")
        telegramChain = flag("telegram_chain")
        telegramTransactional = flag("telegram_transactional")
        whatsappBulk = flag("whatsapp_bulk")
        whatsappChain = flag("whatsapp_chain")
        whatsappTransactional = flag("whatsapp_transactional")
        maxBulk = flag("max_bulk")
        maxChain = flag("max_chain")
        maxTransactional = flag("max_transactional")
        walletBulk = flag("wallet_bulk")
        walletChain = flag("wallet_chain")
        walletTransactional = flag("wallet_transactional")
        hasWebPush = flag("web_push")
        hasMobilePush = flag("mobile_push")
        emailInvalid = flag("email_invalid")
        emailBlacklisted = flag("email_blacklisted")
        emailBounced = flag("email_bounced")
        emailSuppressed = flag("email_suppressed")
        emailConfirmed = flag("email_confirmed")
    }
}
