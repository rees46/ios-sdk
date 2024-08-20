import UIKit

public struct SearchResult {
    let image: String
    let name: String
    let price: Double
    let currency: String
    
    public init(image: String, name: String, price: Double, currency:String) {
        self.image = image
        self.name = name
        self.price = price
        self.currency = currency
    }
}
