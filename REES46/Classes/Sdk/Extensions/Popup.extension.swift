extension Popup {
    init(json: [String: Any]) {
        self.id = json["id"] as? Int ?? 0
        self.channels = json["channels"] as? [String] ?? []
        self.position = json["position"] as? String ?? ""
        self.delay = json["delay"] as? Int ?? 0
        self.html = json["html"] as? String ?? ""
        self.web_push_system = json["web_push_system"] as? Bool ?? false
        self.popup_actions = json["popup_actions"] as? String ?? ""
        
        if let componentsString = json["components"] as? String,
           let componentsData = componentsString.data(using: .utf8) {
            self.components = try? JSONDecoder().decode(PopupComponents.self, from: componentsData)
        } else {
            self.components = nil
        }
    }

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

            let header = extract(using: titleRegex, from: html)
            let text = extract(using: subTitleRegex, from: html)
            return (header, text)
        }
}
