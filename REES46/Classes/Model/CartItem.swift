import Foundation

public struct CartItem: Codable {
  var productId: String
  var quantity: Int
  
  public enum CodingKeys: String, CodingKey {
    case productId = "uniqid"
    case quantity
  }
  
  public init(productId: String, quantity: Int = 1) {
    self.productId = productId
    self.quantity = quantity
  }
  
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    
    productId = try container.decode(String.self, forKey: .productId)
    quantity = try container.decode(Int.self, forKey: .quantity)
  }
}
