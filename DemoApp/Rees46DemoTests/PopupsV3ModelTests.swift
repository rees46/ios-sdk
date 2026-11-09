import XCTest
import UIKit
@_spi(PersonalizationV3) @testable import REES46

/// The shared popups v3 fixtures (`Fixtures/popups_v3_*.json`, copied from the spec as they are):
/// what the API sends plus `_fixture` with the expectations every platform checks.
enum PopupsV3Fixtures {

    private final class BundleToken {}

    static func json(_ name: String, file: StaticString = #filePath, line: UInt = #line) -> [String: Any] {
        let resource = "popups_v3_" + name.replacingOccurrences(of: "-", with: "_")
        guard let url = Bundle(for: BundleToken.self).url(forResource: resource, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            XCTFail("Fixture \(resource).json is missing from the test bundle", file: file, line: line)
            return [:]
        }
        return object
    }

    static func expect(_ name: String) -> [String: Any] {
        (json(name)["_fixture"] as? [String: Any])?["expect"] as? [String: Any] ?? [:]
    }

    /// The popup of a single-popup fixture.
    static func popup(_ name: String) -> PopupV3? {
        PopupV3(json: json(name))
    }

    static func design(_ name: String) -> PopupV3Design {
        PopupV3Design(json: json(name)["design"] as? [String: Any] ?? [:])
    }

    static func element(_ name: String, _ id: String, file: StaticString = #filePath, line: UInt = #line) -> PopupV3Element {
        guard let element = design(name).elements.first(where: { $0.id == id }) else {
            XCTFail("No element \(id) in \(name)", file: file, line: line)
            return PopupV3Element(id: id, type: "text", style: [:])
        }
        return element
    }

    /// Spans of a fixture: `{text, bold?, italic?, underline?, strike?, overline?}`.
    static func spans(_ raw: Any?) -> [PopupV3Span] {
        (raw as? [[String: Any]] ?? []).map { item in
            PopupV3Span(
                text: item["text"] as? String ?? "",
                bold: item["bold"] as? Bool ?? false,
                italic: item["italic"] as? Bool ?? false,
                underline: item["underline"] as? Bool ?? false,
                strike: item["strike"] as? Bool ?? false,
                overline: item["overline"] as? Bool ?? false
            )
        }
    }
}

/// Popups v3, the model side: values, colors, markup, variables, the design grid, the frame and
/// every element's resolved style — against the shared fixtures.
final class PopupsV3ModelTests: XCTestCase {

    private let texts = PopupV3Texts.ru

    // MARK: - parsing.json

    func testColorsParseToCSSOrderOrNil() {
        let colors = PopupsV3Fixtures.json("parsing")["colors"] as? [[String: Any]] ?? []
        XCTAssertEqual(colors.count, 16)
        for vector in colors {
            let input = vector["in"] is NSNull ? nil : vector["in"]
            let expected = vector["out"] as? String
            XCTAssertEqual(CSSColor.parse(input)?.hex, expected, "\(String(describing: input))")
        }
    }

    func testNumbersReadLikeParseFloatWithFallback() {
        let numbers = PopupsV3Fixtures.json("parsing")["numbers"] as? [[String: Any]] ?? []
        XCTAssertEqual(numbers.count, 11)
        for vector in numbers {
            let input = vector["in"] is NSNull ? nil : vector["in"]
            let fallback = (vector["fallback"] as? NSNumber)?.doubleValue ?? 0
            let expected = (vector["out"] as? NSNumber)?.doubleValue
            XCTAssertEqual(PopupV3Value.num(input, fallback), expected, "\(String(describing: input))")
        }
    }

    func testBooleans() {
        let booleans = PopupsV3Fixtures.json("parsing")["booleans"] as? [[String: Any]] ?? []
        XCTAssertEqual(booleans.count, 6)
        for vector in booleans {
            let input = vector["in"] is NSNull ? nil : vector["in"]
            XCTAssertEqual(PopupV3Value.bool(input), vector["out"] as? Bool, "\(String(describing: input))")
        }
    }

    // MARK: - markup.json

    func testMarkupSpansAsTheCompilerRegex() {
        let fixture = PopupsV3Fixtures.json("markup")
        let cases = (fixture["_fixture"] as? [String: Any])?["expect"] as? [[String: Any]] ?? []
        XCTAssertEqual(cases.count, 9)
        XCTAssertEqual((fixture["_fixture"] as? [String: Any])?["regex"] as? String, PopupV3Markup.pattern)
        for item in cases {
            let input = item["input"] as? String ?? ""
            XCTAssertEqual(PopupV3Markup.spans(input), PopupsV3Fixtures.spans(item["spans"]), input)
        }
        // The fixture popup carries the same strings as text elements.
        let messages = PopupsV3Fixtures.design("markup").elements.map { PopupV3TextSpec($0).message ?? "" }
        XCTAssertEqual(messages, cases.map { $0["input"] as? String ?? "" })
    }

