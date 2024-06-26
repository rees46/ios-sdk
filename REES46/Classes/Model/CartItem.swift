import Foundation

public struct CartItem {
    var productId: String
    var quantity: Int = 1
    
    public init(productId: String, quantity: Int = 1) {
        self.productId = productId
        self.quantity = quantity
    }
    
    public init(json: [String: Any]) {
        self.productId = json["uniqid"] as? String ?? ""
        self.quantity = json["quantity"] as? Int ?? 1
    }
}
