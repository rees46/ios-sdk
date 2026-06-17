import Foundation

/// A single user order returned by `orders/by_user`.
///
/// Monetary fields (`value`, `cashValue`, ...) are returned by the API as strings.
public struct Order {
    public var internalId: Int
    public var id: String
    public var date: String
    public var value: String
    public var cashValue: String?
    public var bonusesValue: String?
    public var deliveryValue: String?
    public var promocode: String?
    public var deliveryDate: String?
    public var internalStatus: String?
    public var stream: String?
    public var channel: String?
    public var taxFree: Bool
    public var deliveryType: String?
    public var deliveryAddress: String?
    public var orderStatus: String?
    public var paymentType: String?
    public var items: [OrderItem]

    init(json: [String: Any]) {
        internalId = json["_id"] as? Int ?? 0
        id = json["id"] as? String ?? ""
        date = json["date"] as? String ?? ""
        value = json["value"] as? String ?? ""
        cashValue = json["cash_value"] as? String
        bonusesValue = json["bonuses_value"] as? String
        deliveryValue = json["delivery_value"] as? String
        promocode = json["promocode"] as? String
        deliveryDate = json["delivery_date"] as? String
        internalStatus = json["internal_status"] as? String
        stream = json["stream"] as? String
        channel = json["channel"] as? String
        taxFree = json["tax_free"] as? Bool ?? false
        deliveryType = json["delivery_type"] as? String
        deliveryAddress = json["delivery_address"] as? String
        orderStatus = json["order_status"] as? String
        paymentType = json["payment_type"] as? String
        let itemsJson = json["items"] as? [[String: Any]] ?? []
        items = itemsJson.map { OrderItem(json: $0) }
    }
}

/// A line item of a user `Order`. `item` is the catalog product (same shape as other product responses).
///
/// `price` / `originalPrice` are returned by the API as strings.
public struct OrderItem {
    public var amount: Int
    public var price: String
    public var status: String?
    public var originalPrice: String?
    public var barcode: String?
    public var lineId: String?
    public var cancelReason: String?
    public var item: Product?

    init(json: [String: Any]) {
        amount = json["amount"] as? Int ?? 0
        price = json["price"] as? String ?? ""
        status = json["status"] as? String
        originalPrice = json["original_price"] as? String
        barcode = json["barcode"] as? String
        lineId = json["line_id"] as? String
        cancelReason = json["cancel_reason"] as? String
        if let itemJson = json["item"] as? [String: Any] {
            item = Product(json: itemJson)
        }
    }
}
