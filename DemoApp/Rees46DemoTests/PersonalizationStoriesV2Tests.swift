import XCTest
@_spi(PersonalizationUI) @testable import REES46

/// Stories V2 of the kit: the price splits the currency off the server's formatted string and
/// picks its kind from the product (promo code, then discount, then plain price), the timer
/// counts down in d/h/m/s, a text block is framed only when its fill shows, slides pick their
/// theme, the viewer's server data maps from the same `StoryContent` the legacy stories parse,
/// and the cover splits its ring into one arc per slide.
final class PersonalizationStoriesV2Tests: XCTestCase {

    // MARK: - Price: currency split

    private func split(_ formatted: String) -> [String?] {
        let parts = PersonalizationStoryPrice.splitCurrency(formatted)
        return [parts.amount, parts.currency]
    }

    func testCurrencyIsTheTrailingTokenWithoutDigits() {
        XCTAssertEqual(split("1 190 900 ₽"), ["1 190 900", "₽"])
        XCTAssertEqual(split("12,99 €"), ["12,99", "€"])
        XCTAssertEqual(split("9 999₽"), ["9 999", "₽"], "no space before the sign")
        XCTAssertEqual(split("1 190.00 руб."), ["1 190.00", "руб."])
        XCTAssertEqual(split("245\u{00A0}000\u{00A0}₽"), ["245\u{00A0}000", "₽"], "non-breaking spaces of server formatting")
    }

    func testWithoutATrailingTokenTheWholeStringIsTheAmount() {
        XCTAssertEqual(split("$140"), ["$140", nil])
        XCTAssertEqual(split("Free"), ["Free", nil])
        XCTAssertEqual(split(""), ["", nil])
    }

    // MARK: - Price: kind from the product

    private func product(_ item: [String: Any]) -> PersonalizationStorySlide.Offer? {
        let slide: [String: Any] = [
            "id": "39_0", "type": "", "duration": 10, "background": "",
            "elements": [
                ["type": "button", "title": "Buy", "link": "https://shop.example/p?utm=1", "link_ios": "https://shop.example/p"],
                ["type": "product", "item": item]
            ]
        ]
        let json: [String: Any] = ["id": 1, "stories": [["id": 39, "name": "Test", "slides": [slide]]]]
        return PersonalizationStory.list(json: json).first?.slides.first?.offer
    }

    private let base: [String: Any] = [
        "id": "216908", "name": "Надувной бассейн", "brand": "INTEX",
        "price": 19990, "price_formatted": "19 990 ₽",
        "oldprice": 27990, "oldprice_formatted": "27 990 ₽",
        "image_url": "https://img.example/216908.jpg", "picture": "https://img.example/180/216908.jpg",
        "url": "https://shop.example/p?recommended_by=stories", "deeplink_ios": "https://shop.example/p"
    ]

    private func merged(_ extra: [String: Any]) -> [String: Any] {
        base.merging(extra) { _, new in new }
    }

    func testAPromoCodeWinsOverTheDiscountAndShowsThePriceWithTheCode() {
        let offer = product(merged([
            "discount_percent": 28, "promocode": "PROMO", "price_with_promocode_formatted": "17 990 ₽"
        ]))

        XCTAssertEqual(offer?.priceKind, .promoCode("PROMO"))
        XCTAssertEqual(offer?.displayedPrice, "17 990 ₽")
        XCTAssertEqual(offer?.oldPrice, "27 990 ₽")
    }

    func testADiscountShowsItsPercent() {
        let offer = product(merged(["discount_percent": 28]))

        XCTAssertEqual(offer?.priceKind, .discount("28%"))
        XCTAssertEqual(offer?.displayedPrice, "19 990 ₽")
    }

    func testWithoutPromoCodeAndDiscountOnlyThePrice() {
        // The server sends `null` for a missing discount; an old price equal to the price is no old price.
        let offer = product(merged(["discount_percent": NSNull(), "oldprice": 19990, "oldprice_formatted": "19 990 ₽"]))

        XCTAssertEqual(offer?.priceKind, .price)
        XCTAssertNil(offer?.oldPrice)
    }

    func testTheProductMapsBrandImageAndTheIOSLink() {
        let offer = product(base)

        XCTAssertEqual(offer?.brand, "INTEX")
        XCTAssertEqual(offer?.imageUrl, "https://img.example/216908.jpg", "the original, not the 180 px picture")
        XCTAssertEqual(offer?.link, "https://shop.example/p", "deeplink_ios before url")
    }

    func testFractionalPricesAreComparedAsDecimals() {
        // 19 990.50 is less than 19 990.90: an Int parse would make them equal and drop the old price.
        let offer = product(merged([
            "price": 19990.5, "price_formatted": "19 990,50 ₽", "oldprice": "19990.90", "oldprice_formatted": "19 990,90 ₽",
            "discount_percent": 12.5
        ]))
        XCTAssertEqual(offer?.oldPrice, "19 990,90 ₽")
        XCTAssertEqual(offer?.discountPercent, 12.5)
        XCTAssertEqual(offer?.priceKind, .discount("12.5%"), "the fraction stays")

        let cheaper = product(merged(["price": "100.5", "oldprice": 100.25, "oldprice_formatted": "100,25 ₽"]))
        XCTAssertNil(cheaper?.oldPrice, "an old price below the price is not shown")
    }

    func testAPromoCodeWithoutAnOldPriceCrossesOutTheRegularPrice() {
        let offer = product(merged([
            "oldprice": NSNull(), "oldprice_formatted": "", "promocode": "SALE", "price_with_promocode_formatted": "17 990 ₽"
        ]))
        XCTAssertEqual(offer?.displayedPrice, "17 990 ₽")
        XCTAssertEqual(offer?.crossedOutPrice, "19 990 ₽", "the regular price, crossed out")

        let same = product(merged(["oldprice": 0, "promocode": "SALE", "price_with_promocode_formatted": "19 990 ₽"]))
        XCTAssertNil(same?.crossedOutPrice, "nothing to cross out when the code does not change the price")

        let dearer = product(merged(["oldprice": 0, "promocode": "SALE", "price_with_promocode_formatted": "21 990 ₽"]))
        XCTAssertNil(dearer?.crossedOutPrice, "a regular price below the promo price is not crossed out")
        XCTAssertEqual(PersonalizationStorySlide.Offer.amount("1 190 900,50 ₽"), 1_190_900.5)

        let withOld = product(merged(["promocode": "SALE", "price_with_promocode_formatted": "17 990 ₽"]))
        XCTAssertEqual(withOld?.crossedOutPrice, "27 990 ₽", "the old price wins when there is one")
    }

