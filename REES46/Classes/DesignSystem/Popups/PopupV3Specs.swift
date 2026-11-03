import UIKit

// Что рисует каждый элемент попапа v3 — значения после правила умолчаний и подстановки
// переменных. Ключи и запасные значения — как в компиляторе дизайна (`design_compiler/elements`).
// Вью элементов строятся по этим описаниям; тесты сверяют их с общими фикстурами.

/// Текст `text` и `box`: сообщение с разметкой поверх коробки.
struct PopupV3TextSpec {
    let message: String?
    let align: PopupV3HAlign
    let fontSize: Double
    let fontWeight: Double

    init(_ element: PopupV3Element, runtime: [String: String] = [:]) {
        let box = element.box
        message = element.text("message", runtime: runtime)
        align = PopupV3HAlign(element.value("messageAlign")) ?? .left
        fontSize = element.num("messageFontSize", box.fontSize)
        fontWeight = element.num("messageFontWeight", box.fontWeight)
    }

    var spans: [PopupV3Span] { message.map(PopupV3Markup.spans) ?? [] }
}

/// Стили кнопки (`button*`) — у кнопки, крестика, форм и опроса.
struct PopupV3ButtonStyle: Equatable {
    var background: CSSColor
    var textColor: CSSColor
    var fontSize: Double
    var radius: Double
    var paddingX: Double
    var paddingY: Double
}

/// Кнопка: ссылка, закрытие или копирование.
struct PopupV3ButtonSpec {
    enum Action: String { case link, close, copy }

    let action: Action
    /// Подпись с разметкой; пустая — текст по умолчанию «Подробнее».
    let text: String
    let align: PopupV3HAlign
    let style: PopupV3ButtonStyle
    let fontFamily: String?
    /// Ссылка `link` (`linkHref`, у старых документов `buttonHref`); `nil` — открывать нечего.
    let href: String?
    /// Что копирует `copy`: `copyText`, иначе подпись кнопки как есть.
    let copyText: String?

    init(_ element: PopupV3Element, texts: PopupV3Texts, runtime: [String: String] = [:]) {
        action = (element.string("buttonAction")).flatMap(Action.init(rawValue:)) ?? .link
        let label = element.text("buttonText", runtime: runtime)
        text = label ?? texts.detail
        align = PopupV3HAlign(element.value("buttonAlign")) ?? .left
        style = PopupV3ButtonStyle(
            background: element.color("buttonBgColor", CSSColor(red: 0x25, green: 0x63, blue: 0xeb, alpha: 255)),
            textColor: element.color("buttonTextColor", .white),
            fontSize: element.num("buttonFontSize", 12),
            radius: element.num("buttonRadius", 0),
            paddingX: element.num("buttonPaddingX", 0),
            paddingY: element.num("buttonPaddingY", 0)
        )
        fontFamily = element.string("fontFamily")
        switch action {
        case .link:
            href = PopupV3Links.usable(element.text("linkHref", runtime: runtime) ?? element.text("buttonHref", runtime: runtime))
            copyText = nil
        case .copy:
            href = nil
            copyText = element.text("copyText", runtime: runtime) ?? label
        case .close:
            href = nil
            copyText = nil
        }
    }
}

/// Крестик: текст (по умолчанию «×»), картинка или SVG.
struct PopupV3CloseSpec {
    enum Mode: String { case text, image, svg }

    let mode: Mode
    let text: String
    let imageUrl: String?
    let imageAlt: String
    /// Сторона иконки: `closeIconSize`, иначе `buttonFontSize`, 8–128.
    let size: Double
    let align: PopupV3HAlign
    let style: PopupV3ButtonStyle
    let fontFamily: String?

    init(_ element: PopupV3Element, texts: PopupV3Texts, runtime: [String: String] = [:]) {
        mode = element.string("closeIconMode").flatMap(Mode.init(rawValue:)) ?? .text
        text = element.text("buttonText", runtime: runtime) ?? "×"
        imageUrl = PopupV3Links.safeHTTP(element.text("imageUrl", runtime: runtime))
        imageAlt = element.text("imageAlt", runtime: runtime) ?? texts.close
        size = max(8, min(128, element.num("closeIconSize", element.num("buttonFontSize", 22))))
        align = PopupV3HAlign(element.value("buttonAlign")) ?? .right
        style = PopupV3ButtonStyle(
            background: element.color("buttonBgColor", .transparent),
            textColor: element.color("buttonTextColor", CSSColor(red: 0x71, green: 0x71, blue: 0x7a, alpha: 255)),
            fontSize: element.num("buttonFontSize", 22),
            radius: element.num("buttonRadius", 999),
            paddingX: element.num("buttonPaddingX", 8),
            paddingY: element.num("buttonPaddingY", 2)
        )
        fontFamily = element.string("fontFamily")
    }
}

