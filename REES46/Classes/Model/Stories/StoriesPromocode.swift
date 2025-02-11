import Foundation

public class StoriesPromoCodeElement:Codable {
  let id, name, brand, price_full, price_formatted, price_full_formatted, image_url, picture, currency: String
  let url: String
  let deeplinkIos: String
  let price: Int
  let oldprice: Int
  let oldprice_full, oldprice_formatted, oldprice_full_formatted: String
  let discount_percent: Int
  let price_with_promocode_formatted: String
  let promocode: String
  let image_url_resized: PromoCodeElementImagesResize?
  
  private enum CodingKeys: String, CodingKey {
    case id, promocode, price_with_promocode_formatted, image_url_resized, oldprice_full_formatted, oldprice_formatted, oldprice, oldprice_full, discount_percent, price_full_formatted, picture, price_full, price_formatted, currency, image_url, name, url, deeplinkIos, price, brand
  }
  
  required public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decode(String.self, forKey: .id)
    self.promocode = try container.decode(String.self, forKey: .promocode)
    self.price_with_promocode_formatted = try container.decode(String.self, forKey: .price_with_promocode_formatted)
    self.image_url_resized = try container.decodeIfPresent(PromoCodeElementImagesResize.self, forKey: .image_url_resized)
    self.oldprice_full_formatted = try container.decode(String.self, forKey: .oldprice_full_formatted)
    self.oldprice_formatted = try container.decode(String.self, forKey: .oldprice_formatted)
    self.oldprice = try container.decode(Int.self, forKey: .oldprice)
    self.oldprice_full = try container.decode(String.self, forKey: .oldprice_full)
    self.discount_percent = try container.decode(Int.self, forKey: .discount_percent)
    self.price_full_formatted = try container.decode(String.self, forKey: .price_full_formatted)
    self.picture = try container.decode(String.self, forKey: .picture)
    self.price_full = try container.decode(String.self, forKey: .price_full)
    self.price_formatted = try container.decode(String.self, forKey: .price_formatted)
    self.currency = try container.decode(String.self, forKey: .currency)
    self.image_url = try container.decode(String.self, forKey: .image_url)
    self.name = try container.decode(String.self, forKey: .name)
    self.url = try container.decode(String.self, forKey: .url)
    self.deeplinkIos = try container.decode(String.self, forKey: .deeplinkIos)
    self.price = try container.decode(Int.self, forKey: .price)
    self.brand = try container.decode(String.self, forKey: .brand)
  }
}

public class PromoCodeElementImagesResize: Codable {
  let image_url_resized220: String
  let image_url_resized310: String
  let image_url_resized520: String
  private enum CodingKeys: String, CodingKey{
    case image_url_resized220 = "220"
    case image_url_resized310 = "310"
    case image_url_resized520 = "520"
  }
  required public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.image_url_resized220 = try container.decode(String.self, forKey: .image_url_resized220)
    self.image_url_resized310 = try container.decode(String.self, forKey: .image_url_resized310)
    self.image_url_resized520 = try container.decode(String.self, forKey: .image_url_resized520)
  }
}
