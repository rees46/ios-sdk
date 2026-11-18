//
//  StoriesPackageTests.swift
//  REES46CoreTests
//
//  `stories.get` without a server: the request it builds, and what it makes of each answer of the
//  proposed fixture.
//

import XCTest
@_spi(Bridge) @testable import REES46

final class StoriesPackageTests: XCTestCase {

    func test_the_requests_of_the_stories_fixture_and_its_refusals() throws {
        let cases = try FixtureCase.load("stories").filter { $0.item.response == nil }
        XCTAssertFalse(cases.isEmpty)
        for item in cases {
            let make = { try StoriesAPIImpl.getRequest(code: item.args["code"] as? String ?? "") }
            if item.item.request != nil {
                FixtureMatching.assert(try make().coreRequest, is: item)
            } else {
                FixtureMatching.assertRefused(item, make)
            }
        }
    }

    func test_the_answers_of_the_stories_fixture_end_as_it_says() throws {
        // A case without an answer runs over the stub server (`StoriesPredictLoyaltySlidersTests`).
        let cases = try FixtureCase.load("stories").filter { $0.item.response?.status != nil }
        XCTAssertFalse(cases.isEmpty)
        for item in cases {
            let request = try StoriesAPIImpl.getRequest(code: item.args["code"] as? String ?? "")
            let result = try FixtureMatching.outcome(of: item, for: request, call: "stories.get")
            FixtureMatching.assert(result, as: item, json: Self.json(_:))
        }
    }

    func test_the_code_is_one_segment_of_the_path_and_a_blank_one_is_refused() throws {
        XCTAssertEqual(try StoriesAPIImpl.getRequest(code: "a/b c?d#e%").path, "stories/a%2Fb%20c%3Fd%23e%25")
        XCTAssertEqual(try StoriesAPIImpl.getRequest(code: "115bd0b6").path, "stories/115bd0b6")
        XCTAssertTrue(try StoriesAPIImpl.getRequest(code: "115bd0b6").query.isEmpty, "the core adds shop_id and did")
        XCTAssertThrowsError(try StoriesAPIImpl.getRequest(code: " \n")) { error in
            guard case .invalidArgument? = error as? Rees46.SdkError else { return XCTFail("\(error)") }
        }
    }

    func test_an_answer_without_a_body_is_not_a_block() throws {
        let request = try StoriesAPIImpl.getRequest(code: "115bd0b6")
        XCTAssertThrowsError(try request.decode(Data()))
        XCTAssertEqual(try request.decode(Data("{}".utf8)).stories.count, 0, "an object without stories is a block without them")
    }