/// Картинка на ширину ячейки.
struct PopupV3ImageSpec {
    enum Height: Equatable {
        case auto
        case px(Double)
        /// Процент высоты экрана (у веба — от высоты блока; на mobile — экран).
        case percent(Double)
        case vh(Double)
    }

    enum Fit: String { case cover, contain, fill, none }

    let hidden: Bool
    let url: String?
    let alt: String
    let height: Height
    let fit: Fit
    /// Ширина к высоте из `imageAspectRatio` вида `16 / 9`; битая запись — `nil`.
    let aspectRatio: Double?
    let radius: Double
    let marginBottom: Double
    let link: String?

    init(_ element: PopupV3Element, texts: PopupV3Texts, runtime: [String: String] = [:]) {
        hidden = PopupV3Value.bool(element.style["showImage"]) == false
        url = PopupV3Links.safeHTTP(element.text("imageUrl", runtime: runtime))
        alt = element.text("imageAlt", runtime: runtime) ?? texts.image
        switch element.string("imageHeightMode") ?? "auto" {
        case "auto": height = .auto
        case "%": height = .percent(max(1, min(100, element.num("imageHeight", 100))))
        case "vh": height = .vh(max(1, min(100, element.num("imageHeight", 40))))
        default: height = .px(element.num("imageHeight", 120))
        }
        fit = element.string("imageObjectFit").flatMap(Fit.init(rawValue:)) ?? .cover
        aspectRatio = Self.ratio(element.string("imageAspectRatio"))
        radius = element.num("imageRadius", 0)
        marginBottom = element.num("imageMarginBottom", 0)
        link = element.link(runtime: runtime)
    }

    /// `\d+(\.\d+)? / \d+(\.\d+)?` → ширина / высота.
    static func ratio(_ raw: String?) -> Double? {
        guard let text = raw?.trimmingCharacters(in: .whitespaces) else { return nil }
        let parts = text.split(separator: "/", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2, parts.allSatisfy(isDecimal), let width = Double(parts[0]), let height = Double(parts[1]), width > 0, height > 0 else { return nil }
        return width / height
    }

    private static func isDecimal(_ text: String) -> Bool {
        let pieces = text.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...2).contains(pieces.count) else { return false }
        return pieces.allSatisfy { !$0.isEmpty && $0.allSatisfy { ("0"..."9").contains($0) } }
    }
}

/// Поля ввода форм.
struct PopupV3InputStyle: Equatable {
    var background: CSSColor
    var textColor: CSSColor
    var borderColor: CSSColor
    var radius: Double
}

/// Флаги согласия на рассылки email.
enum PopupV3Consent {
    static let fields = ["email_bulk", "email_chain", "email_transactional"]

    static func known(_ value: Any?) -> [String] {
        let listed = (value as? [Any] ?? []).compactMap { $0 as? String }
        return fields.filter(listed.contains)
    }
}

/// Форма подписки на email.
struct PopupV3EmailSpec {
    let inline: Bool
    let placeholder: String
    let submitText: String
    let consentLabel: String
    /// Флаги профиля при согласии: `emailConsentFields` → `emailConsents[].field` → подписи
    /// `email*Label` → все три.
    let consentFields: [String]
    let segmentId: String?
    let errorMessage: String
    let successTitle: String?
    let successMessage: String?
    let successBackground: CSSColor
    let successColor: CSSColor
    let successAlign: PopupV3HAlign
    let successRadius: Double
    let successPaddingX: Double
    let successPaddingY: Double
    let successTitleColor: CSSColor
    let successTitleFontSize: Double
    let successFontSize: Double
    let input: PopupV3InputStyle
    let inputFontSize: Double
    let button: PopupV3ButtonStyle

