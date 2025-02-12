import Foundation

public struct ProductsListResponse: Codable {
  public var brands: [String]?
  public var filters: [String: Filter]?
  public var priceRange: PriceRange?
  public var products: [Product]
  public var productsTotal: Int
  
  private enum CodingKeys: String, CodingKey {
    case brands, filters, products
    case priceRange = "price_range"
    case productsTotal = "products_total"
  }
  
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.brands = try container.decodeIfPresent([String].self, forKey: .brands)/*?.compactMap { $0["name"] as? String }*/
    self.filters = try container.decodeIfPresent([String : Filter].self, forKey: .filters)
    self.priceRange = try container.decodeIfPresent(PriceRange.self, forKey: .priceRange)
    self.products = try container.decode([Product].self, forKey: .products)/*.map { Product( $0) } ?? []*/
    self.productsTotal = try container.decode(Int.self, forKey: .productsTotal)
  }
  
//  init(json: [String: Any]) {
//    brands = (json["brands"] as? [[String: Any]])?.compactMap { $0["name"] as? String }
//
//    filters = (json["filters"] as? [String: Any])?.reduce(into: [:]) { result, item in
//    if let dict = item.value as? [String: Any] { result[item.key] = Filter(json: dict) }
//}
//
//    if let priceRangeJSON = json["price_range"] as? [String: Any] {
//      self.priceRange = PriceRange(json: priceRangeJSON)
//    }
//
//    products = (json["products"] as? [[String: Any]])?.map { Product(json: $0) } ?? []
//
//    productsTotal = (json["products_total"] as? Int) ?? 0
//  }
}
