import Foundation

/// Один маппер «товар API → карточка кита» для всех виджетов с данными.
///
/// Поиск, категория, коллекция, `products`, `products/get` и рекомендации `extended=1`
/// отдают товар одной формы, а модели SDK у них разные: `Product`, `CategoryProduct`,
/// `ProductInfo`, `Recommended`. Каждая модель кладёт свои поля в `Fields`, правила
/// карточки живут только здесь. Сторис со своим маппингом сюда не входят.
enum ProductMapper {

    /// Поля товара, из которых собирается карточка. Пустая строка — то же, что `nil`:
    /// модели SDK отдают отсутствующие строки по-разному.
    struct Fields {
        var id: String
        var name: String
        var price: Double
        var priceFormatted: String?
        var currency: String?
        var oldPrice: Double?
        var oldPriceFormatted: String?
        var discount: Int?
        var discountFormatted: String?
        var discountPercent: Int?
        var picture: String?
        var imageUrl: String?
        var brand: String?
        var url: String?
        var deeplink: String?
    }

    /// Строки берутся уже отформатированными сервером. Цена — `price_formatted`, иначе
    /// число с валютой. Старая цена — только когда она больше цены. Бейдж скидки — только
    /// при старой цене и положительной скидке: `discount`, иначе `discount_percent`.
    /// Его текст — `discount_formatted` (сервер форматирует его из `discount`), иначе число
    /// с «%»; впереди ровно один «-». Картинка — `picture` (уменьшенная копия), иначе
    /// оригинал. Рейтинга в API нет.
    static func card(_ fields: Fields, actionText: String?) -> PersonalizationProduct {
        let oldPriceText = text(fields.oldPriceFormatted)
        let hasOldPrice = (fields.oldPrice ?? 0) > fields.price && oldPriceText != nil
        var discountText: String?
        if hasOldPrice {
            if let discount = fields.discount, discount > 0 {
                discountText = badge(fields.discountFormatted, discount)
            } else if let percent = fields.discountPercent, percent > 0 {
                // `discount_formatted` здесь не берётся: он про `discount`, а тот не больше нуля.
                discountText = badge(nil, percent)
            }
        }
        return PersonalizationProduct(
            id: fields.id,
            name: fields.name,
            price: text(fields.priceFormatted) ?? "\(fields.price) \(fields.currency ?? "")",
            imageUrl: text(fields.picture) ?? text(fields.imageUrl),
            brand: text(fields.brand),
            oldPrice: hasOldPrice ? oldPriceText : nil,
            discount: discountText,
            actionText: actionText,
            url: text(fields.url),
            deeplink: text(fields.deeplink)
        )
    }

    /// Текст бейджа: `formatted` без своих минусов («6%», «-6%», «--6%» → «-6%»),
    /// пустой — `number` с «%».
    private static func badge(_ formatted: String?, _ number: Int) -> String {
        let body = (formatted ?? "").trimmingCharacters(in: .whitespaces).drop { $0 == "-" || $0 == "\u{2212}" }
        return "-" + (body.isEmpty ? "\(number)%" : String(body))
    }

    private static func text(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }
}

extension Product {
    /// Товар поиска и `products` → данные карточки кита.
    func toCardProduct(actionText: String? = nil) -> PersonalizationProduct {
        ProductMapper.card(ProductMapper.Fields(
            id: id, name: name, price: price, priceFormatted: priceFormatted, currency: currency,
            oldPrice: oldPrice, oldPriceFormatted: oldPriceFormatted,
            discount: discount, discountFormatted: discountFormatted, discountPercent: discountPercent,
            picture: resizedImageUrl, imageUrl: imageUrl, brand: brand,
            url: url, deeplink: deeplinkIos
        ), actionText: actionText)
    }
}

extension Recommended {
    /// Товар рекомендаций (`extended=1`) → данные карточки кита.
    func toCardProduct(actionText: String? = nil) -> PersonalizationProduct {
        ProductMapper.card(ProductMapper.Fields(
            id: id, name: name, price: price, priceFormatted: priceFormatted, currency: currency,
            oldPrice: oldPrice, oldPriceFormatted: oldPriceFormatted,
            discount: discount, discountFormatted: discountFormatted, discountPercent: discountPercent,
            picture: resizedImageUrl, imageUrl: imageUrl, brand: brand,
            url: url, deeplink: deeplinkIos
        ), actionText: actionText)
    }
}

extension CategoryProduct {
    /// Товар категории и коллекции → данные карточки кита.
    func toCardProduct(actionText: String? = nil) -> PersonalizationProduct {
        ProductMapper.card(ProductMapper.Fields(
            id: id ?? "", name: name ?? "", price: price ?? 0, priceFormatted: priceFormatted, currency: currency,
            oldPrice: oldPrice, oldPriceFormatted: oldPriceFormatted,
            discount: discount, discountFormatted: discountFormatted, discountPercent: discountPercent,
            picture: picture, imageUrl: imageUrl, brand: brand,
            url: url, deeplink: deeplinkIos
        ), actionText: actionText)
    }
}

extension ProductInfo {
    /// Товар `products/get` → данные карточки кита.
    func toCardProduct(actionText: String? = nil) -> PersonalizationProduct {
        ProductMapper.card(ProductMapper.Fields(
            id: id, name: name, price: price, priceFormatted: priceFormatted, currency: currency,
            oldPrice: oldPrice, oldPriceFormatted: oldPriceFormatted,
            discount: discount, discountFormatted: discountFormatted, discountPercent: discountPercent,
            picture: resizedImageUrl, imageUrl: imageUrl, brand: brand,
            url: url, deeplink: deeplinkIos
        ), actionText: actionText)
    }
}