    init(_ element: PopupV3Element, texts: PopupV3Texts, runtime: [String: String] = [:]) {
        inline = element.string("emailLayout") == "inline"
        placeholder = element.text("emailPlaceholder", runtime: runtime) ?? texts.email
        submitText = element.text("emailSubmitText", runtime: runtime) ?? texts.subscribe
        consentLabel = Self.consentLabel(element, runtime: runtime) ?? texts.emailConsent
        consentFields = Self.consentFields(element)
        segmentId = element.string("emailSegmentId").map { $0.trimmingCharacters(in: .whitespaces) }.flatMap { $0.isEmpty ? nil : $0 }
        errorMessage = element.text("emailErrorMessage", runtime: runtime) ?? texts.emailError
        successTitle = element.text("emailSuccessTitle", runtime: runtime)
        successMessage = element.text("emailSuccessMessage", runtime: runtime)
        successBackground = element.color("emailSuccessBg", CSSColor(red: 0xec, green: 0xfd, blue: 0xf5, alpha: 255))
        successColor = element.color("emailSuccessColor", CSSColor(red: 0x06, green: 0x5f, blue: 0x46, alpha: 255))
        let align = PopupV3HAlign(element.value("emailSuccessAlign"))
        successAlign = align == .left || align == .right ? align! : .center
        successRadius = element.num("emailSuccessRadius", 12)
        successPaddingX = element.num("emailSuccessPaddingX", 14)
        successPaddingY = element.num("emailSuccessPaddingY", 16)
        successTitleColor = element.color("emailSuccessTitleColor", CSSColor(red: 0x04, green: 0x78, blue: 0x57, alpha: 255))
        successTitleFontSize = element.num("emailSuccessTitleFontSize", 16)
        successFontSize = element.num("emailSuccessFontSize", 13)
        input = PopupV3InputStyle(
            background: element.color("emailInputBg", CSSColor(red: 0xf8, green: 0xfa, blue: 0xfc, alpha: 255)),
            textColor: element.color("emailInputColor", CSSColor(red: 0x0f, green: 0x17, blue: 0x2a, alpha: 255)),
            borderColor: element.color("emailInputBorderColor", CSSColor(red: 0xcb, green: 0xd5, blue: 0xe1, alpha: 255)),
            radius: element.num("emailInputRadius", 10)
        )
        inputFontSize = max(element.num("fontSize", 13), 12)
        button = PopupV3ButtonStyle(
            background: element.color("buttonBgColor", CSSColor(red: 0x25, green: 0x63, blue: 0xeb, alpha: 255)),
            textColor: element.color("buttonTextColor", .white),
            fontSize: element.num("buttonFontSize", 14),
            radius: element.num("buttonRadius", 10),
            paddingX: element.num("buttonPaddingX", 18),
            paddingY: element.num("buttonPaddingY", 10)
        )
    }

    var hasSuccess: Bool { successTitle != nil || successMessage != nil }

    static func consentFields(_ element: PopupV3Element) -> [String] {
        let own = PopupV3Consent.known(element.value("emailConsentFields"))
        if !own.isEmpty { return own }
        let legacy = (element.style["emailConsents"] as? [Any] ?? []).compactMap { ($0 as? [String: Any])?["field"] as? String }
        let fromLegacy = PopupV3Consent.fields.filter(legacy.contains)
        if !fromLegacy.isEmpty { return fromLegacy }
        var labelled: [String] = []
        if element.string("emailConsentBulkLabel") != nil { labelled.append("email_bulk") }
        if element.string("emailConsentChainLabel") != nil { labelled.append("email_chain") }
        if element.string("emailConsentTransactionalLabel") != nil { labelled.append("email_transactional") }
        return labelled.isEmpty ? PopupV3Consent.fields : labelled
    }

    static func consentLabel(_ element: PopupV3Element, runtime: [String: String]) -> String? {
        if let own = element.text("emailConsentLabel", runtime: runtime), !own.trimmingCharacters(in: .whitespaces).isEmpty {
            return own.trimmingCharacters(in: .whitespaces)
        }
        if let first = (element.style["emailConsents"] as? [Any])?.first as? [String: Any],
           let label = PopupV3Value.string(first["label"]) {
            return element.substitute(label, runtime: runtime)
        }
        return element.text("emailConsentBulkLabel", runtime: runtime)
    }
}

/// Форма профиля.
struct PopupV3FormSpec {

    enum Kind: String, CaseIterable {
        case email, phone, firstName = "first_name", lastName = "last_name", birthday, gender, custom
    }

    struct Field: Equatable {
        let id: String
        let kind: Kind
        let label: String
        let placeholder: String
        let required: Bool
        /// Свойство профиля у `custom`: `[a-z0-9_]`; у прочих пусто.
        let propertyKey: String

        /// Ключ в профиле: стандартное поле или свойство `custom`.
        var profileKey: String { kind == .custom ? propertyKey : kind.rawValue }
    }

