import Foundation

public struct Popup: Codable {
    public enum Position: String {
        case centered = "centered"
        case bottom = "fixed_bottom"
        case top = "top"
    }
    
    public let id: Int
    public let channels: [String]
    public let position: String
    public let delay: Int
    public let html: String
    public let components: PopupComponents?
    public let web_push_system: Bool
    public let popup_actions: String
    
    public func getParsedPopupActions() -> PopupActions? {
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
