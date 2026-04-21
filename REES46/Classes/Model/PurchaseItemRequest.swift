import Foundation

/// One purchased line item (strict mobile contract).
///
/// Required: `id`, `amount`, `price`.
/// Optional: `quantity`, `lineId`, `fashionSize` — omit from the initializer when unused.
public struct PurchaseItemRequest {
    public let id: String
    public let amount: Int
    public let price: Double
    public let quantity: Int?
    public let lineId: String?
    public let fashionSize: String?

    public init(
        id: String,
        amount: Int,
        price: Double,
        quantity: Int? = nil,
        lineId: String? = nil,
        fashionSize: String? = nil
    ) {
        self.id = id
        self.amount = amount
        self.price = price
        self.quantity = quantity
        self.lineId = lineId
        self.fashionSize = fashionSize
    }
}
