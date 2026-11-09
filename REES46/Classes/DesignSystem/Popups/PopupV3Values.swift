import UIKit

// Разбор значений документа design попапов v3. Числа приходят и строками, и `null`, — как в
// компиляторе дизайна (`Context#num`): что не разобралось — запасное значение элемента.
// Цвета — CSS: `#rgb`, `#rgba`, `#rrggbb`, `#rrggbbaa` (порядок CSS, альфа в конце), `rgb()` и
// `rgba()` через запятые или пробелы, 148 имён и `transparent`.

/// Число, флаг и строка из JSON дизайна.
enum PopupV3Value {

    /// Число из числа или строки: строка читается как `parseFloat` — `"12px"` → 12, `" 7 "` → 7;
    /// пустая строка, `null`, логическое, нечисло — `fallback`.
    static func num(_ value: Any?, _ fallback: Double) -> Double {
        number(value) ?? fallback
    }

    /// Число или `nil`, правила — как у `num`.
    static func number(_ value: Any?) -> Double? {
        switch value {
        case let number as NSNumber:
            if isBool(number) { return nil }
            let double = number.doubleValue
            return double.isFinite ? double : nil
        case let text as String:
            return parseFloat(text)
        default:
            return nil
        }
    }

    /// Флаг: `true`, `"true"`, ненулевое число — истина; `false`, `"false"`, `0` — ложь; прочее — `nil`.
    static func bool(_ value: Any?) -> Bool? {
        switch value {
        case let number as NSNumber:
            return isBool(number) ? number.boolValue : number.doubleValue != 0
        case let text as String:
            switch text.trimmingCharacters(in: .whitespaces).lowercased() {
            case "true", "1": return true
            case "false", "0": return false
            default: return nil
            }
        default:
            return nil
        }
    }

    /// Строка как есть; число — его запись; `null`, пустая строка и прочее — `nil`.
    static func string(_ value: Any?) -> String? {
        switch value {
        case let text as String:
            return text.isEmpty ? nil : text
        case let number as NSNumber:
            if isBool(number) { return number.boolValue ? "true" : "false" }
            return number.stringValue
        default:
            return nil
        }
    }

    /// Ключ задан: не `null` и не пустая строка — правило умолчаний дизайна.
    static func isPresent(_ value: Any?) -> Bool {
        switch value {
        case nil, is NSNull: return false
        case let text as String: return !text.isEmpty
        default: return true
        }
    }

    static func isBool(_ number: NSNumber) -> Bool {
        number === kCFBooleanTrue || number === kCFBooleanFalse
    }

    /// Начало строки как число, как `parseFloat` в JS: пробелы по краям, знак, дробь, экспонента.
    static func parseFloat(_ text: String) -> Double? {
        let scalars = Array(text.trimmingCharacters(in: .whitespacesAndNewlines).unicodeScalars)
        var index = 0
        func digit(_ i: Int) -> Bool { i < scalars.count && ("0"..."9").contains(scalars[i]) }
        if index < scalars.count, scalars[index] == "+" || scalars[index] == "-" { index += 1 }
        let start = index
        while digit(index) { index += 1 }
        var digits = index - start
        if index < scalars.count, scalars[index] == "." {
            index += 1
            let fraction = index
            while digit(index) { index += 1 }
            digits += index - fraction
        }
        guard digits > 0 else { return nil }
        var end = index
        if index < scalars.count, scalars[index] == "e" || scalars[index] == "E" {
            var exponent = index + 1
            if exponent < scalars.count, scalars[exponent] == "+" || scalars[exponent] == "-" { exponent += 1 }
            let exponentStart = exponent
            while digit(exponent) { exponent += 1 }
            if exponent > exponentStart { end = exponent }
        }
        var view = String.UnicodeScalarView()
        view.append(contentsOf: scalars[0..<end])
        guard let value = Double(String(view)), value.isFinite else { return nil }
        return value
    }
}

/// Цвет CSS: 8 бит на канал, альфа отдельно.
struct CSSColor: Equatable {
    var red: UInt8
    var green: UInt8
    var blue: UInt8
    var alpha: UInt8

    static let transparent = CSSColor(red: 0, green: 0, blue: 0, alpha: 0)
    static let black = CSSColor(red: 0, green: 0, blue: 0, alpha: 255)
    static let white = CSSColor(red: 255, green: 255, blue: 255, alpha: 255)

    /// Запись `#rrggbbaa` в нижнем регистре — так цвета сверяются с общими фикстурами.
    var hex: String {
        String(format: "#%02x%02x%02x%02x", red, green, blue, alpha)
    }

    var uiColor: UIColor {
        UIColor(red: CGFloat(red) / 255, green: CGFloat(green) / 255, blue: CGFloat(blue) / 255, alpha: CGFloat(alpha) / 255)
    }

    var isTransparent: Bool { alpha == 0 }

