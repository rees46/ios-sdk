public struct Product: Codable {
  public var id: String
  public var barcode: String
  public var name: String
  public var brand: String
  public var model: String
  public var description: String
  public var imageUrl: String
  public var resizedImageUrl: String
  public var resizedImages: [String: String]
  public var url: String
  public var deeplinkIos: String
  
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
  public var isNew: Bool?
  public var params: [[String: Any]]?
  
  private enum CodingKeys: String, CodingKey {
    case id, barcode, name, brand, model, description, url, price, oldPrice, currency, params, discount
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
    barcode = try container.decode(String.self, forKey: .barcode)
    name = try container.decode(String.self, forKey: .name)
    brand = try container.decode(String.self, forKey: .brand)
    model = try container.decode(String.self, forKey: .model)
    description = try container.decode(String.self, forKey: .description)
    url = try container.decode(String.self, forKey: .url)
    price = try container.decode(Double.self, forKey: .price)
    oldPrice = try container.decode(Double.self, forKey: .oldPrice)
    discount = try container.decode(Int.self, forKey: .discount)
    imageUrl = try container.decode(String.self, forKey: .imageUrl)
    resizedImageUrl = try container.decode(String.self, forKey: .resizedImageUrl)
    resizedImages = try container.decode([String: String].self, forKey: .resizedImages)
    deeplinkIos = try container.decode(String.self, forKey: .deeplinkIos)
    priceFormatted = try container.decode(String.self, forKey: .priceFormatted)
    priceFull = try container.decode(Double.self, forKey: .priceFull)
    priceFullFormatted = try container.decode(String.self, forKey: .priceFullFormatted)
    oldPriceFormatted = try container.decode(String.self, forKey: .oldPriceFormatted)
    oldPriceFull = try container.decode(Double.self, forKey: .oldPriceFull)
    oldPriceFullFormatted = try container.decode(String.self, forKey: .oldPriceFullFormatted)
    salesRate = try container.decode(Int.self, forKey: .salesRate)
    relativeSalesRate = try container.decode(Float.self, forKey: .relativeSalesRate)
    isNew = try container.decodeIfPresent(Bool.self, forKey: .isNew)
    currency = try container.decode(String.self, forKey: .currency)
    if let paramsData = try? container.decodeIfPresent(Data.self, forKey: .params) {
      params = try? JSONSerialization.jsonObject(with: paramsData, options: []) as? [[String: Any]]
    } else {
      params = nil
    }
  }
  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    if let params = params{
      let paramsData = try JSONSerialization.data(withJSONObject: params, options: [])
      try container.encode(paramsData, forKey: .params)
    }
  }
}
