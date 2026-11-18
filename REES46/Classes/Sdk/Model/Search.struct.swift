import Foundation

struct Search: Codable {
    var enable: Int
    var landing: String
    var type: String
    var settings: Settings
    /// `blank_mode`: `agent` when the shop turned the search agent on (`search.agentEnabled`).
    var blankMode: String?
    
    init(json: [String: Any]) {
        enable = json["enabled"] as? Int ?? 0
        landing = json["landing"] as? String ?? ""
        type = json["type"] as? String ?? ""
        settings = Settings(json: json["settings"] as? [String: Any] ?? [:])
        blankMode = json["blank_mode"] as? String
    }
    
    init() {
        self.enable = 0
        self.landing = ""
        self.type = ""
        self.settings = Settings()
    }
}
