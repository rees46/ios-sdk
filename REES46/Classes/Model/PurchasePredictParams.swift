import Foundation

/// The contacts `getProbabilityToPurchase` once sent. They are no longer sent: the server finds the customer by
/// the device id, which wins over any contact. `shop_id`, `did`, session and `stream` are set by the SDK.
public struct PurchasePredictParams {
    public var email: String?
    public var phone: String?
    public var telegramId: String?
    public var loyaltyId: String?

    public init(
        email: String? = nil,
        phone: String? = nil,
        telegramId: String? = nil,
        loyaltyId: String? = nil
    ) {
        self.email = email
        self.phone = phone
        self.telegramId = telegramId
        self.loyaltyId = loyaltyId
    }
}
