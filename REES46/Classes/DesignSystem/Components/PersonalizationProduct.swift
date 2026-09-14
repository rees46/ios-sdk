import UIKit

/// Данные товара для карточки и раскладок каталога.
///
/// Строки уже отформатированы: цена с валютой, оценка с запятой, скидка со знаком —
/// форматирование и локализация остаются за интегратором.
/// Изображение по `imageUrl` компонент не грузит: раскладки отдают хосту
/// `UIImageView` через свой `imageLoader`.
public struct PersonalizationProduct {
    public let id: String
    public let name: String
    public let price: String
    public let imageUrl: String?
    public let brand: String?
    public let ratingValue: String?
    public let reviews: Int
    public let oldPrice: String?
    public let discount: String?
    public let actionText: String?

    public init(
        id: String,
        name: String,
        price: String,
        imageUrl: String? = nil,
        brand: String? = nil,
        ratingValue: String? = nil,
        reviews: Int = 0,
        oldPrice: String? = nil,
        discount: String? = nil,
        actionText: String? = nil
    ) {
        self.id = id
        self.name = name
        self.price = price
        self.imageUrl = imageUrl
        self.brand = brand
        self.ratingValue = ratingValue
        self.reviews = reviews
        self.oldPrice = oldPrice
        self.discount = discount
        self.actionText = actionText
    }
}
