import Foundation

public struct SearchBlankResponse {
  public var lastQueries: [Query]
  public var suggests: [Suggest]
  public var lastProducts: Bool
  public var products: [Product]
  
  init(json: [String: Any]) {
    let lastQueriesTemp = json["last_queries"] as? [[String: Any]] ?? []
    var quyArr = [Query]()
    for item in lastQueriesTemp {
      quyArr.append(Query(json: item))
    }
    lastQueries = quyArr
    
    let suggestsTemp = json["suggests"] as? [[String: Any]] ?? []
    var sugArr = [Suggest]()
    for item in suggestsTemp {
      sugArr.append(Suggest(json: item))
    }
    suggests = sugArr
    
    lastProducts = json["last_products"] as? Bool ?? true
    
    let productsTemp = json["products"] as? [[String: Any]] ?? []
    var productArr = [Product]()
    for item in productsTemp {
      productArr.append(Product(json: item))
    }
    products = productArr
  }
}
