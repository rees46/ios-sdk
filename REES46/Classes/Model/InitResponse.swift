

struct InitResponse: Codable {
    var ssid: String = ""
    var seance: String = ""
    var currency: String = ""
    var search: Search = Search()
    var webPushSettings: WebPushSet = WebPushSet()

    init(json: [String: Any]) {
        ssid = json["ssid"] as! String
        seance = json["seance"] as! String
        currency = json["currency"] as! String
        let search = json["search"] as! [String: Any]
        let webPushSet = json["web_push_settings"] as! [String: Any]

        self.search = Search(json: search)
        webPushSettings = WebPushSet(json: webPushSet)
    }
    
    init() {
        
    }
}

struct Search: Codable {
    var enable: Int = 0
    var landing: String = ""
    var settings: Settings = Settings()

    init(json: [String: Any]) {
        enable = json["enabled"] as! Int
        landing = json["landing"] as! String
        let settings = json["settings"] as! [String: Any]
        self.settings = Settings(json: settings)
    }
    
    init() {
    }
}

struct Settings: Codable {
    var categoriesTitle: String = ""
    var itemsTitle: String = ""
    var lastProductTitle: String = ""
    var lastQueriesTitle: String = ""
    var redirects: [String: String] = [:]
    var suggestionTitles: String = ""
    var showAllTitle: String = ""

    init(json: [String: Any]) {
        categoriesTitle = json["categories_title"] as! String
        itemsTitle = json["items_title"] as! String
        lastProductTitle = json["last_products_title"] as! String
        lastQueriesTitle = json["last_queries_title"] as! String
        redirects = json["redirects"] as! [String: String]
        suggestionTitles = json["suggestions_title"] as! String
        showAllTitle = json["show_all_title"] as! String
    }
    
    init() {
    }
}

struct WebPushSet: Codable {
    var safariEnable: Int = 0
    var safariId: String = ""

    init(json: [String: Any]) {
        safariEnable = json["safari_enabled"] as! Int
        safariId = json["safari_id"] as! String
    }
    
    init() {
    }
}
