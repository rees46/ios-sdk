import UIKit
import REES46

/// What the demo shop's feed calls its facets, the way an integrator would set it up for their own
/// feed: the kit knows only the format of the response, not what a shop's facets mean. Facets left
/// out here keep the kit's default titles; values of a JSON object (stickers) are shown by their
/// `title` by the kit itself.
enum ShopFacets {

    private static let titles = [
        "stickers": "Стикеры",
        "stickers_liquid": "Стикеры",
        "product_type": "Тип товара"
    ]

    private static let valueTitles = [
        "product_type": ["regular": "Обычный", "digital": "Цифровой", "mto": "Под заказ"]
    ]

    /// Section titles and value labels of the filters of `screen`.
    static func attach<Item>(to screen: PersonalizationResultsScreen<Item>) {
        let kitTitle = screen.facetTitle
        screen.facetTitle = { name in ShopFacets.titles[name] ?? kitTitle(name) }
        screen.facetValueTitle = { facet, value in ShopFacets.valueTitles[facet]?[value] }
    }
}