    func testThePromoCaptionIsTheAdminTitle() {
        let element: [String: Any] = ["type": "product", "title": "Your code", "item": merged(["promocode": "SALE"])]
        XCTAssertEqual(PersonalizationStorySlide.Offer(element: element)?.promoCaption, "Your code")
        XCTAssertNil(product(merged(["promocode": "SALE"]))?.promoCaption, "no title: the host text")
    }

    func testAProductSlideButtonOpensItsOwnLinkElseTheProduct() {
        let item = merged([:])
        let slide: [String: Any] = [
            "id": 7, "type": "", "elements": [
                ["type": "button", "title": "Own", "link": "https://shop.example/web", "link_ios": "https://shop.example/ios"],
                ["type": "button", "title": "Web only", "link": "https://shop.example/web"],
                ["type": "button", "title": "No link"],
                ["type": "product", "item": item]
            ]
        ]
        let json: [String: Any] = ["stories": [["id": 1, "slides": [slide]]]]
        guard let mapped = PersonalizationStory.list(json: json).first?.slides.first else { return XCTFail("no slide") }
        XCTAssertEqual(mapped.buttons.map { mapped.link(of: $0) }, [
            "https://shop.example/ios", "https://shop.example/web", "https://shop.example/p"
        ])
        XCTAssertNotNil(mapped.buttons.first?.element, "the element goes to the communication delegate")
        if case .product(let element)? = mapped.offer?.source {
            XCTAssertEqual(element.product?.promocode, "")
        } else {
            XCTFail("the product element is kept for the delegate")
        }
    }

    func testTextBlocksTakeThePresetLineHeightAndTheirPromoCode() {
        let slide: [String: Any] = [
            "id": 1, "type": "image", "background": "https://img.example/a.jpg", "elements": [
                ["type": "text_block", "text_input": "Large", "font_size": 48],
                ["type": "text_block", "text_input": "Medium", "font_size": "30", "text_align": "end"],
                ["type": "text_block", "text_input": "Spaced", "font_size": "20", "text_line_spacing": "1.5"],
                ["type": "text_block", "text_input": "Code", "promocode": "TEXT10", "text_align": "start"],
                ["type": "text_block", "text_input": "   "]
            ]
        ]
        let json: [String: Any] = ["stories": [["id": 1, "slides": [slide]]]]
        let blocks = PersonalizationStory.list(json: json).first?.slides.first?.textBlocks ?? []
        XCTAssertEqual(blocks.map(\.style), [
            .large, .medium, PersonalizationStoryTextBlock.Style(size: 20, lineHeight: 30), .small
        ], "no line spacing: the preset of the size; a blank block is skipped")
        XCTAssertEqual(blocks[1].alignment, .right)
        XCTAssertEqual(blocks[3].alignment, .natural)
        XCTAssertEqual(blocks[3].promoCode, "TEXT10")
        XCTAssertEqual(PersonalizationStoryTextBlock.Style.presetLineHeight(for: 25), 30, "the small preset's ratio")
    }

    func testMissingLineSpacingTieGoesToTheLargerPreset() {
        let height = PersonalizationStoryTextBlock.Style.presetLineHeight
        XCTAssertEqual(height(39), 39, "a tie between Medium and Large goes to Large (1.0)")
        XCTAssertEqual(height(40), 40, "nearer to Large")
        XCTAssertEqual(height(38), 46, "nearer to Medium: round(38 × 1.2)")
        XCTAssertEqual(height(48), 48)
        XCTAssertEqual(height(30), 36)
        XCTAssertEqual(height(20), 24)
        XCTAssertEqual(height(12), 14, "below Small: round(12 × 1.2)")
    }

    func testDynamicSlideIdsAndNumericIdsAreKept() {
        let json: [String: Any] = ["stories": [["id": "39", "slides": [["id": "39_0", "type": ""], ["id": 12, "type": "image"]]]]]
        XCTAssertEqual(PersonalizationStory.list(json: json).first?.slides.map(\.id), ["39_0", "12"])
    }

    // MARK: - Server data