    func with(alpha value: UInt8) -> CSSColor {
        CSSColor(red: red, green: green, blue: blue, alpha: value)
    }

    /// Цвет из `#…` с непрозрачностью `0…1`, как `overlayColor` + `overlayOpacity`.
    func with(opacity: Double) -> CSSColor {
        with(alpha: Self.channel(fraction: opacity))
    }

    /// Цвет из значения дизайна; не строка, пусто, битая запись, `url(…)` — `nil`.
    static func parse(_ value: Any?) -> CSSColor? {
        guard let raw = value as? String else { return nil }
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !text.isEmpty else { return nil }
        if text.hasPrefix("#") { return hex(String(text.dropFirst())) }
        if text.hasPrefix("rgb") { return function(text) }
        if text == "transparent" { return .transparent }
        return names[text].map { rgb in
            CSSColor(red: UInt8((rgb >> 16) & 0xff), green: UInt8((rgb >> 8) & 0xff), blue: UInt8(rgb & 0xff), alpha: 255)
        }
    }

    /// Шестизначный hex ли это — к такому цвету тени компилятор дописывает альфу `55`.
    static func isSixDigitHex(_ value: Any?) -> Bool {
        guard let raw = value as? String else { return false }
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.count == 7 && text.hasPrefix("#") && text.dropFirst().allSatisfy(\.isHexDigit)
    }

    private static func hex(_ digits: String) -> CSSColor? {
        guard digits.allSatisfy(\.isHexDigit) else { return nil }
        let values = digits.map { UInt8($0.hexDigitValue ?? 0) }
        switch values.count {
        case 3, 4:
            let alpha = values.count == 4 ? values[3] * 17 : 255
            return CSSColor(red: values[0] * 17, green: values[1] * 17, blue: values[2] * 17, alpha: alpha)
        case 6, 8:
            let pairs = stride(from: 0, to: values.count, by: 2).map { values[$0] * 16 + values[$0 + 1] }
            return CSSColor(red: pairs[0], green: pairs[1], blue: pairs[2], alpha: pairs.count == 4 ? pairs[3] : 255)
        default:
            return nil
        }
    }

    /// `rgb(37, 99, 235)`, `rgba(37, 99, 235, 0.5)`, `rgb(0 0 0 / 50%)`.
    private static func function(_ text: String) -> CSSColor? {
        guard let open = text.firstIndex(of: "("), text.hasSuffix(")") else { return nil }
        let name = text[..<open].trimmingCharacters(in: .whitespaces)
        guard name == "rgb" || name == "rgba" else { return nil }
        let body = text[text.index(after: open)..<text.index(before: text.endIndex)]
        var parts = body.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard (1...2).contains(parts.count) else { return nil }
        let slashAlpha = parts.count == 2 ? parts.removeLast().trimmingCharacters(in: .whitespaces) : nil
        var items = parts[0]
            .replacingOccurrences(of: ",", with: " ")
            .split(separator: " ")
            .map(String.init)
        if let slashAlpha {
            guard items.count == 3 else { return nil }
            items.append(slashAlpha)
        }
        guard items.count == 3 || items.count == 4 else { return nil }
        var channels: [UInt8] = []
        for item in items.prefix(3) {
            guard let value = component(item, scale: 255) else { return nil }
            channels.append(UInt8(max(0, min(255, value.rounded(.toNearestOrAwayFromZero)))))
        }
        var alpha: UInt8 = 255
        if items.count == 4 {
            guard let value = component(items[3], scale: 1) else { return nil }
            alpha = channel(fraction: value)
        }
        return CSSColor(red: channels[0], green: channels[1], blue: channels[2], alpha: alpha)
    }

    /// Число или процент от `scale`.
    private static func component(_ text: String, scale: Double) -> Double? {
        if text.hasSuffix("%") {
            return Double(text.dropLast()).map { $0 / 100 * scale }
        }
        return Double(text)
    }

    static func channel(fraction: Double) -> UInt8 {
        UInt8(max(0, min(255, (max(0, min(1, fraction)) * 255).rounded(.toNearestOrAwayFromZero))))
    }

