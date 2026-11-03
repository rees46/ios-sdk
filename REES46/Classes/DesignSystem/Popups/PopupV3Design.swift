import UIKit

// Документ design попапа v3 — нормализованная модель для рендера. Строится один раз до показа,
// без UI: сетка строк и ячеек, стили рамки и элементов, статические переменные.
//
// Правило умолчаний: значение из документа → `DEFAULTS` типа (стиль нового элемента в
// редакторе) → запасное значение компилятора. `null` и пустая строка — отсутствие значения.

enum PopupV3HAlign: String, Equatable {
    case left, center, right

    init?(_ value: Any?) {
        guard let text = value as? String, let align = PopupV3HAlign(rawValue: text) else { return nil }
        self = align
    }
}

enum PopupV3VAlign: String, Equatable {
    case top, center, bottom

    init?(_ value: Any?) {
        guard let text = value as? String, let align = PopupV3VAlign(rawValue: text) else { return nil }
        self = align
    }
}

/// Лог попапов v3: в отладочной сборке — консоль, в любой — при `debug` движка.
enum PopupsV3Log {
    static var verbose = false

    static func log(_ message: @autoclosure () -> String) {
        if verbose {
            NSLog("Popups v3: %@", message())
        } else {
            #if DEBUG
            print("Popups v3: \(message())")
            #endif
        }
    }
}

// MARK: - Документ

struct PopupV3Design {

    static let maxRows = 50
    static let maxColumns = 6
    static let maxElements = 200
    /// Промежуток между строками.
    static let rowsGap: CGFloat = 8

    let frame: PopupV3FrameStyle
    let rows: [PopupV3Row]
    let variables: [String: String]

    /// Ни одного элемента для рисования — попап не показывается.
    var isEmpty: Bool {
        rows.allSatisfy { row in row.cells.allSatisfy(\.elements.isEmpty) }
    }

    var elements: [PopupV3Element] {
        rows.flatMap { $0.cells.flatMap(\.elements) }
    }

    /// `known` — типы, которые умеет рисовать рендер; прочие пропускаются с записью в лог.
    init(json: [String: Any], known: Set<String> = PopupV3Elements.types) {
        let variables = PopupV3Variables.statics(json["variables"])
        self.variables = variables
        self.frame = PopupV3FrameStyle(json: json["frameStyle"] as? [String: Any] ?? [:])

        var rawRows = (json["rows"] as? [Any] ?? []).compactMap { $0 as? [String: Any] }
        var rawElements = (json["elements"] as? [Any] ?? []).compactMap { $0 as? [String: Any] }
        if rawRows.count > Self.maxRows {
            PopupsV3Log.log("design has \(rawRows.count) rows, only \(Self.maxRows) are drawn")
            rawRows = Array(rawRows.prefix(Self.maxRows))
        }
        if rawElements.count > Self.maxElements {
            PopupsV3Log.log("design has \(rawElements.count) elements, only \(Self.maxElements) are drawn")
            rawElements = Array(rawElements.prefix(Self.maxElements))
        }

        func element(_ raw: [String: Any]) -> PopupV3Element? {
            let type = raw["type"] as? String ?? ""
            let id = PopupV3Value.string(raw["id"]) ?? ""
            guard known.contains(type) else {
                PopupsV3Log.log("element \(id.isEmpty ? "without id" : id) of type \(type.isEmpty ? "nil" : type) skipped")
                return nil
            }
            return PopupV3Element(id: id, type: type, style: raw["style"] as? [String: Any] ?? [:], statics: variables)
        }

        guard !rawRows.isEmpty else {
            // Старый дизайн без строк: элементы стояли по абсолютным x/y — здесь они идут потоком
            // сверху вниз по y, при равном y — слева направо.
            let ordered = rawElements.enumerated().sorted { lhs, rhs in
                let ly = PopupV3Value.num(lhs.element["y"], 0), ry = PopupV3Value.num(rhs.element["y"], 0)
                if ly != ry { return ly < ry }
                let lx = PopupV3Value.num(lhs.element["x"], 0), rx = PopupV3Value.num(rhs.element["x"], 0)
                if lx != rx { return lx < rx }
                return lhs.offset < rhs.offset
            }.map(\.element)
            let elements = ordered.compactMap(element)
            rows = elements.isEmpty ? [] : [PopupV3Row.free(elements)]
            return
        }

        var byCell: [String: [[String: Any]]] = [:]
        for raw in rawElements {
            let key = "\(PopupV3Value.string(raw["rowId"]) ?? ""):\(Int(PopupV3Value.num(raw["partIndex"], 0)))"
            byCell[key, default: []].append(raw)
        }
        var placed = Set<String>()
        rows = rawRows.map { raw in
            let row = PopupV3Row(json: raw) { index in
                let key = "\(PopupV3Value.string(raw["id"]) ?? ""):\(index)"
                placed.insert(key)
                return (byCell[key] ?? []).compactMap(element)
            }
            return row
        }
        for (key, items) in byCell where !placed.contains(key) {
            for item in items {
                PopupsV3Log.log("element \(PopupV3Value.string(item["id"]) ?? "without id") has no cell \(key), skipped")
            }
        }
    }
}

