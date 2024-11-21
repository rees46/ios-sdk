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
        if let search = json["search"] as? [String: Any] {
            self.search = Search(json: search)
        }
        if let webPush = json["web_push_settings"] as? [String: Any] {
            self.webPushSettings = WebPushSettings(json: webPush)
        }
        recone = json["recone"] as? Bool ?? false
    }

    init() {
    }
}

struct Search: Codable {
    var enable: Int = 0
    var landing: String = ""
    var type: String = ""
    var settings: Settings = Settings()

    init(json: [String: Any]) {
        enable = json["enabled"] as? Int ?? 0
        landing = json["landing"] as? String ?? ""
        type = json["type"] as? String ?? ""
        let settings = json["settings"] as? [String: Any] ?? [:]
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
    var enableFullSearch: Bool = false
    var appendToBody: Bool = false
    var enableLastQueries: Bool = false
    var enableOldPrice: Bool = false
    var popularLinksTitle: String = ""
    var popularCategoriesTitle: String = ""
    var popularBrandsTitle: String = ""
    var priceFilterName: String = ""
    var priceFilterFrom: String = ""
    var priceFilterTo: String = ""

    init(json: [String: Any]) {
        categoriesTitle = json["categories_title"] as? String ?? ""
        itemsTitle = json["items_title"] as? String ?? ""
        lastProductTitle = json["last_products_title"] as? String ?? ""
        lastQueriesTitle = json["last_queries_title"] as? String ?? ""
        redirects = json["redirects"] as? [String: String] ?? [:]
        suggestionTitles = json["suggestions_title"] as? String ?? ""
        showAllTitle = json["show_all_title"] as? String ?? ""
        enableFullSearch = json["enable_full_search"] as? Bool ?? false
        appendToBody = json["append_to_body"] as? Bool ?? false
        enableLastQueries = json["enable_last_queries"] as? Bool ?? false
        enableOldPrice = json["enable_old_price"] as? Bool ?? false
        popularLinksTitle = json["popular_links_title"] as? String ?? ""
        popularCategoriesTitle = json["popular_categories_title"] as? String ?? ""
        popularBrandsTitle = json["popular_brands_title"] as? String ?? ""
        priceFilterName = json["price_filter_name"] as? String ?? ""
        priceFilterFrom = json["price_filter_from"] as? String ?? ""
        priceFilterTo = json["price_filter_to"] as? String ?? ""
    }

    init() {
    }
}

struct WebPushSettings: Codable {
    var publicKey: String = ""
    var safariEnabled: Bool = false
    var safariId: String = ""
    var serviceWorker: String = ""

    init(json: [String: Any]) {
        publicKey = json["public_key"] as? String ?? ""
        safariEnabled = json["safari_enabled"] as? Bool ?? false
        safariId = json["safari_id"] as? String ?? ""
        serviceWorker = json["service_worker"] as? String ?? ""
    }

    init() {
    }
}
