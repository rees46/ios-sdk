import Foundation

/// Strict purchase tracking request for `push` (`event` = `purchase`).
///
/// Required: `orderId`, `orderPrice`, `items`.
/// Optional fields default to `nil` / `false` — omit them from the initializer when unused.
public struct PurchaseTrackingRequest {
    public let orderId: String
    public let orderPrice: Double
    public let items: [PurchaseItemRequest]

    public let deliveryType: String?
    public let deliveryAddress: String?
    public let paymentType: String?
    public let isTaxFree: Bool

    public let promocode: String?
    public let orderCash: Double?
    public let orderBonuses: Double?
    public let orderDelivery: Double?
    public let orderDiscount: Double?
    public let channel: String?

    public let custom: [String: Any]?
    public let recommendedSource: [String: Any]?

    public let stream: String?
    public let segment: String?

    public init(
        orderId: String,
        orderPrice: Double,
        items: [PurchaseItemRequest],
        deliveryType: String? = nil,
        deliveryAddress: String? = nil,
        paymentType: String? = nil,
        isTaxFree: Bool = false,
        promocode: String? = nil,
        orderCash: Double? = nil,
        orderBonuses: Double? = nil,
        orderDelivery: Double? = nil,
        orderDiscount: Double? = nil,
        channel: String? = nil,
        custom: [String: Any]? = nil,
        recommendedSource: [String: Any]? = nil,
        stream: String? = nil,
        segment: String? = nil
    ) {
        self.orderId = orderId
        self.orderPrice = orderPrice
        self.items = items
        self.deliveryType = deliveryType
        self.deliveryAddress = deliveryAddress
        self.paymentType = paymentType
        self.isTaxFree = isTaxFree
        self.promocode = promocode
        self.orderCash = orderCash
        self.orderBonuses = orderBonuses
        self.orderDelivery = orderDelivery
        self.orderDiscount = orderDiscount
        self.channel = channel
        self.custom = custom
        self.recommendedSource = recommendedSource
        self.stream = stream
        self.segment = segment
    }
}
