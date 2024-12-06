struct RegexHelper {
    static func extract(using pattern: String, from text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        if let match = regex.firstMatch(in: text, options: [], range: range),
           let matchRange = Range(match.range(at: 1), in: text) {
            return String(text[matchRange])
        }
        return nil
    }
}
