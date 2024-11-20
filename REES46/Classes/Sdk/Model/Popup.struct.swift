public struct PopupComponents: Codable {
    let text: String?
    let image: String?
    let button: String?
    let header: String?
    let text_enabled: String?
    let image_enabled: String?
    let header_enabled: String?
}

public struct Popup: Codable {
    enum Position: String {
        case centered = "centered"
        case bottom = "fixed_bottom"
    }
    
    let id: Int
    let channels: [String]
    let position: String
    let delay: Int
    let html: String
    let components: PopupComponents?
    let web_push_system: Bool
    let popup_actions: String
    
    func getParsedPopupActions() -> PopupActions? {
        guard let data = popup_actions.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        do {
            let actions = try decoder.decode(PopupActions.self, from: data)
            return actions
        } catch {
            print("[getParsedPopupActions] Error decoding popup actions: \(error)")
            return nil
        }
    }
}

public struct PopupActions: Codable {
    let link: Link?
    let close: Close?
    
    struct Link: Codable {
        let link_ios: String?
        let link_android: String?
        let link_web: String?
        let button_text: String?
    }
    
    struct Close: Codable {
        let button_text: String?
    }
}
