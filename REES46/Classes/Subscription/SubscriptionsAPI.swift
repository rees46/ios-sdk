//
//  SubscriptionsAPI.swift
//  REES46
//
//  The `subscriptions` namespace of the contract (`sdk/contract/subscriptions.md`).
//

import Foundation

/**
 The customer's subscriptions: to the channels and kinds of mailings, and to a product's price drop or its
 return to stock. The server finds the customer by the device id; a contact in a request says which
 address or number the subscription is for. Pass a contact only when the app knows it is the customer's:
 the server acts on its owner.

 For the Flutter and React Native bridges, as every namespace but `tracking`: `@_spi(Bridge) import
 REES46` and a shop started with `Rees46.initializeBridge`. On the old core every method ends as
 `notInitialized` and sends nothing.

 Every `completion` is called once, on the main thread, with the value or the error: `notInitialized` on
 the old core or after `release()`, `shopBlocked`, `invalidArgument` — an empty `itemId`, a
 `currentPrice` not above 0, an empty string in `itemIds` or in a contact, `manage` without a flag —
 before anything is sent, `network`, `timeout`, `http(code:serverCode:)`, `decoding`, `cancelled` for a
 call `release()` ended. The `async` forms throw the same `Rees46.SdkError`, and cancelling the task
 ends the call as `cancelled`. Nothing is repeated: the app decides. The server checks the email and the
 phone.
 */
@_spi(Bridge)
public protocol SubscriptionsAPI {

    /// Subscribes the customer to channels and kinds of mailings or unsubscribes them
    /// (`POST subscriptions/manage`): `true` subscribes, `false` unsubscribes, `nil` changes nothing.
    func manage(_ request: Rees46.SubscriptionsUpdateRequest, completion: @escaping (Result<Void, Rees46.SdkError>) -> Void)

    func manage(_ request: Rees46.SubscriptionsUpdateRequest) async throws

    /// The customer's subscriptions on every channel and kind (`GET subscriptions/check`). A device the
    /// server does not know is `http(400)`.
    func check(completion: @escaping (Result<Rees46.SubscriptionStatus, Rees46.SdkError>) -> Void)

    func check() async throws -> Rees46.SubscriptionStatus

    /// Subscribes the customer to the drop of a product's price
    /// (`POST subscriptions/subscribe_for_product_price`); the server ends it once it told them.
    func subscribeForPriceDrop(
        itemId: String,
        currentPrice: Double,
        email: String?,
        phone: String?,
        completion: @escaping (Result<Void, Rees46.SdkError>) -> Void
    )

    func subscribeForPriceDrop(itemId: String, currentPrice: Double, email: String?, phone: String?) async throws

    /// Unsubscribes the customer from the drop of the products' prices
    /// (`POST subscriptions/unsubscribe_from_product_price`): an empty `itemIds` is every product.
    func unsubscribeFromPriceDrop(
        itemIds: [String],
        email: String?,
        phone: String?,
        completion: @escaping (Result<Void, Rees46.SdkError>) -> Void
    )

    func unsubscribeFromPriceDrop(itemIds: [String], email: String?, phone: String?) async throws

    /// Subscribes the customer to a product's return to stock, in the variant of `properties`
    /// (`POST subscriptions/subscribe_for_product_available`); the server ends it once it told them.
    func subscribeForBackInStock(
        itemId: String,
        properties: Rees46.BackInStockProperties?,
        email: String?,
        phone: String?,
        completion: @escaping (Result<Void, Rees46.SdkError>) -> Void
    )

    func subscribeForBackInStock(itemId: String, properties: Rees46.BackInStockProperties?, email: String?, phone: String?) async throws

    /// Unsubscribes the customer from the products' return to stock
    /// (`POST subscriptions/unsubscribe_from_product_available`): an empty `itemIds` is every product.
    func unsubscribeFromBackInStock(
        itemIds: [String],
        email: String?,
        phone: String?,
        completion: @escaping (Result<Void, Rees46.SdkError>) -> Void
    )

    func unsubscribeFromBackInStock(itemIds: [String], email: String?, phone: String?) async throws
}

/// The arguments by default: protocol requirements cannot carry them.
@_spi(Bridge)
extension SubscriptionsAPI {