    func testOverlineAndStylesReachTheAttributedText() {
        let text = PopupV3Fonts.attributed(PopupV3Markup.spans("**a** ^^b^^ __c__ ~~d~~"), size: 16, weight: 400, family: nil, color: .black, lineHeight: 1.35)
        XCTAssertEqual(text.string, "a b c d")
        let bold = text.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertTrue(bold?.fontDescriptor.symbolicTraits.contains(.traitBold) == true)
        XCTAssertNotNil(text.attribute(.popupV3Overline, at: 2, effectiveRange: nil))
        XCTAssertNotNil(text.attribute(.underlineStyle, at: 4, effectiveRange: nil))
        XCTAssertNotNil(text.attribute(.strikethroughStyle, at: 6, effectiveRange: nil))
    }

    // MARK: - variables.json

    func testStaticVariablesFromTheLegacyArrayWithoutRuntimeKeys() {
        let expect = PopupsV3Fixtures.expect("variables")
        let design = PopupsV3Fixtures.design("variables")
        var statics = expect["static_variables"] as? [String: String] ?? [:]
        statics["promo_code"] = nil
        XCTAssertEqual(design.variables, statics, "promo_code from variables is a showcase variable and is ignored")

        let text = PopupV3TextSpec(design.elements[0])
        XCTAssertEqual(text.message, expect["t_after_static"] as? String)
        let shown = PopupV3TextSpec(design.elements[0], runtime: ["promo_code": "ABC123"])
        XCTAssertEqual(shown.message, expect["t_at_show_with_code_ABC123"] as? String)

        XCTAssertEqual(PopupV3ButtonSpec(design.elements[1], texts: texts).href, expect["b_href"] as? String)
        XCTAssertEqual(PopupV3ButtonSpec(design.elements[1], texts: texts).text, "Открыть Аня")
        XCTAssertEqual(PopupV3ImageSpec(design.elements[2], texts: texts).url, expect["i_url"] as? String)
        XCTAssertEqual(PopupV3EmailSpec(design.elements[3], texts: texts).placeholder, expect["e_placeholder"] as? String)
    }

    func testVariablesObjectAndPlatformKeys() {
        let statics = PopupV3Variables.statics(["link": "https://x", "link_ios": "app://ios", "n": 5, "promo_code": "NO"])
        XCTAssertEqual(statics, ["link": "https://x", "link_ios": "app://ios", "n": "5"])
        XCTAssertEqual(PopupV3Variables.apply("{{ link }} {{n}} {{promo_code}} {{x}}", statics: statics), "app://ios 5 {{promo_code}} {{x}}")
    }

    // MARK: - element-text.json, element-box.json

    func testTextElementStyles() {
        let expect = PopupsV3Fixtures.expect("element-text")
        let full = PopupsV3Fixtures.element("element-text", "el-text-full")
        let fullExpect = expect["el-text-full"] as? [String: Any] ?? [:]
        let spec = PopupV3TextSpec(full)
        let box = full.box
        XCTAssertEqual(spec.spans, PopupsV3Fixtures.spans(fullExpect["spans"]))
        XCTAssertEqual(spec.align, .center)
        XCTAssertEqual(spec.fontSize, 20)
        XCTAssertEqual(spec.fontWeight, 700)
        XCTAssertEqual(box.lineHeight, 1.4)
        XCTAssertEqual(box.letterSpacing, 0.5)
        XCTAssertEqual(box.opacity, 0.9)
        XCTAssertEqual(box.paddingX, 8)
        XCTAssertEqual(box.paddingY, 0)
        XCTAssertEqual(box.textColor.hex, "#111827ff")
        XCTAssertEqual(box.background.hex, "#00000000")
        XCTAssertEqual(box.borderColor.hex, "#1118271a")
        XCTAssertEqual(box.shadowY, 2)
        XCTAssertEqual(box.shadowBlur, 8)
        XCTAssertEqual(box.shadowColor.hex, "#00000055")
        XCTAssertEqual(full.link(), "https://demo.rees46.ru/sale")
        XCTAssertEqual(full.cellAlign, .center)

        let bare = PopupsV3Fixtures.element("element-text", "el-text-bare")
        let bareSpec = PopupV3TextSpec(bare)
        XCTAssertEqual(bareSpec.fontSize, 16)
        XCTAssertEqual(bare.box.background.hex, "#00000000")
        XCTAssertEqual(bareSpec.align, .left)
        XCTAssertEqual(bare.box.textColor.hex, "#111827ff")
        XCTAssertEqual(bareSpec.fontWeight, 500)
        XCTAssertEqual(bare.box.lineHeight, 1.35)
        XCTAssertEqual(bare.box.borderWidth, 0)
        XCTAssertNil(bare.link())

        let positioned = PopupsV3Fixtures.design("element-text").elements.map(\.id)
        XCTAssertTrue(positioned.contains("el-text-css-position"), "CSS positioning keeps the element in the flow")
    }

