import UIKit

/// Сторис для просмотрщика кита: имя, аватар и слайды.
///
/// Данные — от хоста или от виджета `PersonalizationStories`, который собирает их из ответа
/// `getStories`. Строки уже отформатированы сервером, картинки компоненты не грузят сами —
/// загрузчик приходит от хоста (у виджета есть встроенный).
@_spi(PersonalizationUI) public struct PersonalizationStory {
    public let id: String
    public let name: String
    public let avatarUrl: String?
    /// Закреплена: кольцо Semantic/Warning и метка «в избранном».
    public let pinned: Bool
    /// Просмотрена по данным сервера.
    public let viewed: Bool
    /// С какого слайда открывать.
    public let startPosition: Int
    public let slides: [PersonalizationStorySlide]

    public init(
        id: String,
        name: String,
        avatarUrl: String? = nil,
        pinned: Bool = false,
        viewed: Bool = false,
        startPosition: Int = 0,
        slides: [PersonalizationStorySlide]
    ) {
        self.id = id
        self.name = name
        self.avatarUrl = avatarUrl
        self.pinned = pinned
        self.viewed = viewed
        self.startPosition = startPosition
        self.slides = slides
    }
}

/// Слайд сторис.
///
/// `image` и `video` — медиа-слайды: фон на весь экран, поверх — текстовые блоки, кнопки
/// и товары; они всегда в тёмной теме кита. `content` — слайд без медиа (в API тип `""`):
/// с товаром это карточка товара (Card/Story View = Product / Promo / Discount), в теме
/// приложения.
@_spi(PersonalizationUI) public struct PersonalizationStorySlide {

    public enum Kind {
        case image, video, content
    }

    /// Кнопка слайда: в ките всегда Primary LG, цвета админки не применяются.
    public struct Button {
        public let title: String
        /// Ссылка для iOS: `link_ios`, иначе `link`.
        public let link: String?

        public init(title: String, link: String? = nil) {
            self.title = title
            self.link = link
        }
    }

    /// Товар: элемент `product` слайда или карточка карусели `products`.
    public struct Offer {
        public let id: String
        public let brand: String?
        public let name: String
        public let imageUrl: String?
        /// Цена, отформатированная сервером.
        public let price: String
        /// Старая цена — только если она больше текущей.
        public let oldPrice: String?
        /// Скидка в процентах; 0 — без скидки.
        public let discountPercent: Int
        public let promoCode: String?
        /// Цена с промокодом, отформатированная сервером.
        public let priceWithPromoCode: String?
        /// Ссылка на товар: `deeplink_ios`, иначе `url`.
        public let link: String?

        public init(
            id: String,
            brand: String? = nil,
            name: String,
            imageUrl: String? = nil,
            price: String,
            oldPrice: String? = nil,
            discountPercent: Int = 0,
            promoCode: String? = nil,
            priceWithPromoCode: String? = nil,
            link: String? = nil
        ) {
            self.id = id
            self.brand = brand
            self.name = name
            self.imageUrl = imageUrl
            self.price = price
            self.oldPrice = oldPrice
            self.discountPercent = discountPercent
            self.promoCode = promoCode
            self.priceWithPromoCode = priceWithPromoCode
            self.link = link
        }

        /// Вид блока цены: промокод → `promoCode`, иначе скидка больше нуля → `discount`
        /// («N%»), иначе `price`.
        public var priceKind: PersonalizationStoryPrice.Kind {
            if let promoCode, !promoCode.isEmpty { return .promoCode(promoCode) }
            if discountPercent > 0 { return .discount("\(discountPercent)%") }
            return .price
        }

        /// Цена в блоке: с промокодом — цена с промокодом, если сервер её прислал.
        public var displayedPrice: String {
            if let promoCode, !promoCode.isEmpty, let priceWithPromoCode, !priceWithPromoCode.isEmpty {
                return priceWithPromoCode
            }
            return price
        }

