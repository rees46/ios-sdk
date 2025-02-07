import Foundation

public class StoriesPromoCodeElement {
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
  
  public init(json: [String: Any]) {
    self.id = json["id"] as? String ?? ""
    self.name = json["name"] as? String ?? ""
    self.url = json["url"] as? String ?? ""
    self.deeplinkIos = json["deeplink_ios"] as? String ?? ""
    self.brand = json["brand"] as? String ?? ""
    self.image_url = json["image_url"] as? String ?? ""
    self.price = json["price"] as? Int ?? 0
    self.price_formatted = json["price_formatted"] as? String ?? ""
    self.price_full = json["price_full"] as? String ?? ""
    self.price_full_formatted = json["price_full_formatted"] as? String ?? ""
    self.picture = json["picture"] as? String ?? ""
    self.currency = json["currency"] as? String ?? ""
    self.oldprice = json["oldprice"] as? Int ?? 0
    self.oldprice_full = json["oldprice_full"] as? String ?? ""
    self.oldprice_formatted = json["oldprice_formatted"] as? String ?? ""
    self.oldprice_full_formatted = json["oldprice_full_formatted"] as? String ?? ""
    self.discount_percent = json["discount_percent"] as? Int ?? 0
    self.price_with_promocode_formatted = json["price_with_promocode_formatted"] as? String ?? ""
    self.promocode = json["promocode"] as? String ?? ""
    let _image_url_resized = json["image_url_resized"] as? [String: Any] ?? [:]
    self.image_url_resized = PromoCodeElementImagesResize(json: _image_url_resized)
  }
}

public class PromoCodeElementImagesResize {
  let image_url_resized220: String
  let image_url_resized310: String
  let image_url_resized520: String
  
  public init(json: [String:Any]) {
    self.image_url_resized220 = json["220"] as? String ?? ""
    self.image_url_resized310 = json["310"] as? String ?? ""
    self.image_url_resized520 = json["520"] as? String ?? ""
  }
}