// MARK: - Рамка

struct PopupV3FrameStyle {

    enum WidthMode: String { case px, percent = "%", vw }
    enum HeightMode: String { case auto, px, percent = "%", vh }

    /// Переопределения рамки для экранов не шире `mediaMaxWidth`; `null` в ключе — тоже значение.
    struct Breakpoint {
        let mediaMaxWidth: Double
        let values: [String: Any]
    }

    static let breakpointKeys = ["width", "widthMode", "height", "heightMode", "maxWidth", "maxWidthMode", "minHeight", "padding", "borderRadius"]

    var width: Double
    var widthMode: WidthMode
    var height: Double?
    var heightMode: HeightMode
    var minHeight: Double?
    var minHeightMode: HeightMode
    /// `nil` — без предела (`maxWidthMode: none`).
    var maxWidth: Double?
    var maxWidthMode: WidthMode
    var background: CSSColor
    var borderWidth: Double
    var borderColor: CSSColor
    var borderRadius: Double
    var padding: Double
    /// `nil` — по макету: у модалки и фуллскрина затемнение есть, у баннера нет.
    var overlayEnabled: Bool?
    var overlayColor: CSSColor
    var overlayOpacity: Double
    var lockBackgroundScroll: Bool
    var offsetX: Double
    var offsetY: Double
    var breakpoints: [Breakpoint]

    /// Пустой дизайн нового попапа (`EMPTY_DESIGN`): 92 %, до 480, белый, рамка 1 #e5e7eb, радиус 16, отступы 20.
    init(json: [String: Any]) {
        width = PopupV3Value.num(json["width"], 92)
        widthMode = Self.widthMode(json["widthMode"]) ?? .percent
        height = PopupV3Value.number(json["height"])
        heightMode = (json["heightMode"] as? String).flatMap(HeightMode.init(rawValue:)) ?? .auto
        minHeight = PopupV3Value.number(json["minHeight"])
        minHeightMode = (json["minHeightMode"] as? String).flatMap(HeightMode.init(rawValue:)) ?? .px
        maxWidthMode = .px
        maxWidth = 480
        background = CSSColor.parse(json["bgColor"]) ?? .white
        borderWidth = PopupV3Value.num(json["borderWidth"], 1)
        borderColor = CSSColor.parse(json["borderColor"]) ?? CSSColor(red: 0xe5, green: 0xe7, blue: 0xeb, alpha: 255)
        borderRadius = PopupV3Value.num(json["borderRadius"], 16)
        padding = PopupV3Value.num(json["padding"], 20)
        overlayEnabled = PopupV3Value.bool(json["overlayEnabled"])
        overlayColor = CSSColor.parse(json["overlayColor"]) ?? .black
        overlayOpacity = max(0, min(1, PopupV3Value.num(json["overlayOpacity"], 0.5)))
        lockBackgroundScroll = PopupV3Value.bool(json["lockBackgroundScroll"]) ?? false
        offsetX = PopupV3Value.num(json["offsetX"], 0)
        offsetY = PopupV3Value.num(json["offsetY"], 0)
        breakpoints = (json["breakpoints"] as? [Any] ?? []).compactMap { item in
            guard let object = item as? [String: Any], let media = PopupV3Value.number(object["mediaMaxWidth"]) else { return nil }
            var values: [String: Any] = [:]
            for key in Self.breakpointKeys where object.keys.contains(key) {
                values[key] = object[key] ?? NSNull()
            }
            return Breakpoint(mediaMaxWidth: media, values: values)
        }
        applyMaxWidth(mode: json["maxWidthMode"], value: json["maxWidth"], present: json.keys.contains("maxWidth"))
    }

