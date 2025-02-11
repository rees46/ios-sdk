import Foundation

public class StoriesElement: Codable {
  public var link: String?
  public var deeplinkIos: String?
  let uID: String?
  let fontType: FontType?
  let fontSize: Double?
  let textItalic: Bool?
  let textBackgroundColorOpacity: String?
  let textBackgroundColor: String?
  let textColor: String?
  let textInput: String?
  let textAlignment: TextAlignment?
  let textLineSpacing: Double?
  let yOffset: Double?
  let type: ElementType
  let color: String?
  let title, linkIos: String?
  let textBold, bold: Bool?
  let background: String?
  let cornerRadius: Int
  let labels: Labels?
  let products: [StoriesProduct]?
  let product: StoriesPromoCodeElement?
  
  private enum CodingKeys: String, CodingKey {
    case link, type, color, title, background, labels, products, bold
    case deeplinkIos = "deeplink_ios"
    case uID = "uniqid"
    case fontType = "font_type"
    case fontSize = "font_size"
    case textItalic = "italic"
    case textBackgroundColorOpacity = "text_background_color_opacity"
    case textBackgroundColor = "text_background_color"
    case textColor = "text_color"
    case textInput = "text_input"
    case textAlignment = "text_align"
    case textLineSpacing = "text_line_spacing"
    case yOffset = "y_offset"
    case linkIos = "link_ios"
    case textBold = "text_bold"
    case cornerRadius = "corner_radius"
    case product = "item"
  }
  required public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    link = try container.decodeIfPresent(String.self, forKey: .link)
    deeplinkIos = try container.decodeIfPresent(String.self, forKey: .deeplinkIos)
    fontType = FontType(rawValue: try container.decodeIfPresent(String.self, forKey: .fontType) ?? "")
    fontSize = try container.decodeIfPresent(Double.self, forKey: .fontSize)
    textItalic = try container.decodeIfPresent(Bool.self, forKey: .textItalic)
    textBackgroundColorOpacity = try container.decodeIfPresent(String.self, forKey: .textBackgroundColorOpacity)
    textBackgroundColor = try container.decodeIfPresent(String.self, forKey: .textBackgroundColor)
    textColor = try container.decodeIfPresent(String.self, forKey: .textColor)
    textInput = try container.decodeIfPresent(String.self, forKey: .textInput)
    textAlignment = TextAlignment(rawValue: try container.decodeIfPresent(String.self, forKey: .textAlignment) ?? TextAlignment.left.rawValue)
    textLineSpacing = try container.decodeIfPresent(Double.self, forKey: .textLineSpacing)
    yOffset = try container.decodeIfPresent(Double.self, forKey: .yOffset)
    uID = try container.decodeIfPresent(String.self, forKey: .uID)
    type = ElementType(rawValue: try container.decodeIfPresent(String.self, forKey: .type) ?? ElementType.unknown.rawValue) ?? .unknown
    color = try container.decodeIfPresent(String.self, forKey: .color)
    title = try container.decodeIfPresent(String.self, forKey: .title)
    linkIos = try container.decodeIfPresent(String.self, forKey: .linkIos)
    bold = try container.decodeIfPresent(Bool.self, forKey: .bold)
    textBold = try container.decodeIfPresent(Bool.self, forKey: .textBold) ?? bold
    background = try container.decodeIfPresent(String.self, forKey: .background)
    cornerRadius = try container.decodeIfPresent(Int.self, forKey: .cornerRadius) ?? 12
    labels = try container.decodeIfPresent(Labels.self, forKey: .labels)
    products = try container.decodeIfPresent([StoriesProduct].self, forKey: .products)
    product = try container.decodeIfPresent(StoriesPromoCodeElement.self, forKey: .product)
    
  }
}
