import Foundation

public class StoriesProduct: Codable {
  let name: String
  let currency: String
  let price: Int
  let price_full: Int
  let price_formatted, price_full_formatted: String
  let oldprice: Int?
  let oldprice_full: Int
  let oldprice_formatted, oldprice_full_formatted: String
  let picture: String
  let discount: String?
  let discount_formatted: String?
  let category: StoriesCategory
  public var url: String
  public var deeplinkIos: String
  
  private enum CodingKeys: String, CodingKey {
    case name, currency, price, price_full, price_formatted, price_full_formatted, oldprice,oldprice_full, oldprice_formatted, oldprice_full_formatted, picture, discount, discount_formatted, category, url
    case deeplinkIos = "deeplink_ios"
  }
  required public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.name = try container.decode(String.self, forKey: .name)
    self.currency = try container.decode(String.self, forKey: .currency)
    self.price = try container.decode(Int.self, forKey: .price)
    self.price_full = try container.decode(Int.self, forKey: .price_full)
    self.price_formatted = try container.decode(String.self, forKey: .price_formatted)
    self.price_full_formatted = try container.decode(String.self, forKey: .price_full_formatted)
    self.oldprice = try container.decodeIfPresent(Int.self, forKey: .oldprice)
    self.oldprice_full = try container.decode(Int.self, forKey: .oldprice_full)
    self.oldprice_formatted = try container.decode(String.self, forKey: .oldprice_formatted)
    self.oldprice_full_formatted = try container.decode(String.self, forKey: .oldprice_full_formatted)
    self.picture = try container.decode(String.self, forKey: .picture)
    self.discount = try container.decodeIfPresent(String.self, forKey: .discount)
    self.discount_formatted = try container.decodeIfPresent(String.self, forKey: .discount_formatted)
    self.category = try container.decode(StoriesCategory.self, forKey: .category)
    self.url = try container.decode(String.self, forKey: .url)
    self.deeplinkIos = try container.decode(String.self, forKey: .deeplinkIos)
  }
}
