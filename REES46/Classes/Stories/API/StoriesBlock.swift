//
//  StoriesBlock.swift
//  REES46
//
//  The models of `stories.get` (`sdk/contract/stories.md`), the same as the Flutter SDK's. A string
//  field without a value is an empty string, not `nil`, as Flutter has it: a model reads without checks.
//

import Foundation

/// A stories block: what `stories.get` gives.
@_spi(Bridge)
public struct StoriesBlock {
    /// The block's id on the server.
    public let id: String
    /// Empty for a block without stories or one on pause.
    public let stories: [Story]
}

/// One story: a cover in the bar and the slides it plays.
@_spi(Bridge)
public struct Story {
    public let id: String
    public let name: String
    /// The cover's URL.
    public let avatar: String
    /// The server remembers the device saw it.
    public let viewed: Bool
    /// Pinned by the shop to the start of the bar.
    public let pinned: Bool
    /// The slide to start from: the first one the device has not seen.
    public let startPosition: Int
    public let slides: [StorySlide]
}

/// One slide of a story.
@_spi(Bridge)
public struct StorySlide {
    /// A number for a slide with media; `<storyId>_<n>`, like `39_0`, for a slide of products.
    public let id: String
    public let type: StorySlideType
    /// The URL of the picture or the video; a slide of products has the one of the stories' settings.
    public let background: String
    /// `#RRGGBB`; empty when not set.
    public let backgroundColor: String
    /// The poster of a video; empty when there is none.
    public let preview: String
    /// How long the slide stays, in seconds: 10 when the answer has none or 0.
    public let duration: Int
    /// The elements the SDK knows, in the answer's order: others — `header`, `poll` — are left out.
    public let elements: [StoryElement]

    /// The seconds of a slide whose answer has no duration, or 0.
    public static let defaultDuration = 10
}

/// What a slide shows behind its elements.
@_spi(Bridge)
public enum StorySlideType {
    /// `background` is a picture.
    case image
    /// `background` is a video, `preview` its poster.
    case video
    /// A slide of products of a campaign: its product comes in a `StoryProductElement`. The answer
    /// gives it no type of media.
    case product
}

/// An element of a slide.
@_spi(Bridge)
public enum StoryElement {
    case button(StoryButtonElement)
    case product(StoryProductElement)
    case products(StoryProductsElement)
    case textBlock(StoryTextBlockElement)
}

/// `button`: a button with a link.
@_spi(Bridge)
public struct StoryButtonElement {
    public let title: String
    public let link: String
    public let linkAndroid: String
    public let linkIos: String
    /// The colours of the old stories view.
    public let background: String
    public let color: String
    public let textBold: Bool
}

/// `product`: the product of a slide of products.
@_spi(Bridge)
public struct StoryProductElement {
    public let title: String
    /// `nil` when the answer has none.
    public let item: StoryProduct?
}

/// `products`: the products of a slide behind a "show / hide" toggle.
@_spi(Bridge)
public struct StoryProductsElement {
    /// The toggle's text while the products are hidden (`labels.show_carousel`).
    public let showLabel: String
    /// The toggle's text while they are shown (`labels.hide_carousel`).
    public let hideLabel: String
    public let products: [StoryProduct]
}

/// `text_block`: a text over the slide.
@_spi(Bridge)
public struct StoryTextBlockElement {
    /// The text (`text_input`).
    public let text: String
    /// 14 when not set.
    public let fontSize: Double
    /// `serif`, `sans-serif`, `monospace` or empty.
    public let fontType: String
    public let bold: Bool
    public let italic: Bool
    /// `left`, `center`, `right` or empty.
    public let textAlign: String
    /// `#RRGGBB` or empty.
    public let textColor: String
    /// `#RRGGBB` behind the text, or empty.
    public let backgroundColor: String
    /// 0…1, read from `"50%"`, `"50"` or `0.5`; 0 — no frame.
    public let backgroundOpacity: Double
    /// A multiple of the font size; 0 — the font's own.
    public let lineSpacing: Double
    /// The top of the block, in percent of the slide's height.
    public let yOffset: Double
    /// The code the block copies when tapped; `nil` when it has none.
    public let promocode: String?

    /// The font size of a block whose answer has none.
    public static let defaultFontSize: Double = 14
}

/// A product of a stories block.
@_spi(Bridge)
public struct StoryProduct {
    public let id: String
    public let name: String
    public let brand: String
    /// The reduced picture: the one to show.
    public let picture: String
    /// The original picture.
    public let imageUrl: String
    public let price: Double
    public let priceFormatted: String
    /// The price without the discount; `nil` unless it is above `price` — without a discount the
    /// server sends `price` here.
    public let oldPrice: Double?
    public let oldPriceFormatted: String
    /// Only when the shop loaded it into its catalog; 0 otherwise. `price` already has the discount.
    public let discountPercent: Double
    public let promocode: String
    /// 0 when the answer has none.
    public let priceWithPromocode: Double
    public let priceWithPromocodeFormatted: String
    public let currency: String
    public let url: String
    public let deeplinkAndroid: String
    public let deeplinkIos: String
}
