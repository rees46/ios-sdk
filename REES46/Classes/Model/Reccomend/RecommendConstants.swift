import Foundation

struct Constants {
  enum JSONKeys: String, CodingKey {
    
    case recommends = "recommends"
    case title = "title"
    case locations = "locations"
    case id = "id"
    case barcode = "barcode"
    case name = "name"
    case brand = "brand"
    case model = "model"
    case description = "description"
    case imageUrl = "image_url"
    case picture = "picture"
    case url = "url"
    case deeplinkIos = "deeplink_ios"
    case price = "price"
    case priceFormatted = "price_formatted"
    case priceFull = "price_full"
    case priceFullFormatted = "price_full_formatted"
    case oldPrice = "oldprice"
    case oldPriceFormatted = "oldprice_formatted"
    case oldPriceFull = "oldprice_full"
    case oldPriceFullFormatted = "oldprice_full_formatted"
    case currency = "currency"
    case salesRate = "sales_rate"
    case relativeSalesRate = "relative_sales_rate"
    case discount = "discount"
    case rating = "rating"
    case image_url_resized = "image_url_resized"
    case categories = "categories"
    case withLocations = "with_locations"
    case extended = "extended"
    case fashionOriginalSizes = "fashion_original_sizes"
    case fashionSizes = "fashion_sizes"
    case fashionColors = "fashion_colors"
    case params = "params"
  }
  
  struct RecommendedBy {
    static let recommendedBy = "recommended_by"
    static let recommendedCode = "recommended_code"
    static let webPushDigestCode = "web_push_digest_code"
  }
}
