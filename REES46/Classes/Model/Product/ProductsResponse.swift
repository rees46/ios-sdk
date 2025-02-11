import Foundation

public struct ProductsListResponse {
  public var brands: [String]?
  public var filters: [String: Filter]?
  public var priceRange: PriceRange?
  public var products: [Product]
  public var productsTotal: Int
  
  init(json: [String: Any]) {
    brands = (json["brands"] as? [[String: Any]])?.compactMap { $0["name"] as? String }
    
    filters = (json["filters"] as? [String: Any])?.reduce(into: [:]) { result, item in  
    if let dict = item.value as? [String: Any] { result[item.key] = Filter(json: dict) }
}
    
    if let priceRangeJSON = json["price_range"] as? [String: Any] {
      self.priceRange = PriceRange(json: priceRangeJSON)
    }
    
    products = (json["products"] as? [[String: Any]])?.map { Product(json: $0) } ?? []
    
    productsTotal = (json["products_total"] as? Int) ?? 0
  }
}
