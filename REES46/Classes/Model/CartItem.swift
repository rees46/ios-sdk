import Foundation

public struct CartItem {
    var productId: String
    var quantity: Int = 1
    var price: Double?

    public init(productId: String, quantity: Int = 1, price: Double? = nil) {
        self.productId = productId
        self.quantity = quantity
        self.price = price
    }

    public init(json: [String: Any]) {
        self.productId = json["uniqid"] as? String ?? ""
        self.quantity = json["quantity"] as? Int ?? 1
        self.price = json["price"] as? Double
    }
}
