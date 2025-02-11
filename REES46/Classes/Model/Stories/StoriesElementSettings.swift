class Labels: Codable {
  let hideCarousel, showCarousel: String
  private enum CodingKeys: String, CodingKey {
    case hideCarousel = "hide_carousel"
    case showCarousel = "show_carousel"
  }
  required public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    hideCarousel = try container.decode(String.self, forKey: .hideCarousel)
    showCarousel = try container.decode(String.self, forKey: .showCarousel)
  }
}

public enum FontType: String, Codable {
  case monospaced
  case serif
  case sansSerif = "sans-serif"
  case unknown
}

enum ElementType: String, Codable {
  case button = "button"
  case products = "products"
  case product = "product"
  case textBlock = "text_block"
  case unknown
}

enum TextAlignment: String, Codable {
  case left
  case right
  case center
}