    private mutating func applyMaxWidth(mode: Any?, value: Any?, present: Bool) {
        if (mode as? String) == "none" {
            maxWidth = nil
            return
        }
        maxWidthMode = Self.widthMode(mode) ?? .px
        if present {
            maxWidth = PopupV3Value.number(value)
        }
    }

    private static func widthMode(_ value: Any?) -> WidthMode? {
        (value as? String).flatMap(WidthMode.init(rawValue:))
    }

    /// Рамка для экрана шириной `screenWidth`: подходящие breakpoints (`screenWidth ≤ mediaMaxWidth`)
    /// применяются от широкого к узкому — узкий побеждает, как каскад CSS.
    func resolved(screenWidth: Double) -> PopupV3FrameStyle {
        var style = self
        let matching = breakpoints
            .filter { screenWidth <= $0.mediaMaxWidth }
            .sorted { $0.mediaMaxWidth > $1.mediaMaxWidth }
        for point in matching {
            let values = point.values
            func has(_ key: String) -> Bool { values.keys.contains(key) }
            if has("width") { style.width = PopupV3Value.num(values["width"], style.width) }
            if let mode = Self.widthMode(values["widthMode"]) { style.widthMode = mode }
            if has("height") { style.height = PopupV3Value.number(values["height"]) }
            if let mode = (values["heightMode"] as? String).flatMap(HeightMode.init(rawValue:)) { style.heightMode = mode }
            if (values["maxWidthMode"] as? String) == "none" {
                style.maxWidth = nil
            } else {
                if let mode = Self.widthMode(values["maxWidthMode"]) { style.maxWidthMode = mode }
                if has("maxWidth") { style.maxWidth = PopupV3Value.number(values["maxWidth"]) }
            }
            if has("minHeight") { style.minHeight = PopupV3Value.number(values["minHeight"]) }
            if has("padding") { style.padding = PopupV3Value.num(values["padding"], style.padding) }
            if has("borderRadius") { style.borderRadius = PopupV3Value.num(values["borderRadius"], style.borderRadius) }
        }
        return style
    }

    /// Ширина рамки: `width` в px, % или vw от ширины экрана, не больше `maxWidth`.
    func frameWidth(screenWidth: Double) -> Double {
        let base = widthMode == .px ? width : screenWidth * width / 100
        guard let maxWidth else { return base }
        let limit = maxWidthMode == .px ? maxWidth : screenWidth * maxWidth / 100
        return min(base, limit)
    }

    /// Высота рамки, заданная в дизайне; `nil` — по содержимому.
    func fixedHeight(screenHeight: Double) -> Double? {
        guard let height else { return nil }
        switch heightMode {
        case .auto: return nil
        case .px: return height
        case .percent, .vh: return screenHeight * height / 100
        }
    }

    /// Минимальная высота рамки; `nil` — нет.
    func minimumHeight(screenHeight: Double) -> Double? {
        guard let minHeight else { return nil }
        switch minHeightMode {
        case .auto, .px: return minHeight
        case .percent, .vh: return screenHeight * minHeight / 100
        }
    }
}

// MARK: - Сетка

struct PopupV3Row {

    enum BackgroundSize: String { case cover, contain, auto }
    enum BackgroundPosition: String { case center, top, bottom, left, right }
    enum BackgroundRepeat: String { case noRepeat = "no-repeat", repeatBoth = "repeat", repeatX = "repeat-x", repeatY = "repeat-y" }

