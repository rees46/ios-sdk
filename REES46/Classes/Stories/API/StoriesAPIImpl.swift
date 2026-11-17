//
//  StoriesAPIImpl.swift
//  REES46
//

import Foundation

struct StoriesAPIImpl: StoriesAPI {

    let requests: NamespaceRequests

    func get(code: String, completion: @escaping (Result<StoriesBlock, Rees46.SdkError>) -> Void) {
        requests.call("stories.get", completion: completion) { try Self.getRequest(code: code) }
    }

    func get(code: String) async throws -> StoriesBlock {
        try await requests.value("stories.get") { try Self.getRequest(code: code) }
    }

    /// `GET stories/{code}`, the code made safe for one segment of the path; the core adds the shop,
    /// the device id and the rest of the common fields. An answer without a body is not a block.
    static func getRequest(code: String) throws -> ApiRequest<StoriesBlock> {
        guard !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw Rees46.SdkError.invalidArgument("the code of the stories block must not be empty")
        }
        guard let segment = code.addingPercentEncoding(withAllowedCharacters: pathSegment) else {
            throw Rees46.SdkError.invalidArgument("the code of the stories block is not text")
        }
        return .get("stories/\(segment)", answer: StoriesAnswer.self) { $0.block }
    }

    /// What one segment of a path may hold as it is: no `/`, `?`, `#` or `%`.
    private static let pathSegment = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/?#%;"))
}

// MARK: - The answer

/// The answer of `GET stories/{code}` (`sdk/contract/stories.md`), read as leniently as the Flutter SDK
/// and the old view read it: numbers may come as strings, ids as numbers, a missing field is its
/// default; an element of a type the SDK does not draw — `header`, `poll`, an unknown one — is left
/// out. Anything but a JSON object is not a block (`decoding`). `settings` — the colours of the old view
/// — and the fields of API v3 are not read.
struct StoriesAnswer: Decodable {

    let block: StoriesBlock

    init(from decoder: Decoder) throws {
        let root = try decoder.container(keyedBy: AnswerKey.self)
        block = StoriesBlock(
            id: root.lenientString("id") ?? "",
            stories: (root.lenientList(StoryAnswer.self, "stories") ?? []).map(\.story)
        )
    }

    private struct StoryAnswer: Decodable {
        let story: Story

        init(from decoder: Decoder) throws {
            let item = try decoder.container(keyedBy: AnswerKey.self)
            story = Story(
                id: item.lenientString("id") ?? "",
                name: item.lenientString("name") ?? "",
                avatar: item.lenientString("avatar") ?? "",
                viewed: item.lenientBool("viewed") ?? false,
                pinned: item.lenientBool("pinned") ?? false,
                startPosition: item.lenientInt("start_position") ?? 0,
                slides: (item.lenientList(SlideAnswer.self, "slides") ?? []).map(\.slide)
            )
        }
    }

    private struct SlideAnswer: Decodable {
        let slide: StorySlide

        init(from decoder: Decoder) throws {
            let item = try decoder.container(keyedBy: AnswerKey.self)
            let seconds = item.lenientInt("duration") ?? 0
            let type: StorySlideType
            switch item.lenientString("type") {
            case "image": type = .image
            case "video": type = .video
            // A slide of products: the answer gives it an empty type.
            default: type = .product
            }
            slide = StorySlide(
                id: item.lenientString("id") ?? "",
                type: type,
                background: item.lenientString("background") ?? "",
                backgroundColor: item.lenientString("background_color") ?? "",
                preview: item.lenientString("preview") ?? "",
                duration: seconds > 0 ? seconds : StorySlide.defaultDuration,
                elements: (item.lenientList(ElementAnswer.self, "elements") ?? []).compactMap(\.element)
            )
        }
    }

    /// One element; `element` is `nil` for a type the SDK leaves out.
    private struct ElementAnswer: Decodable {
        let element: StoryElement?