    func testBoxElementDefaults() {
        let defaults = PopupsV3Fixtures.element("element-box", "el-box-defaults")
        XCTAssertEqual(defaults.box.background.hex, "#f8fafcff")
        XCTAssertEqual(defaults.box.borderRadius, 12)
        XCTAssertEqual(defaults.box.paddingX, 16)
        XCTAssertEqual(defaults.box.paddingY, 16)
        XCTAssertEqual(PopupV3TextSpec(defaults).fontSize, 12, "messageFontSize → fontSize → 12")

        let empty = PopupsV3Fixtures.element("element-box", "el-box-empty")
        XCTAssertEqual(empty.box.background.hex, "#eef2ffff")
        XCTAssertEqual(empty.box.borderRadius, 20)
        XCTAssertEqual(empty.box.paddingX, 24)
        XCTAssertEqual(empty.box.paddingY, 24)
        XCTAssertNil(PopupV3TextSpec(empty).message)
    }

    // MARK: - element-button.json, element-close.json

    func testButtonActionsLinksAndDefaults() {
        let name = "element-button"
        let link = PopupV3ButtonSpec(PopupsV3Fixtures.element(name, "el-btn-link"), texts: texts)
        XCTAssertEqual(link.action, .link)
        XCTAssertEqual(PopupV3Markup.spans(link.text), PopupsV3Fixtures.spans((PopupsV3Fixtures.expect(name)["el-btn-link"] as? [String: Any])?["spans"]))
        XCTAssertEqual(link.align, .left)
        XCTAssertEqual(link.style, PopupV3ButtonStyle(background: CSSColor.parse("#16a34a")!, textColor: .white, fontSize: 16, radius: 12, paddingX: 24, paddingY: 12))
        XCTAssertEqual(link.href, "rees46demo://sale?from=ios", "{{link}} takes link_ios on iOS")

        XCTAssertEqual(PopupV3ButtonSpec(PopupsV3Fixtures.element(name, "el-btn-ios-var"), texts: texts).href, "rees46demo://catalog?from=ios_var")
        XCTAssertEqual(PopupV3ButtonSpec(PopupsV3Fixtures.element(name, "el-btn-close"), texts: texts).action, .close)

        let copy = PopupV3ButtonSpec(PopupsV3Fixtures.element(name, "el-btn-copy"), texts: texts)
        XCTAssertEqual(copy.action, .copy)
        XCTAssertEqual(copy.copyText, "SALE10")
        XCTAssertEqual(PopupV3ButtonSpec(PopupsV3Fixtures.element(name, "el-btn-copy-fallback"), texts: texts).copyText, "SALE20")

        let legacy = PopupV3ButtonSpec(PopupsV3Fixtures.element(name, "el-btn-legacy-href"), texts: texts)
        XCTAssertEqual(legacy.action, .link)
        XCTAssertEqual(legacy.href, "https://demo.rees46.ru")

        let defaults = PopupV3ButtonSpec(PopupsV3Fixtures.element(name, "el-btn-defaults"), texts: texts)
        XCTAssertEqual(defaults.action, .link)
        XCTAssertEqual(defaults.text, "Подробнее")
        XCTAssertEqual(defaults.align, .center)
        XCTAssertEqual(defaults.style, PopupV3ButtonStyle(background: CSSColor.parse("#2563eb")!, textColor: .white, fontSize: 14, radius: 10, paddingX: 20, paddingY: 10))
        XCTAssertNil(defaults.href)

        let unknown = PopupV3ButtonSpec(PopupsV3Fixtures.element(name, "el-btn-unknown-action"), texts: texts)
        XCTAssertEqual(unknown.action, .link)
        XCTAssertEqual(unknown.href, "https://demo.rees46.ru")
        XCTAssertEqual(PopupV3ButtonSpec(PopupsV3Fixtures.element(name, "el-btn-defaults"), texts: .en).text, "Learn more")
    }

    func testCloseModesAndIconSize() {
        let name = "element-close"
        let defaults = PopupV3CloseSpec(PopupsV3Fixtures.element(name, "el-close-default"), texts: texts)
        XCTAssertEqual(defaults.mode, .text)
        XCTAssertEqual(defaults.text, "×")
        XCTAssertEqual(defaults.align, .right)
        XCTAssertEqual(defaults.style.background.hex, "#00000000")
        XCTAssertEqual(defaults.style.textColor.hex, "#71717aff")
        XCTAssertEqual(defaults.style.fontSize, 22)
        XCTAssertEqual(defaults.style.paddingX, 8)
        XCTAssertEqual(defaults.style.paddingY, 2)
        XCTAssertEqual(defaults.style.radius, 999)

        let text = PopupV3CloseSpec(PopupsV3Fixtures.element(name, "el-close-text"), texts: texts)
        XCTAssertEqual(text.text, "Закрыть ×")
        XCTAssertEqual(text.align, .left)
        XCTAssertEqual(text.style.fontSize, 16)

        let image = PopupV3CloseSpec(PopupsV3Fixtures.element(name, "el-close-image"), texts: texts)
        XCTAssertEqual(image.mode, .image)
        XCTAssertEqual(image.imageUrl, "https://pictures.rees46.ru/resize-images/180/c1140c8254976de297c3caf971701a/141206.jpg")
        XCTAssertEqual(image.size, 128, "200 → 128")

        let svg = PopupV3CloseSpec(PopupsV3Fixtures.element(name, "el-close-svg"), texts: texts)
        XCTAssertEqual(svg.mode, .svg)
        XCTAssertEqual(svg.size, 8, "4 → 8")
    }

