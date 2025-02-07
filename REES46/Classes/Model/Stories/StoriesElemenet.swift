import Foundation
import AVFoundation

public class StoriesElement {
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
  let textBold: Bool?
  let background: String?
  let cornerRadius: Int
  let labels: Labels?
  let products: [StoriesProduct]?
  let product: StoriesPromoCodeElement?
  
  public init(json: [String: Any]) {
    self.link = json["link"] as? String
    self.deeplinkIos = json["deeplink_ios"] as? String
    self.fontType = FontType(rawValue: json["font_type"] as? String ?? "")
    self.fontSize = Double(json["font_size"] as? String ?? "")
    self.textItalic = json["italic"] as? Bool ?? false
    self.textBackgroundColorOpacity = json["text_background_color_opacity"] as? String
    self.textBackgroundColor = json["text_background_color"] as? String ?? ""
    self.textColor = json["text_color"] as? String ?? ""
    self.textInput = json["text_input"] as? String
    self.textAlignment = TextAlignment(rawValue: json["text_align"] as? String ?? TextAlignment.left.rawValue)
    self.textLineSpacing = Double(json["text_line_spacing"] as? String ?? "1.5")
    self.yOffset = Double(json["y_offset"] as? String ?? "")
    self.uID = json["uniqid"] as? String
    let _type = json["type"] as? String ?? ""
    self.type = ElementType(rawValue: _type) ?? .unknown
    self.color = json["color"] as? String
    self.title = json["title"] as? String
    self.linkIos = json["link_ios"] as? String
    self.textBold = json["text_bold"] as? Bool ?? json["bold"] as? Bool
    self.background = json["background"] as? String
    self.cornerRadius = json["corner_radius"] as? Int ?? 12
    let _labels = json["labels"] as? [String: Any] ?? [:]
    self.labels = Labels(json: _labels)
    let _products = json["products"] as? [[String: Any]] ?? []
    self.products = _products.map({StoriesProduct(json: $0)})
    let _product = json["item"] as? [String: Any] ?? [:]
    self.product = StoriesPromoCodeElement(json: _product)
  }
}
