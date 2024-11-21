import Foundation

struct Settings: Codable {
    var categoriesTitle: String
    var itemsTitle: String
    var lastProductTitle: String
    var lastQueriesTitle: String
    var redirects: [String: String]
    var suggestionTitles: String
    var showAllTitle: String
    
    init(json: [String: Any]) {
        categoriesTitle = json["categories_title"] as? String ?? ""
        itemsTitle = json["items_title"] as? String ?? ""
        lastProductTitle = json["last_products_title"] as? String ?? ""
        lastQueriesTitle = json["last_queries_title"] as? String ?? ""
        redirects = json["redirects"] as? [String: String] ?? [:]
        suggestionTitles = json["suggestions_title"] as? String ?? ""
        showAllTitle = json["show_all_title"] as? String ?? ""
    }
    
    init() {
        self.categoriesTitle = ""
        self.itemsTitle = ""
        self.lastProductTitle = ""
        self.lastQueriesTitle = ""
        self.redirects = [:]
        self.suggestionTitles = ""
        self.showAllTitle = ""
    }
}