    let id: String
    /// Доли колонок, в сумме 1.
    let fractions: [CGFloat]
    let gap: CGFloat
    let minHeight: CGFloat
    let backgroundColor: CSSColor?
    let backgroundImage: String?
    let backgroundSize: BackgroundSize
    let backgroundPosition: BackgroundPosition
    let backgroundRepeat: BackgroundRepeat
    let cells: [PopupV3Cell]

    /// Строка компилятора: доли из `columns` (проценты) или старого `parts`, `gap` 8,
    /// `minHeight` 110, фон цветом или картинкой. Ячейке `elements(index)` отдаёт её элементы.
    init(json: [String: Any], elements: (Int) -> [PopupV3Element]) {
        id = PopupV3Value.string(json["id"]) ?? ""
        fractions = Self.fractions(json)
        gap = CGFloat(PopupV3Value.num(json["gap"], 8))
        minHeight = CGFloat(PopupV3Value.num(json["minHeight"], 110))
        backgroundColor = PopupV3Value.isPresent(json["bgColor"]) ? CSSColor.parse(json["bgColor"]) : nil
        backgroundImage = PopupV3Links.safeHTTP(json["bgImageUrl"] as? String)
        backgroundSize = (json["bgSize"] as? String).flatMap(BackgroundSize.init(rawValue:)) ?? .cover
        backgroundPosition = (json["bgPosition"] as? String).flatMap(BackgroundPosition.init(rawValue:)) ?? .center
        backgroundRepeat = (json["bgRepeat"] as? String).flatMap(BackgroundRepeat.init(rawValue:)) ?? .noRepeat
        let rawCells = json["cells"] as? [Any] ?? []
        let rowAlign = PopupV3HAlign(json["align"]) ?? .left
        let rowVertical = PopupV3VAlign(json["verticalAlign"]) ?? .top
        cells = fractions.indices.map { index in
            let cell = index < rawCells.count ? rawCells[index] as? [String: Any] ?? [:] : [:]
            return PopupV3Cell(
                align: PopupV3HAlign(cell["align"]) ?? rowAlign,
                verticalAlign: PopupV3VAlign(cell["verticalAlign"]) ?? rowVertical,
                elements: elements(index)
            )
        }
    }

    private init(free elements: [PopupV3Element]) {
        id = ""
        fractions = [1]
        gap = 8
        minHeight = 0
        backgroundColor = nil
        backgroundImage = nil
        backgroundSize = .cover
        backgroundPosition = .center
        backgroundRepeat = .noRepeat
        cells = [PopupV3Cell(align: .left, verticalAlign: .top, elements: elements)]
    }

    /// Старый дизайн без строк — одна колонка потоком.
    static func free(_ elements: [PopupV3Element]) -> PopupV3Row {
        PopupV3Row(free: elements)
    }

    /// Доли: `columns` в процентах (сумма 0 — как 1), иначе `parts` равными долями, иначе одна колонка.
    static func fractions(_ json: [String: Any]) -> [CGFloat] {
        var columns = (json["columns"] as? [Any] ?? []).map { max(0, PopupV3Value.num($0, 0)) }
        if columns.isEmpty {
            let parts = Int(PopupV3Value.num(json["parts"], 1))
            columns = Array(repeating: 1, count: max(1, min(PopupV3Design.maxColumns, parts)))
        }
        if columns.count > PopupV3Design.maxColumns {
            PopupsV3Log.log("row has \(columns.count) columns, only \(PopupV3Design.maxColumns) are drawn")
            columns = Array(columns.prefix(PopupV3Design.maxColumns))
        }
        let sum = columns.reduce(0, +)
        let total = sum == 0 ? 1 : sum
        return columns.map { CGFloat($0 / total) }
    }
}

struct PopupV3Cell {
    let align: PopupV3HAlign
    let verticalAlign: PopupV3VAlign
    let elements: [PopupV3Element]

    /// Элемент со своим `cellVerticalAlign` прижимается сам, а ячейка — к верху.
    var justify: PopupV3VAlign {
        elements.contains { $0.cellVerticalAlign != nil } ? .top : verticalAlign
    }
}

// MARK: - Элемент

struct PopupV3Element {