    // MARK: - element-image.json

    func testImageHeightsFitRatioAndVisibility() {
        let name = "element-image"
        let auto = PopupV3ImageSpec(PopupsV3Fixtures.element(name, "el-img-auto"), texts: texts)
        XCTAssertEqual(auto.url, "https://pictures.rees46.ru/resize-images/180/c1140c8254976de297c3caf971701a/141206.jpg")
        XCTAssertEqual(auto.height, .auto)
        XCTAssertEqual(auto.fit, .cover)
        XCTAssertEqual(auto.radius, 12)
        XCTAssertEqual(auto.marginBottom, 8)
        XCTAssertEqual(auto.link, "https://demo.rees46.ru/product/141206")

        let px = PopupV3ImageSpec(PopupsV3Fixtures.element(name, "el-img-px"), texts: texts)
        XCTAssertEqual(px.height, .px(180))
        XCTAssertEqual(px.fit, .contain)
        XCTAssertEqual(PopupV3ImageSpec(PopupsV3Fixtures.element(name, "el-img-percent"), texts: texts).height, .percent(100))
        XCTAssertEqual(PopupV3ImageSpec(PopupsV3Fixtures.element(name, "el-img-vh"), texts: texts).height, .vh(40))

        let ratio = PopupV3ImageSpec(PopupsV3Fixtures.element(name, "el-img-ratio"), texts: texts)
        XCTAssertEqual(ratio.aspectRatio ?? 0, 1.7778, accuracy: 0.0001)
        let bad = PopupV3ImageSpec(PopupsV3Fixtures.element(name, "el-img-bad-ratio"), texts: texts)
        XCTAssertNil(bad.aspectRatio)
        XCTAssertEqual(bad.fit, .cover)
        XCTAssertTrue(PopupV3ImageSpec(PopupsV3Fixtures.element(name, "el-img-hidden"), texts: texts).hidden)
        XCTAssertEqual(auto.radius, 12)
        XCTAssertEqual(px.radius, 8, "DEFAULTS of image")
    }

    // MARK: - element-email-collector.json, element-form.json

    func testEmailCollectorLayoutConsentsAndTexts() {
        let name = "element-email-collector"
        let inline = PopupV3EmailSpec(PopupsV3Fixtures.element(name, "el-email-inline"), texts: texts)
        XCTAssertTrue(inline.inline)
        XCTAssertEqual(inline.consentFields, ["email_bulk", "email_chain"], "sms_bulk is not an email flag")
        XCTAssertEqual(PopupV3Markup.spans(inline.consentLabel), [PopupV3Span(text: "Согласен получать "), PopupV3Span(text: "рассылку", italic: true)])
        XCTAssertEqual(inline.segmentId, "123")
        XCTAssertEqual(inline.errorMessage, "Проверьте email")
        XCTAssertEqual(inline.successTitle, "Готово!")
        XCTAssertEqual(inline.successMessage, "Проверьте почту")
        XCTAssertEqual(inline.successBackground.hex, "#ecfdf5ff")
        XCTAssertEqual(inline.successAlign, .left)
        XCTAssertEqual(inline.placeholder, "Ваш email")

        let legacy = PopupV3EmailSpec(PopupsV3Fixtures.element(name, "el-email-stacked-legacy"), texts: texts)
        XCTAssertFalse(legacy.inline)
        XCTAssertEqual(legacy.consentFields, ["email_transactional"])
        XCTAssertEqual(legacy.consentLabel, "Согласен на письма о заказах")

        let bare = PopupV3EmailSpec(PopupsV3Fixtures.element(name, "el-email-bare"), texts: texts)
        XCTAssertFalse(bare.inline)
        XCTAssertEqual(bare.consentFields, ["email_bulk", "email_chain", "email_transactional"])
        XCTAssertEqual(bare.placeholder, "Email")
        XCTAssertEqual(bare.submitText, "Подписаться")
        XCTAssertEqual(bare.consentLabel, texts.emailConsent)
        XCTAssertEqual(bare.errorMessage, texts.emailError)
        XCTAssertNil(bare.segmentId)
        XCTAssertFalse(bare.hasSuccess)
        let box = PopupsV3Fixtures.element(name, "el-email-bare").box
        XCTAssertEqual(box.background.hex, "#ffffffff")
        XCTAssertEqual(box.borderRadius, 12)
        XCTAssertEqual(box.paddingX, 12)
    }

