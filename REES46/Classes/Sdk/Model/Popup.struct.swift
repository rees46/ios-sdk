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

public struct Popup: Codable {
    let id: Int
    let channels: [String]
    let position: String
    let delay: Int
    let html: String
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
