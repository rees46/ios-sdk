import Foundation

public struct ProductInfo {
  public var id: String = ""
  public var name: String = ""
  public var brand: String = ""
  public var model: String = ""
  public var description: String = ""
  public var imageUrl: String = ""
  public var resizedImageUrl: String = ""
  public var resizedImages: [String: String] = [:]
  public var url: String
  public var deeplinkIos: String
  
  public var categories: [Category]
  
  public var price: Double
  public var priceFormatted: String
  public var priceFull: Double
  public var priceFullFormatted: String
  public var oldPrice: Double
  public var oldPriceFormatted: String
  public var oldPriceFull: Double
  public var oldPriceFullFormatted: String
  
  public var currency: String
  public var salesRate: Int = 0
  public var discount: Int = 0
  public var relativeSalesRate: Float = 0.0
  public var barcode: String = ""
  public var isNew: Bool?
  public var params: [[String: Any]]?
  
  init(json: [String: Any]) {
    
    id = json["uniqid"] as? String ?? ""
    name = json["name"] as? String ?? ""
    brand = json["brand"] as? String ?? ""
    model = json["model"] as? String ?? ""
    description = json["description"] as? String ?? ""
    imageUrl = json["image_url"] as? String ?? ""
    resizedImageUrl = json["picture"] as? String ?? ""
    resizedImages = json["image_url_resized"] as? [String: String] ?? [:]
    url = json["url"] as? String ?? ""
    deeplinkIos = json["deeplink_ios"] as? String ?? ""
    
    let categoriesJson = json["categories"] as? [[String: Any]] ?? []
    var categoriesAll = [Category]()
    for item in categoriesJson {
      categoriesAll.append(Category(json: item))
    }
    categories = categoriesAll
    
    price = json["price"] as? Double ?? 0
    priceFormatted = json["price_formatted"] as? String ?? ""
    priceFull = json["price_full"] as? Double ?? 0
    priceFullFormatted = json["price_full_formatted"] as? String ?? ""
    oldPrice = json["oldprice"] as? Double ?? 0
    oldPriceFormatted = json["oldprice_formatted"] as? String ?? ""
    oldPriceFull = json["oldprice_full"] as? Double ?? 0
    oldPriceFullFormatted = json["oldprice_full_formatted"] as? String ?? ""
    currency = json["currency"] as? String ?? ""
    barcode = json["barcode"] as? String ?? ""
    isNew = json["is_new"] as? Bool
    params = json["params"] as? [[String: Any]]
    
    discount = json["discount"] as? Int ?? 0
    salesRate = json["sales_rate"] as? Int ?? 0
    relativeSalesRate = json["relative_sales_rate"] as? Float ?? 0.0
  }
}