    func testFormFieldsAreNormalizedLikeTheCompiler() {
        let name = "element-form"
        let expect = (PopupsV3Fixtures.expect(name)["el-form"] as? [String: Any]) ?? [:]
        let form = PopupV3FormSpec(PopupsV3Fixtures.element(name, "el-form"), texts: texts)
        let expected = (expect["fields"] as? [[String: Any]] ?? []).map {
            ($0["id"] as? String ?? "", $0["kind"] as? String ?? "", $0["required"] as? Bool ?? false, $0["propertyKey"] as? String ?? "")
        }
        XCTAssertEqual(form.fields.count, 8)
        XCTAssertEqual(form.fields.map(\.id), expected.map(\.0))
        XCTAssertEqual(form.fields.map(\.kind.rawValue), expected.map(\.1))
        XCTAssertEqual(form.fields.map(\.required), expected.map(\.2))
        XCTAssertEqual(form.fields.map(\.propertyKey), expected.map(\.3))
        XCTAssertEqual(form.consentFields, ["email_bulk"])
        XCTAssertEqual(form.segmentId, "456")
        XCTAssertEqual(form.submitText, "Сохранить")
        XCTAssertEqual(form.fields[7].label, "Уровень")

        let bare = PopupV3FormSpec(PopupsV3Fixtures.element(name, "el-form-bare"), texts: texts)
        XCTAssertEqual(bare.fields, [])
        XCTAssertEqual(bare.consentFields, [], "no formConsentFields — no flags, unlike emailCollector")
        XCTAssertEqual(bare.submitText, "Отправить")
    }

    // MARK: - element-promo-code.json, element-survey.json, element-recommendation.json

    func testPromoCodePersonalAndStatic() {
        let name = "element-promo-code"
        let popup = PopupsV3Fixtures.popup(name)
        XCTAssertEqual(popup?.promoCodeListId, "7")
        XCTAssertTrue(popup?.needsPromoCode == true)

        let personal = PopupV3PromoSpec(PopupsV3Fixtures.element(name, "el-promo-personal"), texts: texts, runtime: ["promo_code": "ABC123"])
        XCTAssertFalse(personal.isStatic)
        XCTAssertEqual(personal.code, "ABC123")
        XCTAssertEqual(personal.align, .left)
        XCTAssertEqual(personal.codeFontSize, 22)
        XCTAssertEqual(personal.copiedText, "Скопировано!")
        XCTAssertEqual(personal.copyText, "Копировать")
        XCTAssertEqual(personal.applyHref, "rees46demo://cart?promo=ABC123")
        XCTAssertNil(PopupV3PromoSpec(PopupsV3Fixtures.element(name, "el-promo-personal"), texts: texts).applyHref, "no code — no link")

        let fixed = PopupV3PromoSpec(PopupsV3Fixtures.element(name, "el-promo-static"), texts: texts)
        XCTAssertTrue(fixed.isStatic)
        XCTAssertEqual(fixed.code, "WELCOME5")
        XCTAssertFalse(fixed.showCopy)

        let text = PopupV3TextSpec(PopupsV3Fixtures.element(name, "el-text-with-code"), runtime: ["promo_code": "ABC123"])
        let expected = (PopupsV3Fixtures.expect(name)["el-text-with-code"] as? [String: Any])?["spans_after_substitution_example"]
        XCTAssertEqual(text.spans, PopupsV3Fixtures.spans(expected))
    }

    func testSurveyScalesAndReviewBodies() {
        let name = "element-survey"
        let nps = PopupV3SurveySpec(PopupsV3Fixtures.element(name, "el-survey-nps"), texts: texts)
        XCTAssertEqual(nps.kind, .nps)
        XCTAssertEqual(nps.scale, 0...10)
        let body = nps.body(rate: 0, comment: "Долгая доставка")
        let requests = PopupsV3Fixtures.json("requests")
        var expected = (requests["review_nps"] as? [String: Any])?["json"] as? [String: Any] ?? [:]
        ["shop_id", "did", "sid"].forEach { expected[$0] = nil }
        XCTAssertEqual(body as NSDictionary, expected as NSDictionary)

        let csat = PopupV3SurveySpec(PopupsV3Fixtures.element(name, "el-survey-csat"), texts: texts)
        XCTAssertEqual(csat.scale, 1...5)
        var csatExpected = (requests["review_csat_no_comment"] as? [String: Any])?["json"] as? [String: Any] ?? [:]
        ["shop_id", "did", "sid"].forEach { csatExpected[$0] = nil }
        XCTAssertEqual(csat.body(rate: 5, comment: "  ") as NSDictionary, csatExpected as NSDictionary)
        XCTAssertEqual(csat.submitText, "Отправить")
        XCTAssertEqual(csat.thanksText, "Спасибо!")
        XCTAssertEqual(csat.scaleBackground.hex, "#f3f4f6ff")
        XCTAssertEqual(csat.activeBackground.hex, "#2563ebff")

        let ces = PopupV3SurveySpec(PopupsV3Fixtures.element(name, "el-survey-ces"), texts: texts)
        XCTAssertEqual(ces.scale, 1...7)
        XCTAssertEqual(ces.body(rate: 3, comment: nil)["campaign"] as? String, "MN TEST")

        let unknown = PopupV3SurveySpec(PopupsV3Fixtures.element(name, "el-survey-unknown"), texts: texts)
        XCTAssertEqual(unknown.kind, .nps)
        XCTAssertEqual(unknown.scale, 0...10)
    }