    public func subscribeForPriceDrop(
        itemId: String,
        currentPrice: Double,
        email: String? = nil,
        phone: String? = nil,
        completion: @escaping (Result<Void, Rees46.SdkError>) -> Void
    ) {
        subscribeForPriceDrop(itemId: itemId, currentPrice: currentPrice, email: email, phone: phone, completion: completion)
    }

    public func subscribeForPriceDrop(itemId: String, currentPrice: Double, email: String? = nil, phone: String? = nil) async throws {
        try await subscribeForPriceDrop(itemId: itemId, currentPrice: currentPrice, email: email, phone: phone)
    }

    public func unsubscribeFromPriceDrop(
        itemIds: [String],
        email: String? = nil,
        phone: String? = nil,
        completion: @escaping (Result<Void, Rees46.SdkError>) -> Void
    ) {
        unsubscribeFromPriceDrop(itemIds: itemIds, email: email, phone: phone, completion: completion)
    }

    public func unsubscribeFromPriceDrop(itemIds: [String], email: String? = nil, phone: String? = nil) async throws {
        try await unsubscribeFromPriceDrop(itemIds: itemIds, email: email, phone: phone)
    }

    public func subscribeForBackInStock(
        itemId: String,
        properties: Rees46.BackInStockProperties? = nil,
        email: String? = nil,
        phone: String? = nil,
        completion: @escaping (Result<Void, Rees46.SdkError>) -> Void
    ) {
        subscribeForBackInStock(itemId: itemId, properties: properties, email: email, phone: phone, completion: completion)
    }

    public func subscribeForBackInStock(
        itemId: String,
        properties: Rees46.BackInStockProperties? = nil,
        email: String? = nil,
        phone: String? = nil
    ) async throws {
        try await subscribeForBackInStock(itemId: itemId, properties: properties, email: email, phone: phone)
    }

    public func unsubscribeFromBackInStock(
        itemIds: [String],
        email: String? = nil,
        phone: String? = nil,
        completion: @escaping (Result<Void, Rees46.SdkError>) -> Void
    ) {
        unsubscribeFromBackInStock(itemIds: itemIds, email: email, phone: phone, completion: completion)
    }

    public func unsubscribeFromBackInStock(itemIds: [String], email: String? = nil, phone: String? = nil) async throws {
        try await unsubscribeFromBackInStock(itemIds: itemIds, email: email, phone: phone)
    }
}

@_spi(Bridge)
extension Rees46 {

    /// What `subscriptions.manage` changes: `true` subscribes, `false` unsubscribes, `nil` is not sent.
    /// The kinds of mailings: `bulk`, mass mailings; `chain`, triggered ones; `transactional`, the
    /// service ones.
    public struct SubscriptionsUpdateRequest: Equatable {
        public var email: String?
        public var phone: String?
        /// The customer's id in the shop's system.
        public var externalId: String?
        /// The id in an external loyalty program.
        public var loyaltyId: String?
        public var telegramId: String?
        public var emailBulk: Bool?
        public var emailChain: Bool?
        public var emailTransactional: Bool?
        public var smsBulk: Bool?
        public var smsChain: Bool?
        public var smsTransactional: Bool?
        public var webPushBulk: Bool?
        public var webPushChain: Bool?
        public var webPushTransactional: Bool?
        public var mobilePushBulk: Bool?
        public var mobilePushChain: Bool?
        public var mobilePushTransactional: Bool?
        public var telegramBulk: Bool?
        public var telegramChain: Bool?
        public var telegramTransactional: Bool?
        public var whatsappBulk: Bool?
        public var whatsappChain: Bool?
        public var whatsappTransactional: Bool?
        public var maxBulk: Bool?
        public var maxChain: Bool?
        public var maxTransactional: Bool?
        public var walletBulk: Bool?
        public var walletChain: Bool?
        public var walletTransactional: Bool?

