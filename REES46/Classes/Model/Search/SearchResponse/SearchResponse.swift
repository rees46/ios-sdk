import Foundation

public struct SearchResponse {
  public var categories: [Category]
  public var products: [Product]
  public var productsTotal: Int
  public var queries: [Query]
  public var filters: [String: Filter]?
  public var industrialFilters: IndustrialFilters?
  public var brands: [String]?
  public var priceRange: PriceRange?
  public var redirect: Redirect?
  
  init(json: [String: Any]) {
    let cats = json["categories"] as? [[String: Any]] ?? []
    var catsTemp = [Category]()
    for item in cats {
      catsTemp.append(Category(json: item))
    }
    categories = catsTemp
    
    let prods = json["products"] as? [[String: Any]] ?? []
    var prodsTemp = [Product]()
    for item in prods {
      prodsTemp.append(Product(json: item))
    }
    products = prodsTemp
    
    let quers = json["queries"] as? [[String: Any]] ?? []
    var quersTemp = [Query]()
    for item in quers {
      quersTemp.append(Query(json: item))
    }
    queries = quersTemp
    
    productsTotal = (json["products_total"] as? Int) ?? 0
    
    if let filtersJSON = json["filters"] as? [String: Any] {
      var filtersResult = [String: Filter]()
      for item in filtersJSON {
        if let dict = item.value as? [String: Any] {
          filtersResult[item.key] = Filter(json: dict)
        }
      }
      self.filters = filtersResult
    }
    
    if let brandsJSON = json["brands"] as? [[String: Any]] {
      var brandsResult = [String]()
      for item in brandsJSON {
        if let name = item["name"] as? String {
          brandsResult.append(name)
        }
      }
      self.brands = brandsResult
    }
    
    if let industrialFiltersJSON = json["industrial_filters"] as? [String: Any] {
      self.industrialFilters = IndustrialFilters(json: industrialFiltersJSON)
    }
    
    if let priceRangeJSON = json["price_range"] as? [String: Any] {
      self.priceRange = PriceRange(json: priceRangeJSON)
    }
    
    if let redirectJSON = json["search_query_redirects"] as? [String: Any] {
      self.redirect = Redirect(json: redirectJSON)
    }
  }
}
