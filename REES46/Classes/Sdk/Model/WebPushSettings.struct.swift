import Foundation

struct WebPushSettings: Codable {
    var publicKey: String
    var safariEnabled: Bool
    var safariId: String
    var serviceWorker: String
    
    init(json: [String: Any]) {
        publicKey = json["public_key"] as? String ?? ""
        safariEnabled = json["safari_enabled"] as? Bool ?? false
        safariId = json["safari_id"] as? String ?? ""
        serviceWorker = json["service_worker"] as? String ?? ""
    }
    
    init() {
        self.publicKey = ""
        self.safariEnabled = false
        self.safariId = ""
        self.serviceWorker = ""
    }
}
