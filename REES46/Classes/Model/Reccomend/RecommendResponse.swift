import Foundation

public struct RecommenderResponse:Codable {
  public var recommended: [Recommended]
  public var title: String
  public var locations: [Location]?
  
  private enum CodingKeys: String, CodingKey {
    case recommended = "recommends"
    case title = "title"
    case locations = "locations"
  }
  
  
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    
    recommended = (try container.decodeIfPresent([Recommended].self, forKey: .recommended) ?? [])
    title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
    locations = try container.decodeIfPresent([Location].self, forKey: .locations)
  }
}

public struct Recommended:Codable {
  public var id: String
  public var barcode: String
  public var name: String
  public var brand: String
  public var model: String
  public var description: String
  public var imageUrl: String
  public var resizedImageUrl: String
  public var url: String
  public var deeplinkIos: String
  public var categories = [Category]()
  public var locations = [Location]()
  
  public var price: Double
  public var priceFormatted: String?
  public var priceFull: Double
  public var priceFullFormatted: String?
  public var oldPrice: Double
  public var oldPriceFormatted: String?
  public var oldPriceFull: Double
  public var oldPriceFullFormatted: String?
  
  public var currency: String
  public var salesRate: Int
  public var discount: Int
  public var rating: Int
  public var relativeSalesRate: Float
  public var paramsRaw: [[String: Any]]?
  public var fashionOriginalSizes: [String]
  public var fashionSizes: [String]
  public var fashionColors: [String]
  public var resizedImages: [String: String]
  
  
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: Constants.JSONKeys.self)
    
    id = try container.decode(String.self, forKey: .id)
    barcode = try container.decode(String.self, forKey: .barcode)
    name = try container.decode(String.self, forKey: .name)
    brand = try container.decode(String.self, forKey: .brand)
    model = try container.decode(String.self, forKey: .model)
    description = try container.decode(String.self, forKey: .description)
    imageUrl = try container.decode(String.self, forKey: .imageUrl)
    resizedImageUrl = try container.decode(String.self, forKey: .picture)
    url = try container.decode(String.self, forKey: .url)
    deeplinkIos = try container.decode(String.self, forKey: .deeplinkIos)
    price = try container.decode(Double.self, forKey: .price)
    priceFormatted = try container.decodeIfPresent(String.self, forKey: .priceFormatted) ?? ""
    priceFull = try container.decode(Double.self, forKey: .priceFull)
    priceFullFormatted = try container.decodeIfPresent(String.self, forKey: .priceFullFormatted) ?? ""
    oldPrice = try container.decode(Double.self, forKey: .oldPrice)
    oldPriceFormatted = try container.decodeIfPresent(String.self, forKey: .oldPriceFormatted) ?? ""
    oldPriceFull = try container.decode(Double.self, forKey: .oldPriceFull)
    oldPriceFullFormatted = try container.decodeIfPresent(String.self, forKey: .oldPriceFullFormatted) ?? ""
    currency = try container.decode(String.self, forKey: .currency)
    salesRate = try container.decode(Int.self, forKey: .salesRate)
    relativeSalesRate = try container.decode(Float.self, forKey: .relativeSalesRate)
    discount = try container.decode(Int.self, forKey: .discount)
    rating = try container.decode(Int.self, forKey: .rating)
    resizedImages = try container.decode([String:String].self, forKey: .image_url_resized)
    locations = try container.decode([Location].self, forKey: .locations)
    categories = try container.decode([Category].self, forKey: .categories).compactMap { $0 }
    fashionOriginalSizes = try container.decode([String].self, forKey: .fashionOriginalSizes)
    fashionSizes = try container.decode([String].self, forKey: .fashionSizes)
    fashionColors = try container.decode([String].self, forKey: .fashionColors)
    
    if let paramsData = try? container.decodeIfPresent(Data.self, forKey: .params) {
      paramsRaw = try? JSONSerialization.jsonObject(with: paramsData, options: []) as? [[String: Any]]
    } else {
      paramsRaw = nil
    }
  }
  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: Constants.JSONKeys.self)
    if let params = paramsRaw {
      let paramsData = try JSONSerialization.data(withJSONObject: params, options: [])
      try container.encode(paramsData, forKey: .params)
    }
  }
}
