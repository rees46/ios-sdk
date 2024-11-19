import Foundation

extension Popup {
    init(json: [String: Any]) {
        self.id = json["id"] as? Int ?? 0
        self.channels = json["channels"] as? [String] ?? []
        self.position = json["position"] as? String ?? ""
        self.delay = json["delay"] as? Int ?? 0
        self.html = json["html"] as? String ?? ""
        self.web_push_system = json["web_push_system"] as? Bool ?? false
        self.popup_actions = json["popup_actions"] as? String ?? ""
    }
}

extension Popup {
    func extractTitleAndSubtitle() -> (title: String?, subTitle: String?) {
        let titleRegex = "<div class=\"popup-title\"[^>]*>(.*?)<\\/div>"
        let subTitleRegex = "<p class=\"popup-\\d+__intro\"[^>]*>(.*?)<\\/p>"

        func extract(using pattern: String, from html: String) -> String? {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
            let range = NSRange(html.startIndex..<html.endIndex, in: html)
            if let match = regex.firstMatch(in: html, options: [], range: range),
               let range = Range(match.range(at: 1), in: html) {
                return String(html[range])
            }
            return nil
        }
        
        let title = extract(using: titleRegex, from: html)
        let subTitle = extract(using: subTitleRegex, from: html)
        return (title, subTitle)
    }
    
    func extractImageUrl() -> String {
        if html.isEmpty {
            return ""
        }
        
        print("HTML content: \(html)")

        let regex = #"<img[^>]+src\s*=\s*['\"]([^'\"]+)['\"]"#
        guard let regex = try? NSRegularExpression(pattern: regex, options: []) else { return "" }
        
        let matches = regex.matches(in: html, options: [], range: NSRange(html.startIndex..<html.endIndex, in: html))
        
        if let match = matches.first {
            if let range = Range(match.range(at: 1), in: html) {
                return String(html[range])
            }
        }
        
        return ""
    }
}