        public init(
            email: String? = nil,
            phone: String? = nil,
            externalId: String? = nil,
            loyaltyId: String? = nil,
            telegramId: String? = nil,
            emailBulk: Bool? = nil,
            emailChain: Bool? = nil,
            emailTransactional: Bool? = nil,
            smsBulk: Bool? = nil,
            smsChain: Bool? = nil,
            smsTransactional: Bool? = nil,
            webPushBulk: Bool? = nil,
            webPushChain: Bool? = nil,
            webPushTransactional: Bool? = nil,
            mobilePushBulk: Bool? = nil,
            mobilePushChain: Bool? = nil,
            mobilePushTransactional: Bool? = nil,
            telegramBulk: Bool? = nil,
            telegramChain: Bool? = nil,
            telegramTransactional: Bool? = nil,
            whatsappBulk: Bool? = nil,
            whatsappChain: Bool? = nil,
            whatsappTransactional: Bool? = nil,
            maxBulk: Bool? = nil,
            maxChain: Bool? = nil,
            maxTransactional: Bool? = nil,
            walletBulk: Bool? = nil,
            walletChain: Bool? = nil,
            walletTransactional: Bool? = nil
        ) {
            self.email = email
            self.phone = phone
            self.externalId = externalId
            self.loyaltyId = loyaltyId
            self.telegramId = telegramId
            self.emailBulk = emailBulk
            self.emailChain = emailChain
            self.emailTransactional = emailTransactional
            self.smsBulk = smsBulk
            self.smsChain = smsChain
            self.smsTransactional = smsTransactional
            self.webPushBulk = webPushBulk
            self.webPushChain = webPushChain
            self.webPushTransactional = webPushTransactional
            self.mobilePushBulk = mobilePushBulk
            self.mobilePushChain = mobilePushChain
            self.mobilePushTransactional = mobilePushTransactional
            self.telegramBulk = telegramBulk
            self.telegramChain = telegramChain
            self.telegramTransactional = telegramTransactional
            self.whatsappBulk = whatsappBulk
            self.whatsappChain = whatsappChain
            self.whatsappTransactional = whatsappTransactional
            self.maxBulk = maxBulk
            self.maxChain = maxChain
            self.maxTransactional = maxTransactional
            self.walletBulk = walletBulk
            self.walletChain = walletChain
            self.walletTransactional = walletTransactional
        }
    }

    /// The customer's subscriptions: for each channel and kind, whether the customer has the channel's
    /// contact and is subscribed. A field the answer does not have is `false`.
    public struct SubscriptionStatus: Equatable {
        /// Whether the CDP has the customer.
        public let exists: Bool
        public let emailBulk: Bool
        public let emailChain: Bool
        public let emailTransactional: Bool
        public let smsBulk: Bool
        public let smsChain: Bool
        public let smsTransactional: Bool
        public let webPushBulk: Bool
        public let webPushChain: Bool
        public let webPushTransactional: Bool
        public let mobilePushBulk: Bool
        public let mobilePushChain: Bool
        public let mobilePushTransactional: Bool
        public let telegramBulk: Bool
        public let telegramChain: Bool
        public let telegramTransactional: Bool
        public let whatsappBulk: Bool
        public let whatsappChain: Bool
        public let whatsappTransactional: Bool
        public let maxBulk: Bool
        public let maxChain: Bool
        public let maxTransactional: Bool
        public let walletBulk: Bool
        public let walletChain: Bool
        public let walletTransactional: Bool
        /// `web_push`: whether the customer has a working web push token.
        public let hasWebPush: Bool
        /// `mobile_push`: whether the customer has a working mobile push token.
        public let hasMobilePush: Bool
        public let emailInvalid: Bool
        public let emailBlacklisted: Bool
        /// The email does not exist.
        public let emailBounced: Bool
        /// The email is blocked: its subscriptions cannot change.
        public let emailSuppressed: Bool
        public let emailConfirmed: Bool
    }

    /// The variant of a product a subscription to its return to stock is for.
    public struct BackInStockProperties: Equatable {
        public var fashionSize: String?
        public var fashionColor: String?
        public var barcode: String?

        public init(fashionSize: String? = nil, fashionColor: String? = nil, barcode: String? = nil) {
            self.fashionSize = fashionSize
            self.fashionColor = fashionColor
            self.barcode = barcode
        }
    }
}

@_spi(Bridge)
extension PersonalizationSDK {

    /// The customer's subscriptions (`SubscriptionsAPI`): on the new core only.
    public var subscriptions: SubscriptionsAPI {
        SubscriptionsAPIImpl(requests: NamespaceRequests(self), popups: self as? SimplePersonalizationSDK)
    }
}
