import Foundation

public struct SearchResponse: Codable {
  public var categories: [Category]
  public var products: [Product]
  public var productsTotal: Int
  public var queries: [Query]
  public var filters: [String: Filter]?
  public var industrialFilters: IndustrialFilters?
  public var brands: [String]?
  public var priceRange: PriceRange?
  public var redirect: Redirect?
  
  private enum CodingKeys: String, CodingKey {
    case categories, products, queries, filters, brands
    case productsTotal = "products_total"
    case industrialFilters = "industrial_filters"
    case priceRange = "price_range"
    case redirect = "search_query_redirects"
  }
  
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    categories = try container.decode([Category].self, forKey: .categories)
    products = try container.decode([Product].self, forKey: .products)
    queries = try container.decode([Query].self, forKey: .queries)
    productsTotal = try container.decode(Int.self, forKey: .productsTotal)
    filters = try container.decodeIfPresent([String: Filter].self, forKey: .filters) ?? [:]
    brands = try container.decodeIfPresent([String].self, forKey: .brands) ?? []
    industrialFilters = try container.decodeIfPresent(IndustrialFilters.self, forKey: .industrialFilters)
    priceRange = try container.decodeIfPresent(PriceRange.self, forKey: .priceRange)
    redirect = try container.decodeIfPresent(Redirect.self, forKey: .redirect)
  }
}
