import Foundation

public struct SearchBlankResponse: Codable {
  public var lastQueries: [Query]
  public var suggests: [Suggest]
  public var lastProducts: Bool
  public var products: [Product]
  
  private enum CodingKeys: String, CodingKey{
    case suggests, products
    case lastQueries = "last_queries"
    case lastProducts = "last_products"
  }
  
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    
    lastProducts = try container.decode(Bool.self, forKey: .lastProducts)
    products = try container.decode([Product].self, forKey: .products)
    lastQueries = try container.decode([Query].self, forKey: .lastQueries)
    suggests = try container.decode([Suggest].self, forKey: .suggests)
  }
}