        /// Карточка карусели кита. Скидка бейджем — только при старой цене.
        func cardProduct(id: String) -> PersonalizationProduct {
            PersonalizationProduct(
                id: id,
                name: name,
                price: price,
                imageUrl: imageUrl,
                brand: brand,
                oldPrice: oldPrice,
                discount: oldPrice != nil && discountPercent > 0 ? "-\(discountPercent)%" : nil
            )
        }
    }

    /// Карусель товаров слайда и подписи её переключателя.
    public struct Products {
        /// Подпись свёрнутого переключателя (`labels.show_carousel`).
        public let showLabel: String?
        /// Подпись развёрнутого (`labels.hide_carousel`).
        public let hideLabel: String?
        public let items: [Offer]

        public init(showLabel: String? = nil, hideLabel: String? = nil, items: [Offer]) {
            self.showLabel = showLabel
            self.hideLabel = hideLabel
            self.items = items
        }
    }

    /// Текстовый блок, см. `PersonalizationStoryTextBlock`.
    public struct TextBlock {
        public let text: String
        public let style: PersonalizationStoryTextBlock.Style
        public let fontFamily: PersonalizationStoryTextBlock.FontFamily
        public let bold: Bool
        public let italic: Bool
        public let alignment: NSTextAlignment
        /// `nil` — цвет по умолчанию для вида блока.
        public let textColor: UIColor?
        /// Заливка вместе с прозрачностью; `nil` или прозрачная — без рамки.
        public let fill: UIColor?
        /// Верх блока в процентах высоты слайда.
        public let yOffset: CGFloat

        public init(
            text: String,
            style: PersonalizationStoryTextBlock.Style = .medium,
            fontFamily: PersonalizationStoryTextBlock.FontFamily = .default,
            bold: Bool = false,
            italic: Bool = false,
            alignment: NSTextAlignment = .natural,
            textColor: UIColor? = nil,
            fill: UIColor? = nil,
            yOffset: CGFloat = 0
        ) {
            self.text = text
            self.style = style
            self.fontFamily = fontFamily
            self.bold = bold
            self.italic = italic
            self.alignment = alignment
            self.textColor = textColor
            self.fill = fill
            self.yOffset = yOffset
        }
    }

    public let id: String
    public let kind: Kind
    /// Картинка или видео фона.
    public let background: String?
    /// Цвет под фоном.
    public let backgroundColor: UIColor?
    /// Постер видео.
    public let preview: String?
    /// Длительность показа, секунды. У видео — пока длина ролика неизвестна.
    public let duration: TimeInterval
    public let buttons: [Button]
    public let offer: Offer?
    public let products: Products?
    public let textBlocks: [TextBlock]

    public init(
        id: String,
        kind: Kind,
        background: String? = nil,
        backgroundColor: UIColor? = nil,
        preview: String? = nil,
        duration: TimeInterval = PersonalizationStorySlide.defaultDuration,
        buttons: [Button] = [],
        offer: Offer? = nil,
        products: Products? = nil,
        textBlocks: [TextBlock] = []
    ) {
        self.id = id
        self.kind = kind
        self.background = background
        self.backgroundColor = backgroundColor
        self.preview = preview
        self.duration = duration > 0 ? duration : Self.defaultDuration
        self.buttons = buttons
        self.offer = offer
        self.products = products
        self.textBlocks = textBlocks
    }

    /// Длительность слайда по умолчанию.
    public static let defaultDuration: TimeInterval = 5

    /// Медиа-слайд: картинка или видео на весь экран.
    public var isMedia: Bool {
        kind == .image || kind == .video
    }

    /// Тема слайда. Медиа и слайд с картинкой фона — тёмная тема кита: светлая шапка
    /// и текст поверх фото. Слайд с цветом фона — по яркости цвета. Остальные — тема
    /// приложения (`unspecified`).
    @available(iOS 12.0, *)
    public var interfaceStyle: UIUserInterfaceStyle {
        if isMedia || !(background ?? "").isEmpty { return .dark }
        if let backgroundColor { return PersonalizationStoryColors.isDark(backgroundColor) ? .dark : .light }
        return .unspecified
    }
}