    func testSlidesMapKindButtonsCarouselAndTextBlocks() {
        let slide: [String: Any] = [
            "id": 37, "type": "", "duration": 7, "background": "", "background_color": "#000000",
            "elements": [
                ["type": "button", "title": "Go gaming!", "link": "https://demo.example/", "link_ios": ""],
                ["type": "button", "title": ""],
                ["type": "products",
                 "labels": ["show_carousel": "Товары для геймеров", "hide_carousel": "Скрыть товары"],
                 "products": [
                    ["name": "Mouse", "price": 12990, "price_formatted": "12 990 ₽",
                     "oldprice": 15990, "oldprice_formatted": "15 990 ₽", "picture": "https://img.example/m.jpg",
                     "url": "https://shop.example/m"],
                    ["name": "Keyboard", "price": 47790, "price_formatted": "47 790 ₽",
                     "oldprice": 47790, "oldprice_formatted": "47 790 ₽", "url": "https://shop.example/k"]
                 ]],
                ["type": "text_block", "text_input": "Sale", "font_size": "30", "text_line_spacing": "1.2",
                 "text_align": "center", "text_color": "#FFFFFF", "text_background_color": "#00FF00",
                 "text_background_color_opacity": "50%", "y_offset": "25", "bold": true]
            ]
        ]
        let empty: [String: Any] = ["id": 41, "name": "Empty", "slides": [[String: Any]]()]
        let json: [String: Any] = ["id": 1, "stories": [
            ["id": 40, "name": "Gaming", "avatar": "https://img.example/a.jpg", "pinned": true, "start_position": 0, "slides": [slide]],
            empty,
            ["id": "40", "name": "Gaming again", "slides": [slide]]
        ]]

        let stories = PersonalizationStory.list(json: json)
        XCTAssertEqual(stories.map(\.id), ["40"], "a story without slides and a repeated id are dropped")
        XCTAssertEqual(stories.first?.name, "Gaming", "the first of the repeated ids stays")
        guard let mapped = stories.first?.slides.first else { return XCTFail("no slide") }

        XCTAssertEqual(mapped.id, "37")
        XCTAssertEqual(mapped.kind, .content)
        XCTAssertEqual(mapped.duration, 7)
        XCTAssertEqual(mapped.buttons.map(\.title), ["Go gaming!"], "a button without a title is not drawn")
        XCTAssertEqual(mapped.buttons.first?.link, "https://demo.example/", "empty link_ios falls back to link")

        XCTAssertEqual(mapped.products?.showLabel, "Товары для геймеров")
        XCTAssertEqual(mapped.products?.items.map(\.name), ["Mouse", "Keyboard"])
        XCTAssertEqual(mapped.products?.items.first?.oldPrice, "15 990 ₽")
        XCTAssertEqual(mapped.products?.items.first?.discountPercent, 19, "(15990 - 12990) / 15990")
        XCTAssertNil(mapped.products?.items.last?.oldPrice)

        guard let block = mapped.textBlocks.first else { return XCTFail("no text block") }
        XCTAssertEqual(block.style, PersonalizationStoryTextBlock.Style(size: 30, lineHeight: 36))
        XCTAssertEqual(block.alignment, .center)
        XCTAssertTrue(block.bold)
        XCTAssertEqual(block.yOffset, 25)
        XCTAssertEqual(block.fill?.cgColor.alpha ?? 0, 0.5, accuracy: 0.001)
        XCTAssertEqual(mapped.interfaceStyle, .unspecified, "no media: the app theme, whatever the background colour")
    }

    func testSlideKindFollowsTheServerType() {
        XCTAssertEqual(PersonalizationStorySlide.kind(of: "image"), .image)
        XCTAssertEqual(PersonalizationStorySlide.kind(of: "video"), .video)
        XCTAssertEqual(PersonalizationStorySlide.kind(of: ""), .content)
    }

    func testMediaSlidesAreDarkOthersFollowTheApp() {
        XCTAssertEqual(PersonalizationStorySlide(id: "1", kind: .image, background: "https://img.example/a.jpg").interfaceStyle, .dark)
        XCTAssertEqual(PersonalizationStorySlide(id: "2", kind: .video, background: "https://video.example/a.mp4").interfaceStyle, .dark)
        XCTAssertEqual(PersonalizationStorySlide(id: "3", kind: .content).interfaceStyle, .unspecified)
        XCTAssertEqual(PersonalizationStorySlide(id: "4", kind: .content, backgroundColor: .black).interfaceStyle, .unspecified,
                       "background_color only paints the letterbox")
        XCTAssertEqual(PersonalizationStorySlide(id: "5", kind: .content, background: "https://img.example/bg.jpg").interfaceStyle, .dark,
                       "a photo behind a content slide is media too")
    }

    func testAMissingDurationFallsBackToTenSeconds() {
        XCTAssertEqual(PersonalizationStorySlide(id: "1", kind: .image, duration: 0).duration, 10)
        let json: [String: Any] = ["stories": [["id": 1, "slides": [["id": 2, "type": "image", "background": "https://img.example/a.jpg"]]]]]
        XCTAssertEqual(PersonalizationStory.list(json: json).first?.slides.first?.duration, 10)
    }

    func testAPinnedStoryStaysPinnedOnceViewedOthersTurnGrey() {
        let slides = [PersonalizationStorySlide(id: "1", kind: .content), PersonalizationStorySlide(id: "2", kind: .content)]
        let state = StoriesSeenState(sdk: nil)

        let pinned = state.barItem(PersonalizationStory(id: "p", name: "P", pinned: true, viewed: true, slides: slides))
        XCTAssertEqual(pinned.state, .pinned, "Semantic/Warning ring and the star")
        XCTAssertEqual(pinned.seen, [], "a finished pinned ring is not lightened")
        XCTAssertEqual(pinned.segments, 0, "a plain warning ring")

        let plain = state.barItem(PersonalizationStory(id: "v", name: "V", viewed: true, slides: slides))
        XCTAssertEqual(plain.state, .viewed)
        XCTAssertEqual(plain.segments, 0, "a viewed ring is solid")

        let fresh = state.barItem(PersonalizationStory(id: "d", name: "D", slides: slides))
        XCTAssertEqual(fresh.state, .default)
        XCTAssertEqual(fresh.segments, 2)
    }

    func testTheRingLightsSeenSlidesByIndex() {
        let slides = (1...4).map { PersonalizationStorySlide(id: String($0), kind: .content) }
        let story = PersonalizationStory(id: "s", name: "S", slides: slides)

        let item = StoriesSeenState.barItem(story, seen: ["2", "4"])
        XCTAssertEqual(item.state, .default)
        XCTAssertEqual(item.segments, 4)
        XCTAssertEqual(item.seen, [1, 3], "segment i is lit iff slide i is seen")

        let done = StoriesSeenState.barItem(story, seen: ["1", "2", "3", "4"])
        XCTAssertEqual(done.state, .viewed, "every slide seen is viewed")
        XCTAssertEqual(done.segments, 0)

        let pinned = StoriesSeenState.barItem(PersonalizationStory(id: "p", name: "P", pinned: true, slides: slides), seen: ["3"])
        XCTAssertEqual(pinned.state, .pinned)
        XCTAssertEqual(pinned.seen, [2])
    }

    func testAViewedCoverDrawsASolidRingWhateverItsSegments() {
        let cover = PersonalizationStoryCover(state: .viewed)
        cover.segments = 5
        cover.seen = [0, 1]
        XCTAssertEqual(cover.arcCount, 1)
        cover.state = .default
        XCTAssertEqual(cover.arcCount, 5)
        XCTAssertEqual(cover.color(ofSegment: 1), PersonalizationColor.buttonPrimaryDisabled)
        XCTAssertEqual(cover.color(ofSegment: 2), PersonalizationColor.buttonPrimary)
    }

