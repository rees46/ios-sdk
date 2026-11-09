import UIKit

// Облегчённая разметка текстов попапа и переменные `{{key}}`.
//
// Разметка — один регэксп компилятора дизайна (`Context::RICH_TEXT_RE`), сканирование слева
// направо без вложенности: `***жирный курсив***`, `**жирный**`, `*курсив*`, `__подчёркнутый__`,
// `~~зачёркнутый~~`, `^^надчёркнутый^^`. Переводы строк — как есть, HTML-теги — обычный текст.
//
// Переменные: статические из `design.variables` подставляются сразу, витринные (`promo_code` и
// др.) — при показе; неизвестный ключ остаётся токеном. Ссылки под платформу: для `{{key}}`
// сначала `key_ios`, потом `key`.

/// Кусок текста с начертанием.
struct PopupV3Span: Equatable {
    var text: String
    var bold = false
    var italic = false
    var underline = false
    var strike = false
    var overline = false
}

enum PopupV3Markup {

    static let pattern = #"\*\*\*([^*]+)\*\*\*|\*\*([^*]+)\*\*|~~([^~]+)~~|__([^_]+)__|\^\^([^^]+)\^\^|\*([^*]+)\*"#

    private static let regex = try! NSRegularExpression(pattern: pattern)

    /// Куски текста по порядку; пустая строка — ни одного.
    static func spans(_ text: String) -> [PopupV3Span] {
        guard !text.isEmpty else { return [] }
        let source = text as NSString
        var spans: [PopupV3Span] = []
        var cursor = 0
        for match in regex.matches(in: text, range: NSRange(location: 0, length: source.length)) {
            if match.range.location > cursor {
                spans.append(PopupV3Span(text: source.substring(with: NSRange(location: cursor, length: match.range.location - cursor))))
            }
            // Группа совпадения: 1 — жирный курсив, 2 — жирный, 3 — зачёркнутый, 4 — подчёркнутый,
            // 5 — надчёркнутый, 6 — курсив.
            for group in 1...6 {
                let range = match.range(at: group)
                guard range.location != NSNotFound else { continue }
                var span = PopupV3Span(text: source.substring(with: range))
                switch group {
                case 1: span.bold = true; span.italic = true
                case 2: span.bold = true
                case 3: span.strike = true
                case 4: span.underline = true
                case 5: span.overline = true
                default: span.italic = true
                }
                spans.append(span)
                break
            }
            cursor = match.range.location + match.range.length
        }
        if cursor < source.length {
            spans.append(PopupV3Span(text: source.substring(from: cursor)))
        }
        return spans
    }

    /// Текст без разметки — для буфера обмена и подписей доступности.
    static func plain(_ text: String) -> String {
        spans(text).map(\.text).joined()
    }
}

enum PopupV3Variables {

    /// Витринные переменные: их значения подставляет SDK при показе, из `variables` они не берутся.
    static let runtimeKeys: Set<String> = ["promo_code", "coupon_code", "campaign_end", "remaining", "progress", "cart_total", "wheel_prize"]

    /// Суффикс платформенных переменных: `{{link}}` на iOS — сначала `link_ios`.
    static let platform = "ios"

    private static let token = try! NSRegularExpression(pattern: #"\{\{\s*([a-zA-Z0-9_]+)\s*\}\}"#)

    /// Статические переменные дизайна: объект или старый массив `{key, value}`; значения — строками,
    /// записи без ключа пропускаются, витринные ключи отбрасываются.
    static func statics(_ raw: Any?) -> [String: String] {
        var result: [String: String] = [:]
        switch raw {
        case let object as [String: Any]:
            for (key, value) in object { result[key] = text(value) }
        case let items as [Any]:
            for case let item as [String: Any] in items {
                guard let key = PopupV3Value.string(item["key"]) else { continue }
                result[key] = text(item["value"])
            }
        default:
            break
        }
        return result.filter { !runtimeKeys.contains($0.key) }
    }

    /// Подстановка за один проход: витринный ключ — из `runtime`, прочие — из `statics`
    /// (`key_ios`, затем `key`); чего нет — токен остаётся как есть.
    static func apply(_ text: String, statics: [String: String], runtime: [String: String] = [:]) -> String {
        guard text.contains("{{") else { return text }
        let source = text as NSString
        var result = ""
        var cursor = 0
        for match in token.matches(in: text, range: NSRange(location: 0, length: source.length)) {
            result += source.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            let key = source.substring(with: match.range(at: 1))
            let value: String?
            if runtimeKeys.contains(key) {
                value = runtime[key]
            } else {
                value = statics["\(key)_\(platform)"] ?? statics[key]
            }
            result += value ?? source.substring(with: match.range)
            cursor = match.range.location + match.range.length
        }
        result += source.substring(from: cursor)
        return result
    }

    /// Есть ли в тексте токен `key`.
    static func contains(_ key: String, in text: String) -> Bool {
        let source = text as NSString
        return token.matches(in: text, range: NSRange(location: 0, length: source.length))
            .contains { source.substring(with: $0.range(at: 1)) == key }
    }

    private static func text(_ value: Any?) -> String {
        switch value {
        case let text as String: return text
        case let number as NSNumber:
            if PopupV3Value.isBool(number) { return number.boolValue ? "true" : "false" }
            return number.stringValue
        default: return ""
        }
    }
}

/// Надчёркивание — своим атрибутом: у `NSAttributedString` его нет, линию рисует `PopupV3Label`.
extension NSAttributedString.Key {
    static let popupV3Overline = NSAttributedString.Key("PersonalizationPopupV3Overline")
}