    let id: String
    let type: String
    let style: [String: Any]
    let statics: [String: String]

    /// Стиль нового элемента в редакторе (`DEFAULTS` компилятора). У emailCollector и form здесь нет
    /// раскладки, флагов согласия и полей: без них в документе компилятор рисует столбик, все три
    /// флага и форму без полей — так и мы.
    static let defaults: [String: [String: Any]] = [
        "text": ["fontSize": 16, "bgColor": "transparent", "messageAlign": "left"],
        "box": ["bgColor": "#f8fafc", "borderRadius": 12, "paddingX": 16, "paddingY": 16],
        "button": [
            "buttonAction": "link", "buttonAlign": "center", "buttonBgColor": "#2563eb", "buttonTextColor": "#ffffff",
            "buttonFontSize": 14, "buttonPaddingX": 20, "buttonPaddingY": 10, "buttonRadius": 10
        ],
        "close": [
            "closeIconMode": "text", "buttonAlign": "right", "buttonBgColor": "transparent", "buttonTextColor": "#71717a",
            "buttonFontSize": 22, "buttonPaddingX": 8, "buttonPaddingY": 2, "buttonRadius": 999
        ],
        "image": ["bgColor": "transparent", "imageHeightMode": "auto", "imageObjectFit": "cover", "imageRadius": 8],
        "emailCollector": ["borderRadius": 12, "buttonBgColor": "#2563eb", "buttonTextColor": "#ffffff"],
        "form": ["borderRadius": 12, "buttonBgColor": "#2563eb", "buttonTextColor": "#ffffff"],
        "promoCode": [
            "promoSource": "personal", "promoShowCopy": true, "promoCodeBg": "#fef3c7", "promoCodeColor": "#92400e",
            "promoCodeRadius": 10, "promoCodeFontSize": 20, "messageAlign": "center", "bgColor": "transparent"
        ],
        "survey": [
            "surveyType": "nps", "surveyScaleBg": "#f3f4f6", "surveyScaleColor": "#111827",
            "surveyScaleActiveBg": "#2563eb", "surveyScaleActiveColor": "#ffffff",
            "buttonBgColor": "#2563eb", "buttonTextColor": "#ffffff"
        ],
        "recommendation": ["bgColor": "transparent"]
    ]

    /// Тянутся на всю ширину ячейки; прочие — по содержимому.
    static let stretchTypes: Set<String> = ["image", "emailCollector", "form", "promoCode", "survey", "recommendation"]
    /// Ссылка `linkHref` на всём элементе.
    static let linkableTypes: Set<String> = ["text", "box", "image"]

    init(id: String, type: String, style: [String: Any], statics: [String: String] = [:]) {
        self.id = id
        self.type = type
        self.style = style
        self.statics = statics
    }

    var stretches: Bool { Self.stretchTypes.contains(type) }

    /// Значение ключа: из документа, иначе из `DEFAULTS` типа.
    func value(_ key: String) -> Any? {
        let own = style[key]
        if PopupV3Value.isPresent(own) { return own }
        return Self.defaults[type]?[key]
    }

    func num(_ key: String, _ fallback: Double) -> Double {
        PopupV3Value.num(value(key), fallback)
    }

    func color(_ key: String, _ fallback: CSSColor) -> CSSColor {
        CSSColor.parse(value(key)) ?? fallback
    }

    func bool(_ key: String) -> Bool? {
        PopupV3Value.bool(value(key))
    }

    /// Строка как есть, без переменных; пустая — `nil`.
    func string(_ key: String) -> String? {
        PopupV3Value.string(value(key))
    }

    /// Текст с переменными: статическими и витринными `runtime`.
    func text(_ key: String, runtime: [String: String] = [:]) -> String? {
        string(key).map { PopupV3Variables.apply($0, statics: statics, runtime: runtime) }
    }

    /// Переменные в произвольной строке элемента (подписи полей формы).
    func substitute(_ text: String, runtime: [String: String] = [:]) -> String {
        PopupV3Variables.apply(text, statics: statics, runtime: runtime)
    }