    func testTheStartSlideFollowsWhatWasSeen() {
        let slides = (1...4).map { PersonalizationStorySlide(id: String($0), kind: .content) }
        let story = PersonalizationStory(id: "s", name: "S", startPosition: 2, slides: slides)
        XCTAssertEqual(StoriesSeenState.startSlide(story, seen: []), 2, "untouched: the server start position")
        XCTAssertEqual(StoriesSeenState.startSlide(story, seen: ["1", "3"]), 1, "started: the first unseen in order")
        XCTAssertEqual(StoriesSeenState.startSlide(story, seen: ["1", "2", "3", "4"]), 0, "viewed: from the start")

        let viewed = PersonalizationStory(id: "v", name: "V", viewed: true, startPosition: 2, slides: slides)
        XCTAssertEqual(StoriesSeenState.startSlide(viewed, seen: []), 0, "viewed by the server: from the start")

        let far = PersonalizationStory(id: "f", name: "F", startPosition: 9, slides: slides)
        XCTAssertEqual(StoriesSeenState.startSlide(far, seen: []), 3, "clamped to the story")
    }

    func testASlideWithoutMediaSitsOnBackgroundCardWhateverItsColour() {
        let offer = PersonalizationStorySlide.Offer(id: "1", name: "MacBook", price: "1 190 900 ₽")
        let plain = PersonalizationStorySlideView(
            slide: PersonalizationStorySlide(id: "1", kind: .content, offer: offer),
            texts: .init(), isMuted: true, imageLoader: { _, _ in }
        )
        XCTAssertEqual(plain.backgroundColor, PersonalizationColor.backgroundCard)
        XCTAssertEqual(plain.slide.interfaceStyle, .unspecified, "follows the app")

        let blue = UIColor(red: 0, green: 0x80 / 255.0, blue: 0xF0 / 255.0, alpha: 1)
        let coloured = PersonalizationStorySlideView(
            slide: PersonalizationStorySlide(id: "2", kind: .content, backgroundColor: blue, offer: offer),
            texts: .init(), isMuted: true, imageLoader: { _, _ in }
        )
        XCTAssertEqual(coloured.backgroundColor, PersonalizationColor.backgroundCard, "background_color is for the letterbox only")
        XCTAssertEqual(coloured.slide.interfaceStyle, .unspecified)

        let photo = PersonalizationStorySlideView(
            slide: PersonalizationStorySlide(id: "3", kind: .image, background: "https://img.example/a.jpg", backgroundColor: blue),
            texts: .init(), isMuted: true, imageLoader: { _, _ in }
        )
        XCTAssertEqual(photo.backgroundColor, blue, "the letterbox around the fitted photo")
    }

    // MARK: - Timer

    func testTimerSplitsTheRestIntoDaysHoursMinutesSeconds() {
        let rest: TimeInterval = ((2 * 24 + 18) * 60 + 33) * 60 + 24
        XCTAssertEqual(PersonalizationStoryTimer.texts(remaining: rest), ["2", "18", "33", "24"])
    }

    func testTimerPadsAllButDaysAndRoundsSecondsDown() {
        XCTAssertEqual(PersonalizationStoryTimer.texts(remaining: 3_725.9), ["0", "01", "02", "05"])
        XCTAssertEqual(PersonalizationStoryTimer.texts(remaining: 100 * 86_400), ["100", "00", "00", "00"])
    }

    func testTimerKeepsTwoDigitsForHoursMinutesSeconds() {
        let rest: TimeInterval = ((2 * 24 + 8) * 60 + 3) * 60 + 4
        XCTAssertEqual(PersonalizationStoryTimer.texts(remaining: rest), ["2", "08", "03", "04"], "2d 08h 03m 04s")
    }

    func testTimerStopsAtZero() {
        XCTAssertEqual(PersonalizationStoryTimer.texts(remaining: -5), ["0", "00", "00", "00"])
    }

    // MARK: - Text block

    func testASolidBlockGetsTheKitFrameATransparentOneDoesNot() {
        let solid = PersonalizationStorySlide.TextBlock.fill(color: "#00AA00", opacity: "100%")
        let half = PersonalizationStorySlide.TextBlock.fill(color: "#00AA00", opacity: "50%")
        let invisible = PersonalizationStorySlide.TextBlock.fill(color: "#00AA00", opacity: "0%")
        let noColour = PersonalizationStorySlide.TextBlock.fill(color: "", opacity: "100%")

        XCTAssertTrue(PersonalizationStoryTextBlock.isSolid(solid))
        XCTAssertTrue(PersonalizationStoryTextBlock.isSolid(half))
        XCTAssertFalse(PersonalizationStoryTextBlock.isSolid(invisible))
        XCTAssertFalse(PersonalizationStoryTextBlock.isSolid(noColour))
        XCTAssertNil(noColour)
    }

