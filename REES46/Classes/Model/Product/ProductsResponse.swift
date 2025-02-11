import Foundation

public struct ProductsListResponse: Codable {
  public var brands: [String]?
  public var filters: [String: Filter]?
  public var priceRange: PriceRange?
  public var products: [Product]
  public var productsTotal: Int
  
  public enum CodingKeys: String, CodingKey {
    case brands, filters, products
    case priceRange = "price_range"
    case productsTotal = "products_total"
  }
  
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    
    if let brandsArray = try? container.decodeIfPresent([[String: String]].self, forKey: .brands) {
      brands = brandsArray.compactMap { $0["name"] }
    } else {
      brands = nil
    }
    
    if let filtersDict = try? container.decodeIfPresent([String: Filter].self, forKey: .filters) {
      filters = filtersDict.compactMapValues { dict in
        if let filterData = try? JSONSerialization.data(withJSONObject: dict, options: []) {
          return try? JSONDecoder().decode(Filter.self, from: filterData)
        }
        return nil
      }
    } else {
      filters = nil
    }
    
    priceRange = try container.decodeIfPresent(PriceRange.self, forKey: .priceRange)
    
    products = try container.decode([Product].self, forKey: .products)
    
    productsTotal = try container.decode(Int.self, forKey: .productsTotal)
  }
}