    var cellAlign: PopupV3HAlign? { PopupV3HAlign(style["cellAlign"]) }
    var cellVerticalAlign: PopupV3VAlign? { PopupV3VAlign(style["cellVerticalAlign"]) }

    /// Ссылка на всём элементе — только у text, box, image.
    func link(runtime: [String: String] = [:]) -> String? {
        guard Self.linkableTypes.contains(type) else { return nil }
        return PopupV3Links.usable(text("linkHref", runtime: runtime))
    }

    /// Коробка стилей элемента (`Context#box_declarations` с поправками типа).
    var box: PopupV3Box {
        var box = PopupV3Box(
            background: color("bgColor", .white),
            textColor: color("textColor", CSSColor(red: 0x11, green: 0x18, blue: 0x27, alpha: 255)),
            borderWidth: num("borderWidth", 0),
            borderColor: color("borderColor", CSSColor(red: 0xd4, green: 0xd4, blue: 0xd8, alpha: 255)),
            borderRadius: num("borderRadius", 0),
            paddingX: num("paddingX", 0),
            paddingY: num("paddingY", 0),
            fontFamily: string("fontFamily"),
            fontSize: num("fontSize", 12),
            fontWeight: num("fontWeight", 500),
            letterSpacing: num("letterSpacing", 0),
            lineHeight: num("lineHeight", 1.35),
            opacity: max(0, min(1, num("opacity", 1))),
            shadowY: num("shadowY", 0),
            shadowBlur: num("shadowBlur", 0),
            shadowColor: Self.shadowColor(value("shadowColor"))
        )
        switch type {
        case "button", "close":
            box.background = .transparent
            box.borderWidth = 0
        case "recommendation":
            box.background = .transparent
            box.borderWidth = 0
            box.paddingX = 0
            box.paddingY = 0
            box.shadowY = 0
            box.shadowBlur = 0
        case "emailCollector", "form":
            box.background = color("bgColor", .white)
            box.textColor = color("textColor", CSSColor(red: 0x0f, green: 0x17, blue: 0x2a, alpha: 255))
            box.borderColor = color("borderColor", CSSColor(red: 0xe2, green: 0xe8, blue: 0xf0, alpha: 255))
            box.borderRadius = num("borderRadius", 12)
            box.paddingX = num("paddingX", 12)
            box.paddingY = num("paddingY", 12)
        default:
            break
        }
        return box
    }

    /// Цвет тени: к шестизначному hex (и к запасному чёрному) компилятор дописывает альфу `55`.
    static func shadowColor(_ value: Any?) -> CSSColor {
        guard let color = CSSColor.parse(value) else { return CSSColor.black.with(alpha: 0x55) }
        return CSSColor.isSixDigitHex(value) ? color.with(alpha: 0x55) : color
    }
}

/// Общие стили обёртки элемента.
struct PopupV3Box: Equatable {
    var background: CSSColor
    var textColor: CSSColor
    var borderWidth: Double
    var borderColor: CSSColor
    var borderRadius: Double
    var paddingX: Double
    var paddingY: Double
    var fontFamily: String?
    var fontSize: Double
    var fontWeight: Double
    var letterSpacing: Double
    var lineHeight: Double
    var opacity: Double
    var shadowY: Double
    var shadowBlur: Double
    var shadowColor: CSSColor

    var hasShadow: Bool { (shadowY != 0 || shadowBlur != 0) && !shadowColor.isTransparent }
}

// MARK: - Ссылки

enum PopupV3Links {

    /// Ссылка, которую можно открыть: пустая — `nil`; `javascript:` и `data:` отбрасываются.
    /// Прочие схемы (в том числе deep link приложения) разрешены.
    static func usable(_ raw: String?) -> String? {
        guard let text = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        let lower = text.lowercased()
        if lower.hasPrefix("javascript:") || lower.hasPrefix("data:") || lower.hasPrefix("vbscript:") { return nil }
        // Токен, который нечем подставить, — не адрес.
        if text.contains("{{") { return nil }
        return text
    }

    /// Адрес картинки: только http и https.
    static func safeHTTP(_ raw: String?) -> String? {
        guard let text = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty,
              let scheme = URL(string: text)?.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return nil }
        return text
    }
}
