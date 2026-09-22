import UIKit

/// Категория, на которую можно перейти из поиска: из подсказок instant-поиска (есть id)
/// или из популярных категорий пустого запроса (только имя и ссылка).
@_spi(PersonalizationUI) public struct PersonalizationSearchCategory {
    public let id: String?
    public let name: String
    public let url: String?
}

/// Колбэки SDK приходят с фоновой очереди — виджеты перекладывают их на главную.
enum MainThread {
    static func run(_ block: @escaping () -> Void) {
        if Thread.isMainThread { block() } else { DispatchQueue.main.async(execute: block) }
    }
}

/// Недавние запросы пользователя — локальная история виджета поиска, по магазину.
///
/// Сервер тоже помнит последние запросы (`last_queries` в `search/blank`), но не умеет
/// забывать по одному, а в макете у каждого тега крестик и есть «Clear». Поэтому история
/// живёт в UserDefaults под ключом с id магазина.
final class RecentSearches {
    private let key: String
    private let limit: Int
    private let defaults = UserDefaults.standard

    init(shopKey: String, limit: Int) {
        key = "personalization.ui.recentSearches.\(shopKey)"
        self.limit = limit
    }

    func load() -> [String] {
        defaults.stringArray(forKey: key) ?? []
    }

    /// Кладёт `query` в начало, убирая дубль, и режет по лимиту.
    @discardableResult
    func add(_ query: String) -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return load() }
        let next = [trimmed] + load().filter { $0.caseInsensitiveCompare(trimmed) != .orderedSame }
        return save(Array(next.prefix(limit)))
    }

    @discardableResult
    func remove(_ query: String) -> [String] {
        save(load().filter { $0 != query })
    }

    @discardableResult
    func clear() -> [String] {
        save([])
    }

    private func save(_ items: [String]) -> [String] {
        defaults.set(items, forKey: key)
        return items
    }
}

private var searchImageLoadKey: UInt8 = 0

/// Загрузчик картинок по умолчанию: URLSession с кэшем в памяти. Картинка ставится,
/// только если `imageView` всё ещё ждёт этот же URL — ячейки переиспользуются.
final class SearchImages {
    static let shared = SearchImages()

    private let cache = NSCache<NSString, UIImage>()

    /// Чего ждёт конкретный `imageView`. Живёт на самом view, а не в общем словаре:
    /// уходит вместе с ним и снимает недокачанную загрузку.
    private final class Load {
        var url: String?
        var task: URLSessionDataTask?

        deinit { task?.cancel() }
    }

    private func state(of imageView: UIImageView) -> Load {
        if let load = objc_getAssociatedObject(imageView, &searchImageLoadKey) as? Load { return load }
        let load = Load()
        objc_setAssociatedObject(imageView, &searchImageLoadKey, load, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return load
    }

    func load(_ imageView: UIImageView, url: String?) {
        let load = state(of: imageView)
        // Прошлая загрузка этому view больше не нужна.
        load.task?.cancel()
        load.task = nil
        load.url = url
        guard let url, !url.isEmpty, let link = URL(string: url) else {
            imageView.image = nil
            return
        }
        if let cached = cache.object(forKey: url as NSString) {
            imageView.image = cached
            return
        }
        imageView.image = nil
        // Замыкание не держит `load`: иначе он не ушёл бы вместе с view до конца загрузки.
        let task = URLSession.shared.dataTask(with: link) { [weak self, weak imageView] data, _, _ in
            guard let self, let data, let image = UIImage(data: data) else { return }
            self.cache.setObject(image, forKey: url as NSString)
            DispatchQueue.main.async {
                guard let imageView, self.state(of: imageView).url == url else { return }
                imageView.image = image
            }
        }
        load.task = task
        task.resume()
    }
}

extension Product {
    /// Товар ответа поиска → данные карточки кита. Строки берутся уже отформатированными
    /// сервером (`price_formatted`, `oldprice_formatted`); картинка — `picture`
    /// (уменьшенная копия), иначе оригинал.
    func toCardProduct(actionText: String?) -> PersonalizationProduct {
        let hasOldPrice = oldPrice > price && !oldPriceFormatted.isEmpty
        let discountText = hasOldPrice && discount > 0 ? "-\(discount)%" : nil
        return PersonalizationProduct(
            id: id,
            name: name,
            price: priceFormatted.isEmpty ? "\(price) \(currency)" : priceFormatted,
            imageUrl: resizedImageUrl.isEmpty ? (imageUrl.isEmpty ? nil : imageUrl) : resizedImageUrl,
            brand: brand.isEmpty ? nil : brand,
            oldPrice: hasOldPrice ? oldPriceFormatted : nil,
            discount: discountText,
            actionText: actionText
        )
    }
}