    func testSolidPaddingIs12ForLargeTextAnd8OtherwiseTransparentHasNone() {
        let large = PersonalizationStoryTextBlock.insets(style: .large, solid: true)
        let medium = PersonalizationStoryTextBlock.insets(style: .medium, solid: true)
        let small = PersonalizationStoryTextBlock.insets(style: .small, solid: true)

        XCTAssertEqual(large, UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16))
        XCTAssertEqual(medium, UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16))
        XCTAssertEqual(small, UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16))
        XCTAssertEqual(PersonalizationStoryTextBlock.insets(style: .large, solid: false), .zero)
    }

    func testTheBlockFramesItselfByItsFill() {
        let block = PersonalizationStoryTextBlock(text: "Sale", style: .large, fill: .green)
        XCTAssertTrue(block.isSolid)
        XCTAssertEqual(block.layer.cornerRadius, 12)

        block.fill = UIColor.green.withAlphaComponent(0)
        XCTAssertFalse(block.isSolid)
        XCTAssertEqual(block.layer.cornerRadius, 0)
    }

    func testOpacityStringsFromTheAdmin() {
        XCTAssertEqual(PersonalizationStoryColors.opacity("0%"), 0)
        XCTAssertEqual(PersonalizationStoryColors.opacity("35%") ?? -1, 0.35, accuracy: 0.0001)
        XCTAssertEqual(PersonalizationStoryColors.opacity("100%"), 1)
        XCTAssertEqual(PersonalizationStoryColors.opacity("0.5") ?? -1, 0.5, accuracy: 0.0001)
        XCTAssertNil(PersonalizationStoryColors.opacity(""))
        XCTAssertNil(PersonalizationStoryColors.opacity("abc"))
    }

    func testHexColoursFromTheAdmin() {
        XCTAssertNotNil(PersonalizationStoryColors.parse("#3b82f6"))
        XCTAssertNotNil(PersonalizationStoryColors.parse("fff"))
        XCTAssertEqual(PersonalizationStoryColors.parse("#00000080")?.cgColor.alpha ?? 0, 128.0 / 255, accuracy: 0.001)
        XCTAssertNil(PersonalizationStoryColors.parse(""))
        XCTAssertNil(PersonalizationStoryColors.parse("#12"))
        XCTAssertNil(PersonalizationStoryColors.parse("not a colour"))
    }

    // MARK: - Cover and progress

    func testTheRingSplitsIntoOneArcPerSlideWithEqualGaps() {
        let gap: CGFloat = 0.1
        let arcs = PersonalizationStoryCover.segmentAngles(count: 4, gapAngle: gap)

        XCTAssertEqual(arcs.count, 4)
        XCTAssertEqual(arcs[0].start, -.pi / 2 + gap / 2, accuracy: 0.0001, "the first arc starts at the top")
        for index in 1..<arcs.count {
            XCTAssertEqual(arcs[index].start - arcs[index - 1].end, gap, accuracy: 0.0001)
        }
        let swept = arcs.reduce(0) { $0 + $1.end - $1.start }
        XCTAssertEqual(swept + 4 * gap, 2 * .pi, accuracy: 0.0001)
    }

    func testASingleSlideIsASolidRing() {
        let arcs = PersonalizationStoryCover.segmentAngles(count: 1, gapAngle: 0.1)
        XCTAssertEqual(arcs.count, 1)
        XCTAssertEqual(arcs[0].end - arcs[0].start, 2 * .pi, accuracy: 0.0001)
    }

    func testProgressFillsPastSlidesAndPartOfTheCurrent() {
        let progress = PersonalizationStoryProgress(count: 4)
        progress.current = 2
        progress.progress = 0.4

        XCTAssertEqual([0, 1, 2, 3].map { progress.fraction(of: $0) }, [1, 1, 0.4, 0])
    }

    // MARK: - Layout

    /// Never shown, but a window: the views lay out the way they do on screen.
    private var host: UIWindow!

    override func setUp() {
        super.setUp()
        host = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
    }

    override func tearDown() {
        host = nil
        super.tearDown()
    }

    /// The view pinned to the top of the host at `width`, height by its own constraints.
    @discardableResult
    private func laidOut<T: UIView>(_ view: T, width: CGFloat = 370) -> T {
        view.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: host.topAnchor),
            view.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            view.widthAnchor.constraint(equalToConstant: width)
        ])
        host.layoutIfNeeded()
        return view
    }

    /// Left and right columns of the price: the row is the only stack directly inside.
    private func columns(_ price: PersonalizationStoryPrice) -> (left: UIView, right: UIView) {
        let row = price.subviews.compactMap { $0 as? UIStackView }.first!
        return (row.arrangedSubviews[0], row.arrangedSubviews[1])
    }

    func testThePriceBoxIs70HighWithTheOldPrice() {
        let price = laidOut(PersonalizationStoryPrice(price: "1 190 900 ₽", oldPrice: "1 245 000 ₽"))
        XCTAssertEqual(price.frame.height, 70, accuracy: 0.5, "12 + 16 + 30 + 12")
        XCTAssertTrue(columns(price).right.isHidden)
    }

    func testPromoColumnsShareTheWidthAndALongCodeTakesMore() {
        let short = laidOut(PersonalizationStoryPrice(price: "1 190 900 ₽", oldPrice: "1 245 000 ₽", kind: .promoCode("PROMO")))
        let halves = columns(short)
        XCTAssertEqual(short.frame.height, 70, accuracy: 0.5, "12 + 16 + 30 + 12 on both sides")
        XCTAssertEqual(halves.left.frame.width, halves.right.frame.width, accuracy: 0.5)
        XCTAssertEqual(halves.left.frame.width + halves.right.frame.width, 370, accuracy: 0.5)

        let long = laidOut(PersonalizationStoryPrice(price: "1 190 900 ₽", kind: .promoCode("YAGODA-MALINA-2026")))
        let split = columns(long)
        XCTAssertGreaterThan(split.right.frame.width, split.left.frame.width)
        XCTAssertEqual(split.left.frame.width + split.right.frame.width, 370, accuracy: 0.5)
    }

    func testThePromoCodeZoomsTo103PercentUnderTheFinger() {
        XCTAssertEqual(PersonalizationStoryPrice.pressedScale, 1.03)
    }

    func testTheDiscountBlockHugsItsTextAndThePriceTakesTheRest() {
        let price = laidOut(PersonalizationStoryPrice(price: "1 190 900 ₽", oldPrice: "1 245 000 ₽", kind: .discount("10%")))
        let parts = columns(price)
        XCTAssertLessThan(parts.right.frame.width, 150)
        XCTAssertEqual(parts.left.frame.width + parts.right.frame.width, 370, accuracy: 0.5)
        XCTAssertEqual(parts.right.frame.height, price.frame.height, accuracy: 0.5)
    }

    func testTimerMergedIsOnePillSeparateIsFourEqualBoxes() {
        let merged = laidOut(PersonalizationStoryTimer(endDate: Date().addingTimeInterval(3_600), view: .merged))
        XCTAssertEqual(merged.frame.height, 60, accuracy: 0.5, "8 + 44 + 8")

        let separate = laidOut(PersonalizationStoryTimer(endDate: Date().addingTimeInterval(3_600), view: .separate))
        let boxes = (separate.subviews.first as? UIStackView)?.arrangedSubviews ?? []
        XCTAssertEqual(boxes.count, 4)
        let widths = boxes.map(\.frame.width)
        XCTAssertEqual(widths.max() ?? 0, widths.min() ?? 1, accuracy: 0.5, "equal widths")
        XCTAssertEqual(boxes.last?.frame.maxX ?? 0, 370, accuracy: 0.5)
    }

    func testCoverAndPreviewKeepTheirSize() {
        let preview = laidOut(PersonalizationStoryPreview(title: "A very long story name", state: .pinned), width: 88)
        XCTAssertEqual(preview.frame.height, 88 + 8 + 32, accuracy: 0.5, "room for two label lines")
        let label = preview.subviews.flatMap(\.subviews).flatMap(\.subviews).compactMap { $0 as? UILabel }.first
        XCTAssertEqual(label?.numberOfLines, 2)
        XCTAssertEqual(label?.lineBreakMode, .byTruncatingTail)
        XCTAssertGreaterThan(label?.frame.height ?? 0, 20, "a long name wraps to a second line")
        XCTAssertEqual(preview.cover.frame.size, CGSize(width: 88, height: 88))
        XCTAssertEqual(preview.cover.imageView.frame, CGRect(x: 6, y: 6, width: 76, height: 76))

        let bar = laidOut(PersonalizationStoriesBar(), width: 402)
        XCTAssertEqual(bar.frame.height, 16 + 128 + 16, accuracy: 0.5)
    }

    func testTheProductSlideFitsTheSquareCardBetweenTheHeaderAndThePrice() {
        let slide = PersonalizationStorySlide(
            id: "1", kind: .content,
            offer: PersonalizationStorySlide.Offer(id: "1", brand: "Apple", name: "MacBook Pro 16", price: "1 190 900 ₽", discountPercent: 10)
        )
        let view = PersonalizationStorySlideView(slide: slide, texts: .init(), isMuted: true, imageLoader: { _, _ in })
        view.safeInsets = Self.islandInsets
        view.frame = host.bounds
        host.addSubview(view)
        host.layoutIfNeeded()

        let card = view.subviews.first { $0.backgroundColor == .white }
        let price = view.subviews.compactMap { $0 as? UIStackView }.first { $0.arrangedSubviews.first is PersonalizationStoryPrice }
        guard let card, let price else { return XCTFail("no card or price") }
        XCTAssertEqual(card.frame.width, card.frame.height, accuracy: 0.5, "square")
        XCTAssertEqual(card.frame.width, 370, accuracy: 0.5, "full content width on a tall screen")
        XCTAssertLessThanOrEqual(card.frame.maxY, price.frame.minY - 16 + 0.5)
        XCTAssertEqual(price.frame.maxY, 874 - 34 - 16, accuracy: 0.5, "16 above the safe area")
        XCTAssertEqual(view.contentGuide.layoutFrame.minY, 62 + 16, accuracy: 0.5, "16 below the Dynamic Island")
    }

    func testOnAShortScreenTheCardShrinksInsteadOfOverlapping() {
        host.frame = CGRect(x: 0, y: 0, width: 375, height: 560)
        let slide = PersonalizationStorySlide(
            id: "1", kind: .content, buttons: [.init(title: "Buy")],
            offer: PersonalizationStorySlide.Offer(id: "1", brand: "Apple", name: "MacBook Pro 16", price: "1 190 900 ₽", promoCode: "PROMO")
        )
        let view = PersonalizationStorySlideView(slide: slide, texts: .init(), isMuted: true, imageLoader: { _, _ in })
        view.frame = host.bounds
        host.addSubview(view)
        host.layoutIfNeeded()

        let card = view.subviews.first { $0.backgroundColor == .white }
        let price = view.subviews.compactMap { $0 as? UIStackView }.first { $0.arrangedSubviews.first is PersonalizationStoryPrice }
        guard let card, let price else { return XCTFail("no card or price") }
        XCTAssertLessThan(card.frame.width, 343)
        XCTAssertEqual(card.frame.width, card.frame.height, accuracy: 0.5)
        XCTAssertLessThanOrEqual(card.frame.maxY, price.frame.minY - 16 + 0.5)
    }

    func testAMediaSlidePutsProductsAtTheBottomAndTextBlocksAtTheirOffset() {
        let slide = PersonalizationStorySlide(
            id: "1", kind: .video, background: "https://video.example/a.mp4",
            products: .init(items: [PersonalizationStorySlide.Offer(id: "1", name: "Mouse", price: "12 990 ₽")]),
            textBlocks: [.init(text: "Sale", style: .large, fill: .green, yOffset: 50)]
        )
        let view = PersonalizationStorySlideView(slide: slide, texts: .init(), isMuted: true, imageLoader: { _, _ in })
        view.safeInsets = Self.islandInsets
        view.frame = host.bounds
        host.addSubview(view)
        host.layoutIfNeeded()

        let block = view.subviews.first { $0 is PersonalizationStoryTextBlock }
        let used = view.subviews.first { $0 is PersonalizationStoryUsedProducts }
        XCTAssertEqual(block?.frame.minY ?? 0, 437, accuracy: 0.5, "50% of 874")
        XCTAssertEqual(block?.frame.width ?? 0, 370, accuracy: 0.5)
        XCTAssertEqual(used?.frame.height ?? 0, 64, accuracy: 0.5, "collapsed: the row only")
        XCTAssertEqual(used?.frame.maxY ?? 0, 874 - 34, accuracy: 0.5, "on the safe area: the row has its own 16")
        XCTAssertEqual(view.scrim.strength, 0.3, "a text block: the light scrim")
        let background = view.subviews.first { $0 is UIImageView }
        XCTAssertEqual(background?.frame, view.bounds, "the background still goes edge to edge")
        view.stop()
    }

    func testExpandedUsedProductsShowTheCarouselOnTheCardSheet() {
        let used = PersonalizationStoryUsedProducts()
        used.products = (0..<3).map { PersonalizationProduct(id: String($0), name: "Product \($0)", price: "9 999 ₽") }
        used.leadingView = PersonalizationStorySoundButton()
        laidOut(used, width: 402)
        XCTAssertEqual(used.frame.height, 64, accuracy: 0.5, "collapsed: the row only")

        used.isExpanded = true
        host.layoutIfNeeded()
        XCTAssertGreaterThan(used.list.frame.height, 100, "the carousel has its cards' height")
        XCTAssertEqual(used.frame.height, 16 + used.list.frame.height + 16 + 64, accuracy: 0.5)
        XCTAssertEqual(used.backgroundColor, PersonalizationColor.backgroundCard)
    }

    func testThePagePutsTheSlideUnderTheNavigation() {
        let story = PersonalizationStory(id: "s", name: "S", slides: [
            PersonalizationStorySlide(
                id: "1", kind: .content,
                offer: PersonalizationStorySlide.Offer(id: "1", brand: "Apple", name: "MacBook", price: "1 190 900 ₽", promoCode: "PROMO")
            )
        ])
        let viewer = PersonalizationStoriesViewController(stories: [story])
        let page = PersonalizationStoryPageViewController(story: story, storyIndex: 0, startSlide: 0, viewer: viewer)
        page.safeInsets = Self.islandInsets
        page.view.frame = host.bounds
        host.addSubview(page.view)
        host.layoutIfNeeded()

        func all(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap(all) }
        let views = all(page.view)
        guard let navigation = views.first(where: { $0 is PersonalizationStoryNavigation }),
              let slide = views.first(where: { $0 is PersonalizationStorySlideView }) as? PersonalizationStorySlideView
        else { return XCTFail("no navigation or slide") }
        let navigationFrame = navigation.convert(navigation.bounds, to: page.view)
        XCTAssertEqual(navigationFrame.height, 46, accuracy: 0.5, "2 + 12 + 32")
        XCTAssertEqual(navigationFrame.width, 402 - 32, accuracy: 0.5)
        XCTAssertEqual(navigationFrame.minY, 62 + 16, accuracy: 0.5, "16 below the Dynamic Island, not under it")
        XCTAssertEqual(slide.contentGuide.layoutFrame.minY, navigationFrame.maxY + 16, accuracy: 0.5)
        XCTAssertEqual(slide.safeInsets, Self.islandInsets, "the slide gets the page's safe area")

        // A new safe area (rotation, a call bar) moves the controls, not the background.
        page.safeInsets = UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0)
        host.layoutIfNeeded()
        XCTAssertEqual(navigation.convert(navigation.bounds, to: page.view).minY, 36, accuracy: 0.5)
        XCTAssertEqual(slide.frame, page.view.bounds)
    }

    func testTheViewerHandsItsSafeAreaToThePages() {
        let story = PersonalizationStory(id: "s", name: "S", slides: [PersonalizationStorySlide(id: "1", kind: .content)])
        let viewer = PersonalizationStoriesViewController(stories: [story])
        viewer.view.frame = host.bounds
        host.addSubview(viewer.view)
        host.layoutIfNeeded()
        viewer.view.layoutIfNeeded()

        let pager = viewer.children.compactMap { $0 as? UIPageViewController }.first
        let page = pager?.viewControllers?.first as? PersonalizationStoryPageViewController
        XCTAssertNotNil(page)
        XCTAssertEqual(page?.safeInsets, viewer.view.safeAreaInsets)
    }

    /// Safe area of a Dynamic Island phone in portrait.
    private static let islandInsets = UIEdgeInsets(top: 62, left: 0, bottom: 34, right: 0)

    // MARK: - Viewer

    func testTheViewerSkipsEmptyStoriesAndKeepsTheRequestedOne() {
        let stories = [
            PersonalizationStory(id: "a", name: "A", slides: []),
            PersonalizationStory(id: "b", name: "B", slides: [PersonalizationStorySlide(id: "1", kind: .content)])
        ]
        let viewer = PersonalizationStoriesViewController(stories: stories, startIndex: 1)
        XCTAssertEqual(viewer.stories.map(\.id), ["b"])
        XCTAssertEqual(viewer.currentIndex, 0)
        XCTAssertEqual(viewer.modalPresentationStyle, .fullScreen)
    }

    /// A viewer with its view loaded and its first page settled, as after `viewDidAppear`.
    private func settledViewer(_ stories: [PersonalizationStory]) -> PersonalizationStoriesViewController {
        let viewer = PersonalizationStoriesViewController(stories: stories)
        viewer.view.frame = host.bounds
        host.addSubview(viewer.view)
        if let page = viewer.pager.viewControllers?.first as? PersonalizationStoryPageViewController {
            viewer.settle(on: page)
        }
        return viewer
    }

    func testTheViewerWalksSlidesAndTheLastSlideOfTheLastStoryCloses() {
        let story = PersonalizationStory(id: "s", name: "S", startPosition: 1, slides: [
            PersonalizationStorySlide(id: "1", kind: .content),
            PersonalizationStorySlide(id: "2", kind: .content),
            PersonalizationStorySlide(id: "3", kind: .content)
        ])
        var closed = 0
        let viewer = PersonalizationStoriesViewController(stories: [story])
        viewer.onClose = { closed += 1 }
        viewer.view.frame = host.bounds
        host.addSubview(viewer.view)
        guard let page = viewer.pager.viewControllers?.first as? PersonalizationStoryPageViewController else { return XCTFail("no page") }
        viewer.settle(on: page)
        XCTAssertEqual(page.slideIndex, 1, "starts at start_position")

        viewer.apply(viewer.state.previous())
        XCTAssertEqual(page.slideIndex, 0)
        viewer.apply(viewer.state.previous())
        XCTAssertEqual(page.slideIndex, 0, "no previous story: the first slide again")

        viewer.apply(viewer.state.next())
        viewer.apply(viewer.state.next())
        XCTAssertEqual(page.slideIndex, 2)
        viewer.apply(viewer.state.next())
        XCTAssertEqual(closed, 1, "past the last slide of the last story")
        viewer.apply(viewer.state.next())
        viewer.close()
        XCTAssertEqual(closed, 1, "closes once")
    }

    func testSlideViewsAreReportedWhenASlideBecomesCurrent() {
        let story = PersonalizationStory(id: "s", name: "S", slides: [
            PersonalizationStorySlide(id: "1", kind: .content),
            PersonalizationStorySlide(id: "2", kind: .content)
        ])
        var shown: [String] = []
        let viewer = PersonalizationStoriesViewController(stories: [story])
        viewer.onSlideView = { _, slide in shown.append(slide.id) }
        viewer.view.frame = host.bounds
        host.addSubview(viewer.view)
        XCTAssertEqual(shown, [], "not settled yet")
        guard let page = viewer.pager.viewControllers?.first as? PersonalizationStoryPageViewController else { return XCTFail("no page") }
        viewer.settle(on: page)
        viewer.settle(on: page)
        viewer.apply(viewer.state.next())
        XCTAssertEqual(shown, ["1", "2"])
    }

    func testEveryCloseCompletionRunsAndTapsStopOnceClosing() {
        let story = PersonalizationStory(id: "s", name: "S", slides: [
            PersonalizationStorySlide(id: "1", kind: .content, buttons: [.init(title: "Go", link: "https://shop.example")])
        ])
        let viewer = settledViewer([story])
        var taps = 0
        viewer.onButtonTap = { _, _, _ in taps += 1 }
        var completions: [Int] = []
        viewer.close { completions.append(1) }
        viewer.close { completions.append(2) }
        XCTAssertEqual(completions, [1, 2], "a second close does not drop its completion")
        viewer.buttonTapped(story, story.slides[0], story.slides[0].buttons[0])
        XCTAssertEqual(taps, 0, "taps during dismissal are ignored")
        viewer.close { completions.append(3) }
        XCTAssertEqual(completions, [1, 2, 3], "already closed: runs at once")
    }

    func testAnOpenSheetBlocksSwipesUntilATapClosesIt() {
        let story = PersonalizationStory(id: "s", name: "S", slides: [
            PersonalizationStorySlide(id: "1", kind: .image, background: "https://img.example/a.jpg",
                                      products: .init(items: [PersonalizationStorySlide.Offer(id: "1", name: "Mouse", price: "1 ₽")]))
        ])
        let viewer = settledViewer([story, story])
        guard let page = viewer.activePage else { return XCTFail("no page") }
        viewer.productsToggled(true, on: page)
        XCTAssertEqual(viewer.pagerScrollView?.isScrollEnabled, false)
        viewer.handleTap(at: 390, width: 402, from: page)
        XCTAssertEqual(viewer.state.slide, 0, "the tap only closed the sheet")
        XCTAssertFalse(viewer.state.isSheetOpen)
        XCTAssertEqual(viewer.pagerScrollView?.isScrollEnabled, true)
    }

    func testTheSoundButtonNamesTheCurrentSoundState() {
        let button = PersonalizationStorySoundButton(isMuted: true)
        button.soundOnLabel = "Sound on"
        button.soundOffLabel = "Sound off"
        XCTAssertEqual(button.accessibilityLabel, "Sound off", "muted: the label is the current state")
        XCTAssertTrue(button.accessibilityTraits.contains(.button))
        XCTAssertFalse(button.accessibilityTraits.contains(.selected))
        if #available(iOS 17.0, *) {
            XCTAssertTrue(button.accessibilityTraits.contains(.toggleButton))
        }

        button.sendActions(for: .touchUpInside)
        XCTAssertFalse(button.isMuted)
        XCTAssertEqual(button.accessibilityLabel, "Sound on")
        XCTAssertTrue(button.accessibilityTraits.contains(.selected), "sound on is the selected state")
    }

    // MARK: - Host API lifecycle

    /// Records what the widget presents instead of putting it on screen.
    private final class CapturingHost: UIViewController {
        var shown: [UIViewController] = []
        override func present(_ controller: UIViewController, animated: Bool, completion: (() -> Void)? = nil) {
            shown.append(controller)
        }
    }

    private func blockStories() -> [PersonalizationStory] {
        ["a", "b"].map { id in
            PersonalizationStory(id: id, name: id.uppercased(), slides: [PersonalizationStorySlide(id: "1", kind: .content)])
        }
    }

    func testOpenBeforeTheBlockLoadsRunsOnceItArrives() {
        let host = CapturingHost()
        let widget = PersonalizationStories(code: "block")
        widget.hostViewController = host
        widget.open(at: 1)
        XCTAssertTrue(host.shown.isEmpty, "nothing to open before the block loads")
        widget.loaded(blockStories())
        let viewer = host.shown.first as? PersonalizationStoriesViewController
        XCTAssertEqual(viewer?.currentIndex, 1, "the queued open runs after the load")

        viewer?.loadViewIfNeeded()
        widget.open(storyId: "a")
        XCTAssertEqual(host.shown.count, 1, "an open viewer pages instead of presenting a second one")
    }

    func testAnEmptyBlockDropsTheQueuedOpenAndQueuesNothing() {
        let widget = PersonalizationStories(code: "block")
        widget.open(storyId: "a")
        XCTAssertNotNil(widget.pendingOpen)
        widget.loaded([])
        XCTAssertNil(widget.pendingOpen)
        widget.open(at: 0)
        XCTAssertNil(widget.pendingOpen, "loaded and empty: nothing to wait for")
    }

    func testPauseAndResumeWithoutAViewerDoNothing() {
        let host = CapturingHost()
        let widget = PersonalizationStories(code: "block")
        widget.hostViewController = host
        widget.loaded(blockStories())
        widget.pause()
        widget.open(at: 0)
        guard let viewer = host.shown.first as? PersonalizationStoriesViewController else { return XCTFail("no viewer") }
        XCTAssertFalse(viewer.state.pauses.contains(.host), "a pause with no viewer is not carried over")
        widget.pause()
        XCTAssertTrue(viewer.state.pauses.contains(.host))
        widget.resume()
        XCTAssertFalse(viewer.state.pauses.contains(.host))
    }

    func testTheControllerKeepsAnOpenUntilItIsAttached() {
        let controller = PersonalizationStoriesController()
        controller.open(at: 1)
        let host = CapturingHost()
        let widget = PersonalizationStories(code: "block")
        widget.hostViewController = host
        controller.stories = widget
        widget.loaded(blockStories())
        XCTAssertEqual((host.shown.first as? PersonalizationStoriesViewController)?.currentIndex, 1)
    }

    func testShowWithoutACodeEndsWithOnErrorOnly() {
        var errors = 0
        var closes = 0
        PersonalizationStories.show(code: "", onError: { _ in errors += 1 }, onClose: { closes += 1 })
        XCTAssertEqual(errors, 1)
        XCTAssertEqual(closes, 0, "no viewer was shown, so it never closes")
    }
}
