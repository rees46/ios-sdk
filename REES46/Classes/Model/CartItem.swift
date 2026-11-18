import Foundation

/// A product in the cart: what the cart events of `tracking` send, and a line of the server's cart
/// (`cart.get`, bridges only).
public struct CartItem {
    var productId: String
    /// How many of the product.
    @_spi(Bridge) public internal(set) var quantity: Int = 1
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
