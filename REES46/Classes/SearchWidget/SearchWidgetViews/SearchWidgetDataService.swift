import Foundation

struct SearchWidgetDataService {
    static var instance = SearchWidgetDataService()
    
//    private let categories = [
//        ShopCartCaterogy(title: "Boots", imageName: "Boots.jpg"),
//        ShopCartCaterogy(title: "Men shoes", imageName: "Men.jpg"),
//        ShopCartCaterogy(title: "Dress", imageName: "Dress.jpg")
//    ]
    
//    func getCategories() -> [ShopCartCaterogy] {
//        return categories
//    }
//    
//    private(set) public var cart = ShopCart()
//    
//    mutating func addProduct(toCart product: SearchWidgetProductDataPrepare, numberOfProduct: Int, status: Bool) {
//        let selectedProduct =  ShopSelectedProduct(selectedProduct: product, addToCart: status, quantity: numberOfProduct)
//        cart.products.append(selectedProduct)
//    }
//    
//    mutating func removeProduct(fromCart product: SearchWidgetProductDataPrepare?, selectedProduct:  ShopSelectedProduct?) {
//        if let product = product {
//            for (index, value) in cart.products.enumerated() {
//                if value.selectedProduct.title == product.title && value.quantity != 0 {
//                    cart.products.remove(at: index)
//                }
//            }
//            return
//        }
//        if let product = selectedProduct {
//            for (index, value) in cart.products.enumerated() {
//                if value.selectedProduct.title == product.selectedProduct.title && value.quantity != 0 {
//                    cart.products.remove(at: index)
//                }
//            }
//            return
//        }
//        
//    }
//    
//    func getCartProductCount() -> Int {
//        return cart.products.count
//    }
//    
//    func getQuantityCount() -> Int {
//        var count = Int()
//        for (_, product) in cart.products.enumerated() {
//            count += product.quantity
//        }
//        return count
//    }
    
//    func isAddedToCart(_ product: SearchWidgetProductDataPrepare) -> String {
//        if cart.products.isEmpty { return "heart" }
//        for (_, value) in cart.products.enumerated() {
//            if value.selectedProduct.title == product.title && value.addToCart == true {
//                return "heart.fill"
//            }
//        }
//        return "heart"
//    }
//    
//    func isProductInCart(_ product: SearchWidgetProductDataPrepare) -> Bool {
//        for (_, value) in cart.products.enumerated() {
//            if value.selectedProduct.title == product.title && value.addToCart == true {
//                return true
//            }
//        }
//        return false
//    }
//    
//    mutating func updateQuantity(incart withItem:  ShopSelectedProduct?,optionalItem: SearchWidgetProductDataPrepare? = nil , with quantity: Int) {
//        
//        if let product = withItem {
//            for (index, value) in cart.products.enumerated() {
//                if value.selectedProduct.title == product.selectedProduct.title {
//                    cart.products[index].quantity = quantity
//                }
//            }
//            return
//        }
//        
//        if let product = optionalItem {
//            for (index, value) in cart.products.enumerated() {
//                if value.selectedProduct.title == product.title {
//                    cart.products[index].quantity += quantity
//                }
//            }
//            return
//        }
//    }
//    
//    func getTotalAmount() -> Double {
//        var amount = Double()
//        for (_, product) in cart.products.enumerated() {
//            //let p = product.selectedProduct.priceNum
//            amount += Double(product.quantity) * product.selectedProduct.priceNum
//        }
//        return amount
//    }
//    
//    mutating func emptyCart() {
//        cart.products.removeAll()
//    }
}