    func testRecommendationCodeAndBox() {
        let name = "element-recommendation"
        let element = PopupsV3Fixtures.element(name, "el-rec")
        XCTAssertEqual(PopupV3RecommendationSpec(element).code, "e6249bb15043644bf25b135006149962")
        XCTAssertEqual(element.box.background, .transparent)
        XCTAssertEqual(element.box.paddingX, 0)
        XCTAssertEqual(element.box.borderWidth, 0)
        XCTAssertNil(PopupV3RecommendationSpec(PopupsV3Fixtures.element(name, "el-rec-empty")).code)
    }

    // MARK: - grid.json, unknown-element.json, legacy-free-elements.json, empty-design.json

    func testGridFractionsAlignmentOrderAndDropped() {
        let design = PopupsV3Fixtures.design("grid")
        XCTAssertEqual(design.rows.map(\.id), ["row-a", "row-b", "row-c", "row-d"])

        let a = design.rows[0]
        XCTAssertEqual(a.fractions, [0.5, 0.5])
        XCTAssertEqual(a.gap, 12)
        XCTAssertEqual(a.minHeight, 80)
        XCTAssertEqual(a.cells.map(\.align), [.left, .center])
        XCTAssertEqual(a.cells.map(\.justify), [.top, .center])
        XCTAssertEqual(a.cells[0].elements.map(\.id), ["a0-1", "a0-2", "a0-3"])
        XCTAssertEqual(a.cells[1].elements.map(\.id), ["a1"], "partIndex \"1\" is a number")

        let b = design.rows[1]
        XCTAssertEqual(b.fractions.count, 3)
        b.fractions.forEach { XCTAssertEqual(Double($0), 0.3333, accuracy: 0.001) }
        XCTAssertEqual(b.gap, 8)
        XCTAssertEqual(b.minHeight, 60)
        XCTAssertEqual(b.cells.map(\.align), [.right, .right, .right])
        XCTAssertEqual(b.cells.map(\.justify), [.bottom, .bottom, .top])
        XCTAssertEqual(b.cells.map { $0.elements.map(\.id) }, [["b0"], [], ["b2"]])

        let c = design.rows[2]
        XCTAssertEqual(c.fractions, [0.25, 0.75])
        XCTAssertEqual(c.minHeight, 110)
        XCTAssertEqual(c.backgroundColor?.hex, "#fef3c7ff")
        XCTAssertEqual(c.backgroundImage, "https://pictures.rees46.ru/resize-images/180/c1140c8254976de297c3caf971701a/141206.jpg")
        XCTAssertEqual(c.backgroundSize, .contain)
        XCTAssertEqual(c.backgroundPosition, .top)
        XCTAssertEqual(c.backgroundRepeat, .repeatX)
        XCTAssertEqual(c.cells.map(\.align), [.left, .left], "an unknown cell align falls back to the row, then left")
        XCTAssertEqual(c.cells[1].elements.first?.cellAlign, .right)
        XCTAssertEqual(PopupV3CellView.align(c.cells[1].elements[0], cell: c.cells[1]), .right)

        let d = design.rows[3]
        assertClose(d.fractions.map { Double($0) }, [0.1, 0.1, 0.2, 0.2, 0.2, 0.2])
        XCTAssertEqual(d.cells[5].elements.map(\.id), ["d5"])

        let ids = design.elements.map(\.id)
        XCTAssertFalse(ids.contains("orphan"))
        XCTAssertFalse(ids.contains("out-of-range"))
    }

    func testUnknownElementsAreSkipped() {
        let design = PopupsV3Fixtures.design("unknown-element")
        XCTAssertEqual(design.elements.map(\.id), ["ok", "bad-style"])
        XCTAssertTrue(design.elements[1].style.isEmpty, "a style that is not an object is an empty style")
    }

    func testLegacyDesignFlowsByYThenX() {
        let design = PopupsV3Fixtures.design("legacy-free-elements")
        XCTAssertEqual(design.elements.map(\.id), PopupsV3Fixtures.expect("legacy-free-elements")["order"] as? [String])
        XCTAssertEqual(design.rows.count, 1)
    }

    func testEmptyDesignIsNotShownAndHasTheDefaultFrame() {
        let design = PopupsV3Fixtures.design("empty-design")
        XCTAssertTrue(design.isEmpty)
        let frame = design.frame
        XCTAssertEqual(frame.width, 92)
        XCTAssertEqual(frame.widthMode, .percent)
        XCTAssertEqual(frame.maxWidth, 480)
        XCTAssertEqual(frame.heightMode, .auto)
        XCTAssertEqual(frame.background.hex, "#ffffffff")
        XCTAssertEqual(frame.borderWidth, 1)
        XCTAssertEqual(frame.borderColor.hex, "#e5e7ebff")
        XCTAssertEqual(frame.borderRadius, 16)
        XCTAssertEqual(frame.padding, 20)
        XCTAssertEqual(PopupV3FrameStyle(json: [:]).frameWidth(screenWidth: 400), 368)
    }

    // MARK: - breakpoints.json, layouts.json

