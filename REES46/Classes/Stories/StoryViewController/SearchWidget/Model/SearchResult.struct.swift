import UIKit

public struct SearchResult {
    let query: String?
    let id: String
    let image: String
    let name: String
    let price: Double
    let currency: String
    let rating: Int
    public var filters: [String: Filter]?
    
    public init(
        query: String?,
        id: String,
        image: String,
        name: String,
        price: Double,
        currency: String,
        rating: Int,
        filters: [String: Filter]? = nil
    ) {
        self.query = query
        self.id = id
        self.image = image
        self.name = name
        self.price = price
        self.currency = currency
        self.rating = rating
        self.filters = filters
    }
}
