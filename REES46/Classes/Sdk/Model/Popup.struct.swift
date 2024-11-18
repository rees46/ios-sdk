import Foundation

public struct Popup: Codable {
    var id: Int
    var channels: [String]
    var position: String
    var delay: Int
    var html: String
    var webPushSystem: Bool
    var popupActions: String?

    init(json: [String: Any]) {
        id = json["id"] as? Int ?? 0
        channels = json["channels"] as? [String] ?? []
        position = json["position"] as? String ?? ""
        delay = json["delay"] as? Int ?? 0
        html = json["html"] as? String ?? ""
        webPushSystem = json["web_push_system"] as? Bool ?? false
        popupActions = json["popup_actions"] as? String
    }

    init() {
        self.id = 0
        self.channels = []
        self.position = ""
        self.delay = 0
        self.html = ""
        self.webPushSystem = false
        self.popupActions = nil
    }
}
