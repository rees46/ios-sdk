import Foundation

public struct InitResponse: Codable {
    var deviceId: String = ""
    var seance: String = ""
    var currency: String = ""
    var emailCollector: Bool = false
    var hasEmail: Bool = false
    var recommendations: Bool = false
    var lazyLoad: Bool = false
    var autoCssRecommender: Bool = false
    var cms: String = ""
    var snippets: [String] = []
    var search: Search = Search()
    var webPushSettings: WebPushSettings = WebPushSettings()
    var recone: Bool = false
    var popup: Popup? = nil

    enum CodingKeys: String, CodingKey {
        case deviceId = "did"
        case seance
        case currency
        case emailCollector = "email_collector"
        case hasEmail = "has_email"
        case recommendations
        case lazyLoad = "lazy_load"
        case autoCssRecommender = "auto_css_recommender"
        case cms
        case snippets
        case search
        case webPushSettings = "web_push_settings"
        case recone
        case popup
    }

    init(json: [String: Any]) {
        deviceId = json["did"] as? String ?? ""
        seance = json["seance"] as? String ?? ""
        currency = json["currency"] as? String ?? ""
        emailCollector = json["email_collector"] as? Bool ?? false
        hasEmail = json["has_email"] as? Bool ?? false
        recommendations = json["recommendations"] as? Bool ?? false
        lazyLoad = json["lazy_load"] as? Bool ?? false
        autoCssRecommender = json["auto_css_recommender"] as? Bool ?? false
        cms = json["cms"] as? String ?? ""
        snippets = json["snippets"] as? [String] ?? []
        search = Search(json: json["search"] as? [String: Any] ?? [:])
        webPushSettings = WebPushSettings(json: json["web_push_settings"] as? [String: Any] ?? [:])
        popup = Popup(json: json["popup"] as? [String: Any] ?? [:])
        recone = json["recone"] as? Bool ?? false
    }

    init() {
        self.deviceId = ""
        self.seance = ""
        self.currency = ""
        self.emailCollector = false
        self.hasEmail = false
        self.recommendations = false
        self.lazyLoad = false
        self.autoCssRecommender = false
        self.cms = ""
        self.snippets = []
        self.search = Search()
        self.webPushSettings = WebPushSettings()
        self.popup = nil
        self.recone = false
    }
}

public func convertToDictionary(from response: InitResponse) -> [String: Any]? {
    do {
        let jsonData = try JSONEncoder().encode(response)
        if let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
            return jsonObject
        } else {
            print("[ConvertToDictionary] Failed to convert JSON Data to dictionary")
            return nil
        }
    } catch {
        print("[ConvertToDictionary] Error: \(error)")
        return nil
    }
}
