import Foundation

public struct ProductsListResponse {
  public var brands: [String]?
  public var filters: [String: Filter]?
  public var priceRange: PriceRange?
  public var products: [Product]
  public var productsTotal: Int
  
  init(json: [String: Any]) {
    if let brandsJSON = json["brands"] as? [[String: Any]] {
      var brandsResult = [String]()
      for item in brandsJSON {
        if let name = item["name"] as? String {
          brandsResult.append(name)
        }
      }
      self.brands = brandsResult
    }
    
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
    
    let prods = json["products"] as? [[String: Any]] ?? []
    var prodsTemp = [Product]()
    for item in prods {
      prodsTemp.append(Product(json: item))
    }
    products = prodsTemp
    
    productsTotal = (json["products_total"] as? Int) ?? 0
  }
}
