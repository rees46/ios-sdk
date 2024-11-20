
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