    static let maxFields = 8

    let fields: [Field]
    let consentLabel: String?
    let consentFields: [String]
    let segmentId: String?
    let submitText: String
    let errorMessage: String
    let successTitle: String?
    let successMessage: String?
    let input: PopupV3InputStyle
    let inputFontSize: Double
    let button: PopupV3ButtonStyle

    init(_ element: PopupV3Element, texts: PopupV3Texts, runtime: [String: String] = [:]) {
        fields = Self.fields(element.style["formFields"], element: element, runtime: runtime)
        consentLabel = element.text("formConsentLabel", runtime: runtime)
        consentFields = PopupV3Consent.known(element.value("formConsentFields"))
        segmentId = element.string("formSegmentId").map { $0.trimmingCharacters(in: .whitespaces) }.flatMap { $0.isEmpty ? nil : $0 }
        submitText = element.text("formSubmitText", runtime: runtime) ?? texts.send
        errorMessage = element.text("formErrorMessage", runtime: runtime) ?? texts.formError
        successTitle = element.text("formSuccessTitle", runtime: runtime)
        successMessage = element.text("formSuccessMessage", runtime: runtime)
        input = PopupV3InputStyle(
            background: element.color("formInputBg", CSSColor(red: 0xf8, green: 0xfa, blue: 0xfc, alpha: 255)),
            textColor: element.color("formInputColor", CSSColor(red: 0x0f, green: 0x17, blue: 0x2a, alpha: 255)),
            borderColor: element.color("formInputBorderColor", CSSColor(red: 0xcb, green: 0xd5, blue: 0xe1, alpha: 255)),
            radius: element.num("formInputRadius", 10)
        )
        inputFontSize = max(element.num("fontSize", 13), 12)
        button = PopupV3ButtonStyle(
            background: element.color("buttonBgColor", CSSColor(red: 0x25, green: 0x63, blue: 0xeb, alpha: 255)),
            textColor: element.color("buttonTextColor", .white),
            fontSize: element.num("buttonFontSize", 14),
            radius: element.num("buttonRadius", 10),
            paddingX: element.num("buttonPaddingX", 18),
            paddingY: element.num("buttonPaddingY", 10)
        )
    }

    var hasSuccess: Bool { successTitle != nil || successMessage != nil }

    /// `Form#normalized_fields`: только объекты известного вида, не больше 8; id — `[A-Za-z0-9_-]`
    /// (пустой — `field-<номер после фильтра>`), обязательное — только булево `true`,
    /// `propertyKey` — в нижнем регистре, `[a-z0-9_]`.
    static func fields(_ raw: Any?, element: PopupV3Element, runtime: [String: String]) -> [Field] {
        let objects = (raw as? [Any] ?? []).compactMap { $0 as? [String: Any] }
        let known = objects.compactMap { object -> (Kind, [String: Any])? in
            guard let kind = (object["kind"] as? String).flatMap(Kind.init(rawValue:)) else { return nil }
            return (kind, object)
        }
        return known.prefix(maxFields).enumerated().map { index, item in
            let (kind, object) = item
            let rawId = (PopupV3Value.string(object["id"]) ?? "").filter { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == "-") }
            let rawKey = (PopupV3Value.string(object["propertyKey"]) ?? "").lowercased()
                .filter { $0.isASCII && ($0.isLowercase || $0.isNumber || $0 == "_") }
            let required = (object["required"] as? NSNumber).map { PopupV3Value.isBool($0) && $0.boolValue } ?? false
            return Field(
                id: rawId.isEmpty ? "field-\(index)" : rawId,
                kind: kind,
                label: element.substitute(PopupV3Value.string(object["label"]) ?? "", runtime: runtime),
                placeholder: element.substitute(PopupV3Value.string(object["placeholder"]) ?? "", runtime: runtime),
                required: required,
                propertyKey: kind == .custom ? rawKey : ""
            )
        }
    }
}

/// Промокод: персональный (из списка попапа) или фиксированный.
struct PopupV3PromoSpec {
    let isStatic: Bool
    /// Код для показа и копирования: фиксированный — `promoStaticCode`, персональный —
    /// витринная переменная `promo_code` (нет её — токен как есть).
    let code: String
    let label: String?
    let showCopy: Bool
    let copyText: String
    let copiedText: String
    let applyHref: String?
    let codeBackground: CSSColor
    let codeColor: CSSColor
    let codeFontSize: Double
    let codeRadius: Double
    let align: PopupV3HAlign