    /// Именованные цвета CSS (148 записей CSS Color Level 4).
    static let names: [String: UInt32] = [
        "aliceblue": 0xf0f8ff, "antiquewhite": 0xfaebd7, "aqua": 0x00ffff, "aquamarine": 0x7fffd4,
        "azure": 0xf0ffff, "beige": 0xf5f5dc, "bisque": 0xffe4c4, "black": 0x000000,
        "blanchedalmond": 0xffebcd, "blue": 0x0000ff, "blueviolet": 0x8a2be2, "brown": 0xa52a2a,
        "burlywood": 0xdeb887, "cadetblue": 0x5f9ea0, "chartreuse": 0x7fff00, "chocolate": 0xd2691e,
        "coral": 0xff7f50, "cornflowerblue": 0x6495ed, "cornsilk": 0xfff8dc, "crimson": 0xdc143c,
        "cyan": 0x00ffff, "darkblue": 0x00008b, "darkcyan": 0x008b8b, "darkgoldenrod": 0xb8860b,
        "darkgray": 0xa9a9a9, "darkgreen": 0x006400, "darkgrey": 0xa9a9a9, "darkkhaki": 0xbdb76b,
        "darkmagenta": 0x8b008b, "darkolivegreen": 0x556b2f, "darkorange": 0xff8c00, "darkorchid": 0x9932cc,
        "darkred": 0x8b0000, "darksalmon": 0xe9967a, "darkseagreen": 0x8fbc8f, "darkslateblue": 0x483d8b,
        "darkslategray": 0x2f4f4f, "darkslategrey": 0x2f4f4f, "darkturquoise": 0x00ced1, "darkviolet": 0x9400d3,
        "deeppink": 0xff1493, "deepskyblue": 0x00bfff, "dimgray": 0x696969, "dimgrey": 0x696969,
        "dodgerblue": 0x1e90ff, "firebrick": 0xb22222, "floralwhite": 0xfffaf0, "forestgreen": 0x228b22,
        "fuchsia": 0xff00ff, "gainsboro": 0xdcdcdc, "ghostwhite": 0xf8f8ff, "gold": 0xffd700,
        "goldenrod": 0xdaa520, "gray": 0x808080, "green": 0x008000, "greenyellow": 0xadff2f,
        "grey": 0x808080, "honeydew": 0xf0fff0, "hotpink": 0xff69b4, "indianred": 0xcd5c5c,
        "indigo": 0x4b0082, "ivory": 0xfffff0, "khaki": 0xf0e68c, "lavender": 0xe6e6fa,
        "lavenderblush": 0xfff0f5, "lawngreen": 0x7cfc00, "lemonchiffon": 0xfffacd, "lightblue": 0xadd8e6,
        "lightcoral": 0xf08080, "lightcyan": 0xe0ffff, "lightgoldenrodyellow": 0xfafad2, "lightgray": 0xd3d3d3,
        "lightgreen": 0x90ee90, "lightgrey": 0xd3d3d3, "lightpink": 0xffb6c1, "lightsalmon": 0xffa07a,
        "lightseagreen": 0x20b2aa, "lightskyblue": 0x87cefa, "lightslategray": 0x778899, "lightslategrey": 0x778899,
        "lightsteelblue": 0xb0c4de, "lightyellow": 0xffffe0, "lime": 0x00ff00, "limegreen": 0x32cd32,
        "linen": 0xfaf0e6, "magenta": 0xff00ff, "maroon": 0x800000, "mediumaquamarine": 0x66cdaa,
        "mediumblue": 0x0000cd, "mediumorchid": 0xba55d3, "mediumpurple": 0x9370db, "mediumseagreen": 0x3cb371,
        "mediumslateblue": 0x7b68ee, "mediumspringgreen": 0x00fa9a, "mediumturquoise": 0x48d1cc, "mediumvioletred": 0xc71585,
        "midnightblue": 0x191970, "mintcream": 0xf5fffa, "mistyrose": 0xffe4e1, "moccasin": 0xffe4b5,
        "navajowhite": 0xffdead, "navy": 0x000080, "oldlace": 0xfdf5e6, "olive": 0x808000,
        "olivedrab": 0x6b8e23, "orange": 0xffa500, "orangered": 0xff4500, "orchid": 0xda70d6,
        "palegoldenrod": 0xeee8aa, "palegreen": 0x98fb98, "paleturquoise": 0xafeeee, "palevioletred": 0xdb7093,
        "papayawhip": 0xffefd5, "peachpuff": 0xffdab9, "peru": 0xcd853f, "pink": 0xffc0cb,
        "plum": 0xdda0dd, "powderblue": 0xb0e0e6, "purple": 0x800080, "rebeccapurple": 0x663399,
        "red": 0xff0000, "rosybrown": 0xbc8f8f, "royalblue": 0x4169e1, "saddlebrown": 0x8b4513,
        "salmon": 0xfa8072, "sandybrown": 0xf4a460, "seagreen": 0x2e8b57, "seashell": 0xfff5ee,
        "sienna": 0xa0522d, "silver": 0xc0c0c0, "skyblue": 0x87ceeb, "slateblue": 0x6a5acd,
        "slategray": 0x708090, "slategrey": 0x708090, "snow": 0xfffafa, "springgreen": 0x00ff7f,
        "steelblue": 0x4682b4, "tan": 0xd2b48c, "teal": 0x008080, "thistle": 0xd8bfd8,
        "tomato": 0xff6347, "turquoise": 0x40e0d0, "violet": 0xee82ee, "wheat": 0xf5deb3,
        "white": 0xffffff, "whitesmoke": 0xf5f5f5, "yellow": 0xffff00, "yellowgreen": 0x9acd32
    ]
}