    func test_the_opacity_of_a_text_block_reads_percents_and_fractions() throws {
        func opacity(_ value: String) throws -> Double {
            let json = #"{"stories":[{"slides":[{"elements":[{"type":"text_block","text_background_color_opacity":\#(value)}]}]}]}"#
            let block = try StoriesAPIImpl.getRequest(code: "c").decode(Data(json.utf8))
            guard case .textBlock(let text)? = block.stories.first?.slides.first?.elements.first else {
                XCTFail("no text block")
                return -1
            }
            return text.backgroundOpacity
        }
        XCTAssertEqual(try opacity(#""0%""#), 0)
        XCTAssertEqual(try opacity(#""100%""#), 1)
        XCTAssertEqual(try opacity(#""50""#), 0.5, accuracy: 1e-9)
        XCTAssertEqual(try opacity(#"" 25% ""#), 0.25, accuracy: 1e-9)
        XCTAssertEqual(try opacity("0.3"), 0.3, accuracy: 1e-9)
        XCTAssertEqual(try opacity("80"), 0.8, accuracy: 1e-9)
        XCTAssertEqual(try opacity("150"), 1, "at most 1")
        XCTAssertEqual(try opacity("null"), 0)
        XCTAssertEqual(try opacity(#""bad""#), 0)
        XCTAssertEqual(try opacity("-5"), 0)
    }

    func test_ids_come_as_numbers_and_a_slide_without_media_is_one_of_products() throws {
        let json = #"{"id":7,"stories":[{"id":39,"slides":[{"id":"39_0","type":"","duration":-3},{"id":40,"type":"gif"},{"id":41,"type":"video","duration":"7"}]}]}"#
        let block = try StoriesAPIImpl.getRequest(code: "c").decode(Data(json.utf8))
        XCTAssertEqual(block.id, "7")
        let slides = try XCTUnwrap(block.stories.first?.slides)
        XCTAssertEqual(slides.map(\.id), ["39_0", "40", "41"])
        XCTAssertEqual(slides.map(\.type), [.product, .product, .video])
        XCTAssertEqual(slides.map(\.duration), [10, 10, 7])
    }

    func test_the_stories_fixture_is_proposed_until_the_contract_has_one() {
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: ContractFixtures.url("stories").path),
            "the contract has stories.json now: copy it into contract-\(ContractFixtures.version) and remove the proposed one"
        )
    }

    // MARK: - The block by the contract's names

    static func json(_ block: StoriesBlock) -> [String: Any] {
        ["id": block.id, "stories": block.stories.map(json(story:))]
    }

    private static func json(story: Story) -> [String: Any] {
        [
            "id": story.id, "name": story.name, "avatar": story.avatar, "viewed": story.viewed, "pinned": story.pinned,
            "startPosition": story.startPosition, "slides": story.slides.map(json(slide:)),
        ]
    }

    private static func json(slide: StorySlide) -> [String: Any] {
        let type: String
        switch slide.type {
        case .image: type = "image"
        case .video: type = "video"
        case .product: type = "product"
        }
        return [
            "id": slide.id, "type": type, "background": slide.background, "backgroundColor": slide.backgroundColor,
            "preview": slide.preview, "duration": slide.duration, "elements": slide.elements.map(json(element:)),
        ]
    }

    private static func json(element: StoryElement) -> [String: Any] {
        switch element {
        case .button(let button):
            return [
                "type": "button", "title": button.title, "link": button.link, "linkAndroid": button.linkAndroid,
                "linkIos": button.linkIos, "background": button.background, "color": button.color, "textBold": button.textBold,
            ]
        case .product(let product):
            return ["type": "product", "title": product.title, "item": FixtureMatching.field(product.item.map(json(product:)))]
        case .products(let products):
            return [
                "type": "products", "showLabel": products.showLabel, "hideLabel": products.hideLabel,
                "products": products.products.map(json(product:)),
            ]
        case .textBlock(let text):
            return [
                "type": "textBlock", "text": text.text, "fontSize": text.fontSize, "fontType": text.fontType,
                "bold": text.bold, "italic": text.italic, "textAlign": text.textAlign, "textColor": text.textColor,
                "backgroundColor": text.backgroundColor, "backgroundOpacity": text.backgroundOpacity,
                "lineSpacing": text.lineSpacing, "yOffset": text.yOffset, "promocode": FixtureMatching.field(text.promocode),
            ]
        }
    }

    private static func json(product: StoryProduct) -> [String: Any] {
        [
            "id": product.id, "name": product.name, "brand": product.brand, "picture": product.picture,
            "imageUrl": product.imageUrl, "price": product.price, "priceFormatted": product.priceFormatted,
            "oldPrice": FixtureMatching.field(product.oldPrice), "oldPriceFormatted": product.oldPriceFormatted,
            "discountPercent": product.discountPercent, "promocode": product.promocode,
            "priceWithPromocode": product.priceWithPromocode, "priceWithPromocodeFormatted": product.priceWithPromocodeFormatted,
            "currency": product.currency, "url": product.url, "deeplinkAndroid": product.deeplinkAndroid,
            "deeplinkIos": product.deeplinkIos,
        ]
    }
}
