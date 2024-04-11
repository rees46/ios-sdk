import Foundation

struct ShopSelectedProduct {
    private(set) public var selectedProduct: ShopCartPrepareProduct
    private(set) public var addToCart = false
    var quantity: Int
}

struct ShopCart {
    var products = [ShopSelectedProduct]()
}