    func testBreakpointsNarrowestWins() {
        let frame = PopupsV3Fixtures.design("breakpoints").frame
        let narrow = frame.resolved(screenWidth: 390)
        XCTAssertEqual(narrow.frameWidth(screenWidth: 390), 390)
        XCTAssertNil(narrow.maxWidth)
        XCTAssertEqual(narrow.padding, 12)
        XCTAssertEqual(narrow.borderRadius, 0)
        XCTAssertEqual(narrow.minHeight, 120)

        let middle = frame.resolved(screenWidth: 414)
        XCTAssertEqual(middle.frameWidth(screenWidth: 414), 331.2, accuracy: 0.001)
        XCTAssertEqual(middle.maxWidth, 480)
        XCTAssertEqual(middle.padding, 20)
        XCTAssertEqual(middle.borderRadius, 16)

        let wide = frame.resolved(screenWidth: 800)
        XCTAssertEqual(wide.frameWidth(screenWidth: 800), 480)
        XCTAssertEqual(wide.padding, 20)
        XCTAssertEqual(wide.borderRadius, 16)

        let geometry = PopupV3Geometry(layout: .modal, placement: .center, style: frame, bounds: CGSize(width: 390, height: 844), safe: .zero)
        XCTAssertEqual(geometry.width, 390)
        XCTAssertEqual(geometry.padding, 12)
        XCTAssertEqual(geometry.radius, 0)
        XCTAssertEqual(geometry.minHeight, 120)
    }

    func testLayoutsBannerModalFullscreen() {
        let popups = PopupsV3Fixtures.json("layouts")["popups"] as? [[String: Any]] ?? []
        let parsed = popups.compactMap(PopupV3.init(json:))
        XCTAssertEqual(parsed.map(\.id), [9201, 9202, 9203, 9204])
        let screen = CGSize(width: 390, height: 844)
        let safe = UIEdgeInsets(top: 47, left: 0, bottom: 34, right: 0)
        func geometry(_ popup: PopupV3) -> PopupV3Geometry {
            PopupV3Geometry(layout: popup.layout, placement: popup.placement, style: PopupV3Design(json: popup.design).frame, bounds: screen, safe: safe)
        }

        let top = parsed[0]
        XCTAssertEqual(top.layout, .banner)
        XCTAssertEqual(top.placement, .top)
        let topFrame = PopupV3Design(json: top.design).frame
        XCTAssertNil(topFrame.overlayEnabled)
        XCTAssertFalse(topFrame.lockBackgroundScroll)
        XCTAssertEqual(geometry(top).width, 390 - 2 * 12, "screen − 2 × offsetX")
        XCTAssertEqual(geometry(top).anchorY, 47 + 16, "16 from the top safe area")

        let bottom = parsed[1]
        XCTAssertEqual(bottom.placement, .bottom)
        let bottomFrame = PopupV3Design(json: bottom.design).frame
        XCTAssertEqual(bottomFrame.overlayEnabled, true)
        XCTAssertEqual(bottomFrame.overlayColor.with(opacity: bottomFrame.overlayOpacity).hex, "#0000004d")
        XCTAssertTrue(bottomFrame.lockBackgroundScroll)
        XCTAssertEqual(geometry(bottom).width, 390)
        XCTAssertEqual(geometry(bottom).anchorY, 844 - 34, "0 from the bottom safe area")

        let modal = parsed[2]
        XCTAssertEqual(modal.layout, .modal)
        let modalGeometry = geometry(modal)
        XCTAssertEqual(modalGeometry.width, 390 * 0.92, accuracy: 0.001)
        XCTAssertEqual(modalGeometry.minHeight, 200)
        XCTAssertEqual(modalGeometry.radius, 16)
        XCTAssertEqual(modalGeometry.padding, 20)
        XCTAssertEqual(modalGeometry.borderWidth, 1)
        XCTAssertEqual(modalGeometry.maxHeight, 844 - 47 - 34 - 32)
        XCTAssertNil(PopupV3Design(json: modal.design).frame.overlayEnabled, "null — the layout's default: a modal is dimmed")

        let full = parsed[3]
        XCTAssertEqual(full.layout, .fullscreen)
        let fullGeometry = geometry(full)
        XCTAssertEqual(fullGeometry.width, 390)
        XCTAssertEqual(fullGeometry.fixedHeight, 844 - 47 - 34, "the whole screen inside the safe areas, its own height ignored")
        XCTAssertEqual(fullGeometry.radius, 0)
        XCTAssertEqual(fullGeometry.anchorY, 47)
    }

    func testKeyboardShrinksTheModalArea() {
        let style = PopupV3FrameStyle(json: [:])
        let geometry = PopupV3Geometry(layout: .modal, placement: .center, style: style, bounds: CGSize(width: 390, height: 844), safe: UIEdgeInsets(top: 47, left: 0, bottom: 34, right: 0), keyboard: 300)
        XCTAssertEqual(geometry.maxHeight, 844 - 47 - 300 - 32)
        XCTAssertEqual(geometry.anchorY, (47 + 16 + 844 - 300 - 16) / 2)
    }

    // MARK: - list-response.json, popup-response.json, live-list-181-182.json