        init(from decoder: Decoder) throws {
            let item = try decoder.container(keyedBy: AnswerKey.self)
            switch item.lenientString("type") {
            case "button":
                element = .button(StoryButtonElement(
                    title: item.lenientString("title") ?? "",
                    link: item.lenientString("link") ?? "",
                    linkAndroid: item.lenientString("link_android") ?? "",
                    linkIos: item.lenientString("link_ios") ?? "",
                    background: item.lenientString("background") ?? "",
                    color: item.lenientString("color") ?? "",
                    textBold: item.lenientBool("text_bold") == true || item.lenientBool("bold") == true
                ))
            case "product":
                element = .product(StoryProductElement(
                    title: item.lenientString("title") ?? "",
                    item: item.lenient(ProductAnswer.self, "item")?.product
                ))
            case "products":
                let labels = try? item.nestedContainer(keyedBy: AnswerKey.self, forKey: "labels")
                element = .products(StoryProductsElement(
                    showLabel: labels?.lenientString("show_carousel") ?? "",
                    hideLabel: labels?.lenientString("hide_carousel") ?? "",
                    products: (item.lenientList(ProductAnswer.self, "products") ?? []).map(\.product)
                ))
            case "text_block":
                element = .textBlock(StoryTextBlockElement(
                    text: item.lenientString("text_input") ?? "",
                    fontSize: item.lenientDouble("font_size") ?? StoryTextBlockElement.defaultFontSize,
                    fontType: item.lenientString("font_type") ?? "",
                    bold: item.lenientBool("bold") == true || item.lenientBool("text_bold") == true,
                    italic: item.lenientBool("italic") ?? false,
                    textAlign: item.lenientString("text_align") ?? "",
                    textColor: item.lenientString("text_color") ?? "",
                    backgroundColor: item.lenientString("text_background_color") ?? "",
                    backgroundOpacity: item.opacity("text_background_color_opacity"),
                    lineSpacing: item.lenientDouble("text_line_spacing") ?? 0,
                    yOffset: item.lenientDouble("y_offset") ?? 0,
                    promocode: item.lenientString("promocode")
                ))
            default:
                element = nil
            }
        }
    }

    /// A product; an empty object is none.
    private struct ProductAnswer: Decodable {
        let product: StoryProduct

        init(from decoder: Decoder) throws {
            let item = try decoder.container(keyedBy: AnswerKey.self)
            guard !item.allKeys.isEmpty else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "an empty product"))
            }
            let price = item.lenientDouble("price") ?? 0
            let oldPrice = item.lenientDouble("oldprice")
            product = StoryProduct(
                id: item.lenientString("id") ?? "",
                name: item.lenientString("name") ?? "",
                brand: item.lenientString("brand") ?? "",
                picture: item.lenientString("picture") ?? "",
                imageUrl: item.lenientString("image_url") ?? "",
                price: price,
                priceFormatted: item.lenientString("price_formatted") ?? "",
                // Without a discount the server sends the price itself.
                oldPrice: oldPrice.flatMap { $0 > price ? $0 : nil },
                oldPriceFormatted: item.lenientString("oldprice_formatted") ?? "",
                discountPercent: item.lenientDouble("discount_percent") ?? 0,
                promocode: item.lenientString("promocode") ?? "",
                priceWithPromocode: item.lenientDouble("price_with_promocode") ?? 0,
                priceWithPromocodeFormatted: item.lenientString("price_with_promocode_formatted") ?? "",
                currency: item.lenientString("currency") ?? "",
                url: item.lenientString("url") ?? "",
                deeplinkAndroid: item.lenientString("deeplink_android") ?? "",
                deeplinkIos: item.lenientString("deeplink_ios") ?? ""
            )
        }
    }
}

private extension KeyedDecodingContainer where Key == AnswerKey {

    /// An opacity of 0…1, as the account sends it and Flutter reads it: a string is percents with or
    /// without the sign (`"50%"`, `"50"`), a number above 1 is percents too, otherwise a fraction.
    /// Anything else, or none, is 0.
    func opacity(_ key: Key) -> Double {
        let number: Double?
        if let text = try? decodeIfPresent(String.self, forKey: key) {
            let digits = text.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)
            number = Double(digits).map { $0 / 100 }
        } else {
            number = lenientDouble(key).map { $0 > 1 ? $0 / 100 : $0 }
        }
        guard let value = number, value.isFinite, value > 0 else { return 0 }
        return min(value, 1)
    }
}
