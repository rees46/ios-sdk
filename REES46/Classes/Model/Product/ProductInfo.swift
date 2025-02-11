import Foundation

public struct ProductInfo: Codable/*, Equatable, Hashable*/  {

  public var id: String
  public var name: String
  public var brand: String
  public var model: String
  public var description: String
  public var imageUrl: String
  public var resizedImageUrl: String
  public var resizedImages: [String: String]
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
  public var salesRate: Int
  public var discount: Int
  public var relativeSalesRate: Float
  public var barcode: String
  public var isNew: Bool?
  public var params: [[String: Any]]?
  
  private enum CodingKeys: String, CodingKey {
    case name, brand, model, description, url, categories, price, oldPrice, currency, discount, barcode, params
    case id = "uniqid"
    case imageUrl = "image_url"
    case resizedImageUrl = "picture"
    case resizedImages = "image_url_resized"
    case deeplinkIos = "deeplink_ios"
    case priceFormatted = "price_formatted"
    case priceFull = "price_full"
    case priceFullFormatted = "price_full_formatted"
    case oldPriceFormatted = "oldprice_formatted"
    case oldPriceFull = "oldprice_full"
    case oldPriceFullFormatted = "oldprice_full_formatted"
    case salesRate = "sales_rate"
    case relativeSalesRate = "relative_sales_rate"
    case isNew = "is_new"
  }
  
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    
    id = try container.decode(String.self, forKey: .id)
    name = try container.decode(String.self, forKey: .name)
    brand = try container.decode(String.self, forKey: .brand)
    model = try container.decode(String.self, forKey: .model)
    description = try container.decode(String.self, forKey: .description)
    imageUrl = try container.decode(String.self, forKey: .imageUrl)
    resizedImageUrl = try container.decode(String.self, forKey: .resizedImageUrl)
    resizedImages = try container.decode([String: String].self, forKey: .resizedImages)
    url = try container.decode(String.self, forKey: .url)
    deeplinkIos = try container.decode(String.self, forKey: .deeplinkIos)
    categories = try container.decode([Category].self, forKey: .categories).compactMap { $0 }
    
    price = try container.decode(Double.self, forKey: .price)
    priceFormatted = try container.decode(String.self, forKey: .priceFormatted)
    priceFull = try container.decode(Double.self, forKey: .priceFull)
    priceFullFormatted = try container.decode(String.self, forKey: .priceFullFormatted)
    oldPrice = try container.decode(Double.self, forKey: .oldPrice)
    oldPriceFormatted = try container.decode(String.self, forKey: .oldPriceFormatted)
    oldPriceFull = try container.decode(Double.self, forKey: .oldPriceFull)
    oldPriceFullFormatted = try container.decode(String.self, forKey: .oldPriceFullFormatted)
    currency = try container.decode(String.self, forKey: .currency)
    salesRate = try container.decode(Int.self, forKey: .salesRate)
    discount = try container.decode(Int.self, forKey: .discount)
    relativeSalesRate = try container.decode(Float.self, forKey: .relativeSalesRate)
    barcode = try container.decode(String.self, forKey: .barcode)
    isNew = try container.decodeIfPresent(Bool.self, forKey: .isNew)
    
    if let paramsData = try? container.decodeIfPresent(Data.self, forKey: .params) {
      params = try? JSONSerialization.jsonObject(with: paramsData, options: []) as? [[String: Any]]
    } else {
      params = nil
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    if let params = params {
             let data = try JSONSerialization.data(withJSONObject: params, options: [])
             let jsonString = String(data: data, encoding: .utf8)
             try container.encodeIfPresent(jsonString, forKey: .params)
         }
  }
}
