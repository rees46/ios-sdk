import Foundation

public class StoriesProduct {
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
  
  public init(json: [String:Any]) {
    self.name = json["name"] as? String ?? ""
    self.currency = json["currency"] as? String ?? ""
    self.price = json["price"] as? Int ?? 0
    self.price_full = json["price_full"] as? Int ?? 0
    self.price_formatted = json["price_formatted"] as? String ?? ""
    self.price_full_formatted = json["price_full_formatted"] as? String ?? ""
    self.oldprice = json["oldprice"] as? Int ?? 0
    self.oldprice_full = json["oldprice_full"] as? Int ?? 0
    self.oldprice_formatted = json["oldprice_formatted"] as? String ?? ""
    self.oldprice_full_formatted = json["oldprice_full_formatted"] as? String ?? ""
    self.url = json["url"] as? String ?? ""
    self.deeplinkIos = json["deeplink_ios"] as? String ?? ""
    self.picture = json["picture"] as? String ?? ""
    self.discount = json["discount"] as? String ?? ""
    self.discount_formatted = json["discount_formatted"] as? String ?? "0%"
    let _category = json["category"] as? [String: Any] ?? [:]
    self.category = StoriesCategory(json: _category)
  }
}
