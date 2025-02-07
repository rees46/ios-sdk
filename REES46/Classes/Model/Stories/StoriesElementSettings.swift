class Labels {
  let hideCarousel, showCarousel: String
  
  public init(json: [String: Any]) {
    self.hideCarousel = json["hide_carousel"] as? String ?? ""
    self.showCarousel = json["show_carousel"] as? String ?? ""
  }
}

public enum FontType: String {
  case monospaced
  case serif
  case sansSerif = "sans-serif"
  case unknown
}

enum ElementType: String {
  case button = "button"
  case products = "products"
  case product = "product"
  case textBlock = "text_block"
  case unknown
}

enum TextAlignment: String {
  case left
  case right
  case center
}