    func testListResponseArmsSkipsAndDefaults() {
        let response = PopupsV3Fixtures.json("list-response")
        let expect = PopupsV3Fixtures.expect("list-response")
        let list = PopupsV3List(payload: response["payload"] as? [String: Any] ?? [:])
        XCTAssertEqual(list.ttl, 300, "\"300\"")
        let triggered = list.popups.filter { $0.trigger != .manual }.map(\.id)
        XCTAssertEqual(triggered, expect["armed"] as? [Int])
        XCTAssertEqual(list.popups.filter { $0.trigger == .manual }.map(\.id), expect["manual_only"] as? [Int])
        XCTAssertFalse(list.popups.map(\.id).contains(517), "scroll_percent is a web trigger")
        XCTAssertFalse(list.popups.map(\.id).contains(518), "bar is a web layout")
        let manual = list.popups.first { $0.id == 516 }
        XCTAssertEqual(manual?.frequency, .onceSession)
        XCTAssertEqual(manual?.targetScreens, [])
        XCTAssertEqual(list.popups.first { $0.id == 515 }?.cooldownMinutes, 0)
        XCTAssertEqual(list.popups.first { $0.id == 514 }?.triggerValue, 10, "\"10\"")
        XCTAssertEqual(list.excluded.map(\.id), ["520", "521"])
        XCTAssertEqual(list.excluded.map(\.reason), ["segments", "period"])
        XCTAssertFalse(list.popups.first { $0.id == 519 }?.needsPromoCode ?? true, "a list id without {{promo_code}} needs no code")
    }

    func testManualPopupResponse() {
        let popup = PopupsV3API.popupResult(status: 200, json: PopupsV3Fixtures.json("popup-response"))
        XCTAssertEqual(popup?.id, 516)
        XCTAssertEqual(popup?.trigger, .manual)
        XCTAssertEqual(popup?.layout, .fullscreen)
    }

    func testLivePopups181And182() {
        let list = PopupsV3List(payload: PopupsV3Fixtures.json("live-list-181-182")["payload"] as? [String: Any] ?? [:])
        XCTAssertEqual(list.popups.map(\.id), [181, 182])
        let banner = list.popups[0]
        XCTAssertEqual(banner.layout, .banner)
        XCTAssertEqual(banner.placement, .top)
        XCTAssertEqual(banner.trigger, .appStart)
        XCTAssertEqual(PopupV3Design(json: banner.design).elements.map(\.type), ["close", "text", "button", "image", "emailCollector", "survey"])
        let modal = list.popups[1]
        XCTAssertEqual(modal.layout, .modal)
        XCTAssertFalse(modal.needsPromoCode)
        let promo = PopupV3PromoSpec(PopupV3Design(json: modal.design).elements[0], texts: texts)
        XCTAssertEqual(promo.code, "Fix Test")
        XCTAssertTrue(promo.showCopy)
        let survey = PopupV3SurveySpec(PopupV3Design(json: modal.design).elements[1], texts: texts)
        XCTAssertEqual(survey.kind, .csat)
        XCTAssertEqual(survey.campaignCode, "")
        XCTAssertNil(survey.body(rate: 4, comment: nil)["campaign"], "no campaign in the live popup — none is sent")
    }

    // MARK: - /init

    func testInitFlagAndNoEmptyLegacyPopup() {
        let response = InitResponse(json: ["did": "DID123", "popups_v3": true])
        XCTAssertTrue(response.popupsV3)
        XCTAssertNil(response.popup, "no popup in /init — nothing to present, the shared slot stays free")
        XCTAssertFalse(InitResponse(json: ["did": "DID123"]).popupsV3)
        XCTAssertNil(InitResponse(json: ["popup": [String: Any]()]).popup)
        XCTAssertEqual(InitResponse(json: ["popup": ["id": 174, "position": "centered"]]).popup?.id, 174)
    }

    // MARK: - Links

    func testLinksDropScriptsAndUnresolvedTokens() {
        XCTAssertNil(PopupV3Links.usable("javascript:alert(1)"))
        XCTAssertNil(PopupV3Links.usable(" data:text/html,x"))
        XCTAssertNil(PopupV3Links.usable("  "))
        XCTAssertNil(PopupV3Links.usable("{{link}}"))
        XCTAssertEqual(PopupV3Links.usable("myapp://cart"), "myapp://cart")
        XCTAssertEqual(PopupV3Links.usable("tel:+7900"), "tel:+7900")
        XCTAssertNil(PopupV3Links.safeHTTP("ftp://x/y.png"))
    }

    func testValidation() {
        XCTAssertTrue(PopupV3Validation.isEmail("demo+ios@rees46.test"))
        XCTAssertFalse(PopupV3Validation.isEmail("demo@rees46"))
        XCTAssertFalse(PopupV3Validation.isEmail("de mo@rees46.test"))
        XCTAssertTrue(PopupV3Validation.isPhone("+7 (999) 000-00-00"))
        XCTAssertFalse(PopupV3Validation.isPhone("12345"))
        XCTAssertFalse(PopupV3Validation.isPhone("7+9990000000"))
    }
}

private func assertClose(_ lhs: [Double], _ rhs: [Double], accuracy: Double = 0.0001, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertEqual(lhs.count, rhs.count, file: file, line: line)
    for (left, right) in zip(lhs, rhs) {
        XCTAssertEqual(left, right, accuracy: accuracy, file: file, line: line)
    }
}