    init(_ element: PopupV3Element, texts: PopupV3Texts, runtime: [String: String] = [:]) {
        isStatic = element.string("promoSource") == "static"
        code = isStatic
            ? (element.string("promoStaticCode") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            : PopupV3Variables.apply("{{promo_code}}", statics: [:], runtime: runtime)
        label = element.text("promoLabel", runtime: runtime)
        showCopy = element.bool("promoShowCopy") != false
        copyText = element.text("promoCopyText", runtime: runtime) ?? texts.copy
        copiedText = element.text("promoCopiedText", runtime: runtime) ?? texts.copied
        applyHref = PopupV3Links.usable(element.text("promoApplyHref", runtime: runtime))
        codeBackground = element.color("promoCodeBg", CSSColor(red: 0xfe, green: 0xf3, blue: 0xc7, alpha: 255))
        codeColor = element.color("promoCodeColor", CSSColor(red: 0x92, green: 0x40, blue: 0x0e, alpha: 255))
        codeFontSize = element.num("promoCodeFontSize", 20)
        codeRadius = element.num("promoCodeRadius", 10)
        align = PopupV3HAlign(element.value("messageAlign")) ?? .center
    }
}

/// Мини-опрос NPS / CSAT / CES.
struct PopupV3SurveySpec {
    let kind: PersonalizationStoryPoll.Scale
    let campaignCode: String
    let question: String?
    let minLabel: String?
    let maxLabel: String?
    let commentPlaceholder: String?
    let submitText: String
    let thanksText: String
    let scaleBackground: CSSColor
    let scaleColor: CSSColor
    let activeBackground: CSSColor
    let activeColor: CSSColor
    let button: PopupV3ButtonStyle

    init(_ element: PopupV3Element, texts: PopupV3Texts, runtime: [String: String] = [:]) {
        kind = element.string("surveyType").flatMap(PersonalizationStoryPoll.Scale.init(rawValue:)) ?? .nps
        campaignCode = element.string("surveyCampaignCode") ?? ""
        question = element.text("surveyQuestion", runtime: runtime)
        minLabel = element.text("surveyMinLabel", runtime: runtime)
        maxLabel = element.text("surveyMaxLabel", runtime: runtime)
        commentPlaceholder = element.text("surveyCommentPlaceholder", runtime: runtime)
        submitText = element.text("surveySubmitText", runtime: runtime) ?? texts.send
        thanksText = element.text("surveyThanksText", runtime: runtime) ?? texts.thanks
        scaleBackground = element.color("surveyScaleBg", CSSColor(red: 0xf3, green: 0xf4, blue: 0xf6, alpha: 255))
        scaleColor = element.color("surveyScaleColor", CSSColor(red: 0x11, green: 0x18, blue: 0x27, alpha: 255))
        activeBackground = element.color("surveyScaleActiveBg", CSSColor(red: 0x25, green: 0x63, blue: 0xeb, alpha: 255))
        activeColor = element.color("surveyScaleActiveColor", .white)
        button = PopupV3ButtonStyle(
            background: element.color("buttonBgColor", CSSColor(red: 0x25, green: 0x63, blue: 0xeb, alpha: 255)),
            textColor: element.color("buttonTextColor", .white),
            fontSize: element.num("buttonFontSize", 14),
            radius: element.num("buttonRadius", 10),
            paddingX: element.num("buttonPaddingX", 18),
            paddingY: element.num("buttonPaddingY", 10)
        )
    }

    /// Оценки шкалы: NPS 0–10, CSAT 1–5, CES 1–7.
    var scale: ClosedRange<Int> { kind.defaultRange }

    /// Тело отзыва API v3 опросов (без `shop_id`, `did`, `sid` — их добавляет транспорт): у NPS код
    /// кампании — `category`, у CSAT и CES — `campaign`; пустой код не шлётся.
    func body(rate: Int, comment: String?) -> [String: Any] {
        var body: [String: Any] = ["channel": "popup", "rate": rate]
        if !campaignCode.isEmpty { body[kind == .nps ? "category" : "campaign"] = campaignCode }
        if let comment = comment?.trimmingCharacters(in: .whitespacesAndNewlines), !comment.isEmpty { body["comment"] = comment }
        return body
    }
}

/// Блок рекомендаций по коду блока.
struct PopupV3RecommendationSpec {
    /// Пустой код — блок не рисуется.
    let code: String?

    init(_ element: PopupV3Element) {
        let code = (element.string("recommenderCode") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        self.code = code.isEmpty ? nil : code
    }
}
