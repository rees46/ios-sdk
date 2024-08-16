import UIKit

public struct SearchResult {
    let image: String
    let name: String
    let price: Double
    
    public init(image: String, name: String, price: Double) {
        self.image = image
        self.name = name
        self.price = price
    }
}
