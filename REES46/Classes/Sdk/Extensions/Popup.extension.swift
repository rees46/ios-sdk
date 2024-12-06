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
        let title = RegexHelper.extract(
            using: RegexPattern.title,
            from: html
        )
        let subTitle = RegexHelper.extract(
            using: RegexPattern.subTitle,
            from: html
        )
        return (title, subTitle)
    }
}
