import Foundation

struct Search: Codable {
    var enable: Int
    var landing: String
    var type: String
    var settings: Settings
    
    init(json: [String: Any]) {
        enable = json["enabled"] as? Int ?? 0
        landing = json["landing"] as? String ?? ""
        type = json["type"] as? String ?? ""
        settings = Settings(json: json["settings"] as? [String: Any] ?? [:])
    }
    
    init() {
        self.enable = 0
        self.landing = ""
        self.type = ""
        self.settings = Settings()
    }
}
