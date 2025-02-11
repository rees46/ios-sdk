import Foundation

public struct ProductsListResponse {
  public var brands: [String]?
  public var filters: [String: Filter]?
  public var priceRange: PriceRange?
  public var products: [Product]
  public var productsTotal: Int
  
  init(json: [String: Any]) {
    brands = (json["brands"] as? [[String: Any]])?.compactMap { $0["name"] as? String }
    
    if let filtersJSON = json["filters"] as? [String: Any] {
      var filtersResult = [String: Filter]()
      for item in filtersJSON {
        if let dict = item.value as? [String: Any] {
          filtersResult[item.key] = Filter(json: dict)
        }
      }
      self.filters = filtersResult
    }
    
    if let priceRangeJSON = json["price_range"] as? [String: Any] {
      self.priceRange = PriceRange(json: priceRangeJSON)
    }
    
    products = (json["products"] as? [[String: Any]])?.map { Product(json: $0) } ?? []
    
    productsTotal = (json["products_total"] as? Int) ?? 0
  }
}
