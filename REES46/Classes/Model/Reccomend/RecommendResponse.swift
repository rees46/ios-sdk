import Foundation

public struct RecommenderResponse {
  public var recommended: [Recommended]
  public var title: String = ""
  public var locations: [Location]?
  
  init(json: [String: Any]) {
    let recs = json[Constants.JSONKeys.recommends] as? [[String: Any]] ?? []
    var recsTemp = [Recommended]()
    for item in recs {
      recsTemp.append(Recommended(json: item))
    }
    recommended = recsTemp
    title = (json[Constants.JSONKeys.title] as? String) ?? ""
    
    if let locationsArray = json[Constants.JSONKeys.locations] as? [[String: Any]] {
      var locationsTemp = [Location]()
      for locationItem in locationsArray {
        locationsTemp.append(Location(json: locationItem))
      }
      locations = locationsTemp
    }
  }
}

public struct Recommended {
  public var id: String = ""
  public var barcode: String = ""
  public var name: String = ""
  public var brand: String = ""
  public var model: String = ""
  public var description: String = ""
  public var imageUrl: String = ""
  public var resizedImageUrl: String = ""
  public var url: String = ""
  public var deeplinkIos: String = ""
  public var categories = [Category]()
  public var locations = [Location]()
  
  public var price: Double = 0
  public var priceFormatted: String?
  public var priceFull: Double = 0
  public var priceFullFormatted: String?
  public var oldPrice: Double = 0
  public var oldPriceFormatted: String?
  public var oldPriceFull: Double = 0
  public var oldPriceFullFormatted: String?
  
  public var currency: String = ""
  public var salesRate: Int = 0
  public var discount: Int = 0
  public var rating: Int = 0
  public var relativeSalesRate: Float = 0.0
  public var paramsRaw: [[String: Any]]?
  public var fashionOriginalSizes: [String] = []
  public var fashionSizes: [String] = []
  public var fashionColors: [String] = []
  public var resizedImages: [String: String] = [:]
  
  init(json: [String: Any]) {
    id = json[Constants.JSONKeys.id] as? String ?? ""
    barcode = json[Constants.JSONKeys.barcode] as? String ?? ""
    name = json[Constants.JSONKeys.name] as? String ?? ""
    brand = json[Constants.JSONKeys.brand] as? String ?? ""
    model = json[Constants.JSONKeys.model] as? String ?? ""
    description = json[Constants.JSONKeys.description] as? String ?? ""
    imageUrl = json[Constants.JSONKeys.imageUrl] as? String ?? ""
    resizedImageUrl = json[Constants.JSONKeys.picture] as? String ?? ""
    url = json[Constants.JSONKeys.url] as? String ?? ""
    deeplinkIos = json[Constants.JSONKeys.deeplinkIos] as? String ?? ""
    price = json[Constants.JSONKeys.price] as? Double ?? 0
    priceFormatted = json[Constants.JSONKeys.priceFormatted] as? String
    priceFull = json[Constants.JSONKeys.priceFull] as? Double ?? 0
    priceFullFormatted = json[Constants.JSONKeys.priceFullFormatted] as? String
    oldPrice = json[Constants.JSONKeys.oldPrice] as? Double ?? 0
    oldPriceFormatted = json[Constants.JSONKeys.oldPriceFormatted] as? String
    oldPriceFull = json[Constants.JSONKeys.oldPriceFull] as? Double ?? 0
    oldPriceFullFormatted = json[Constants.JSONKeys.oldPriceFullFormatted] as? String
    currency = json[Constants.JSONKeys.currency] as? String ?? ""
    salesRate = json[Constants.JSONKeys.salesRate] as? Int ?? 0
    relativeSalesRate = json[Constants.JSONKeys.relativeSalesRate] as? Float ?? 0.0
    discount = json[Constants.JSONKeys.discount] as? Int ?? 0
    rating = json[Constants.JSONKeys.rating] as? Int ?? 0
    resizedImages = json[Constants.JSONKeys.image_url_resized] as? [String: String] ?? [:]
    
    let categoriesArray = json[Constants.JSONKeys.categories] as? [[String: Any]] ?? []
    var categoriesTemp = [Category]()
    for item in categoriesArray {
      categoriesTemp.append(Category(json: item))
    }
    categories = categoriesTemp
    
    if let withLocations = json[Constants.JSONKeys.withLocations] as? Bool, withLocations,
       let extended = json[Constants.JSONKeys.extended] as? Bool, extended,
       let locationsArray = json[Constants.JSONKeys.locations] as? [[String: Any]] {
      self.locations = locationsArray.map { Location(json: $0) }
    }
    
    if let locationsArray = json[Constants.JSONKeys.locations] as? [[String: Any]] {
      var locationsTemp = [Location]()
      for item in locationsArray {
        locationsTemp.append(Location(json: item))
      }
      locations = locationsTemp
    }
    
    fashionOriginalSizes = json[Constants.JSONKeys.fashionOriginalSizes] as? [String] ?? []
    fashionSizes = json[Constants.JSONKeys.fashionSizes] as? [String] ?? []
    fashionColors = json[Constants.JSONKeys.fashionColors] as? [String] ?? []
    
    // TODO: convert to objects
    paramsRaw = json[Constants.JSONKeys.params] as? [[String: Any]]
    
  }
}
