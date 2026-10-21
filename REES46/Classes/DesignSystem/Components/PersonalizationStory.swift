import UIKit

/// Сторис для просмотрщика кита: имя, аватар и слайды.
///
/// Данные — от хоста или от виджета `PersonalizationStories`, который собирает их из ответа
/// `stories/{code}`. Строки уже отформатированы сервером, картинки компоненты не грузят сами —
/// загрузчик приходит от хоста (у виджета есть встроенный).
@_spi(PersonalizationUI) public struct PersonalizationStory {
    public let id: String
    public let name: String
    public let avatarUrl: String?
    /// Закреплена: кольцо Semantic/Warning и метка «в избранном» — и после просмотра тоже.
    public let pinned: Bool
    /// Просмотрена по данным сервера.
    public let viewed: Bool
    /// С какого слайда открывать нетронутую сторис.
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
/// `image` и `video` — медиа-слайды: фото или ролик вписан в экран целиком, поля вокруг —
/// `backgroundColor` (без него чёрные); поверх — текстовые блоки, кнопки и товары; они всегда
/// в тёмной теме кита. `content` — слайд без медиа (в API тип `""`): с товаром это карточка
/// товара (Card/Story View = Product / Promo / Discount) на Background/Card в теме приложения.
@_spi(PersonalizationUI) public struct PersonalizationStorySlide {

    public enum Kind {
        case image, video, content
    }

    /// Медиа слайда: что вписывать в экран.
    public enum Media: Equatable {
        case image(String)
        case video(String)
    }

    /// Кнопка слайда: в ките всегда Primary LG, стили админки не применяются.
    public struct Button {
        public let title: String
        /// Своя ссылка кнопки для iOS: `link_ios`, иначе `link`.
        public let link: String?
        /// Элемент ответа: его получает `StoriesCommunicationProtocol`, как у старых сторис.
        public let element: StoriesElement?

        public init(title: String, link: String? = nil, element: StoriesElement? = nil) {
            self.title = title
            self.link = link
            self.element = element
        }
    }

    /// Товар: элемент `product` слайда или карточка карусели `products`.
    public struct Offer {

        /// Откуда товар — для делегата те же типы, что у старых сторис.
        public enum Source {
            /// Элемент `product` слайда; сам товар — его `product` (`StoriesPromoCodeElement`).
            case product(StoriesElement)
            /// Карточка карусели `products`.
            case carousel(StoriesProduct)
        }

        public let id: String
        public let brand: String?
        public let name: String
        public let imageUrl: String?
        /// Цена, отформатированная сервером.
        public let price: String
        /// Старая цена — только если она численно больше текущей.
        public let oldPrice: String?
        /// Скидка в процентах, дробная как есть (12.5); 0 — без скидки.
        public let discountPercent: Double
        public let promoCode: String?
        /// Цена с промокодом, отформатированная сервером.
        public let priceWithPromoCode: String?
        /// Подпись над промокодом из админки (`title` элемента); `nil` — текст хоста.
        public let promoCaption: String?
        /// Ссылка на товар: `deeplink_ios`, иначе `url`.
        public let link: String?
        public let source: Source?

        public init(
            id: String,
            brand: String? = nil,
            name: String,
            imageUrl: String? = nil,
            price: String,
            oldPrice: String? = nil,
            discountPercent: Double = 0,
            promoCode: String? = nil,
            priceWithPromoCode: String? = nil,
            promoCaption: String? = nil,
            link: String? = nil,
            source: Source? = nil
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
            self.promoCaption = promoCaption
            self.link = link
            self.source = source
        }

        private var hasPromoCode: Bool {
            !(promoCode ?? "").isEmpty
        }

        /// Вид блока цены: промокод → `promoCode`, иначе скидка больше нуля → `discount`
        /// («N%», дробная остаётся дробной), иначе `price`.
        public var priceKind: PersonalizationStoryPrice.Kind {
            if let promoCode, hasPromoCode { return .promoCode(promoCode) }
            if discountPercent > 0 { return .discount(Self.percentText(discountPercent)) }
            return .price
        }

        /// Крупная цена: с промокодом — цена с промокодом, если сервер её прислал.
        public var displayedPrice: String {
            if hasPromoCode, let priceWithPromoCode, !priceWithPromoCode.isEmpty {
                return priceWithPromoCode
            }
            return price
        }

        /// Зачёркнутая цена. Старая цена, если она есть; с промокодом без старой цены —
        /// обычная цена, когда она выше цены с промокодом (F10: меньшую не зачёркиваем).
        /// Без чисел в строках решает их неравенство.
        public var crossedOutPrice: String? {
            if let oldPrice { return oldPrice }
            guard hasPromoCode, displayedPrice != price else { return nil }
            if let regular = Self.amount(price), let promo = Self.amount(displayedPrice) {
                return regular > promo ? price : nil
            }
            return price
        }

        /// Число из отформатированной цены: «1 190 900 ₽» → 1190900, «12,99 €» → 12.99.
        static func amount(_ text: String) -> Double? {
            var digits = text.filter { $0.isNumber || $0 == "," || $0 == "." }
            guard !digits.isEmpty else { return nil }
            // Последний разделитель с 1–2 цифрами после него — дробная часть, остальные — группы.
            if let last = digits.lastIndex(where: { $0 == "," || $0 == "." }) {
                let fraction = digits[digits.index(after: last)...]
                let whole = digits[..<last].filter(\.isNumber)
                digits = (1...2).contains(fraction.count) ? whole + "." + fraction : whole + fraction
            }
            return Double(digits)
        }

        /// Тот же товар с промокодом текстового блока слайда, если своего кода у товара нет (H2).
        /// Цена с промокодом относится только к своему коду товара, поэтому крупно остаётся
        /// обычная цена, а зачёркнута лишь старая — она уже выше обычной (H3). Промокод сильнее
        /// скидки, как и у своего кода.
        func withTextBlockPromoCode(_ code: String?) -> Offer {
            guard !hasPromoCode, let code, !code.isEmpty else { return self }
            return Offer(
                id: id,
                brand: brand,
                name: name,
                imageUrl: imageUrl,
                price: price,
                oldPrice: oldPrice,
                discountPercent: discountPercent,
                promoCode: code,
                priceWithPromoCode: nil,
                promoCaption: promoCaption,
                link: link,
                source: source
            )
        }

        /// Процент без лишних нулей: 10 → «10%», 12.5 → «12.5%».
        public static func percentText(_ value: Double) -> String {
            let formatter = NumberFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 2
            formatter.usesGroupingSeparator = false
            return (formatter.string(from: NSNumber(value: value)) ?? String(value)) + "%"
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
                discount: oldPrice != nil && discountPercent > 0 ? "-" + Self.percentText(discountPercent) : nil
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
        /// Промокод блока: нажатие копирует его.
        public let promoCode: String?

        public init(
            text: String,
            style: PersonalizationStoryTextBlock.Style = .medium,
            fontFamily: PersonalizationStoryTextBlock.FontFamily = .default,
            bold: Bool = false,
            italic: Bool = false,
            alignment: NSTextAlignment = .natural,
            textColor: UIColor? = nil,
            fill: UIColor? = nil,
            yOffset: CGFloat = 0,
            promoCode: String? = nil
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
            self.promoCode = promoCode
        }

        /// Пустой или из одних пробелов блок не рисуется.
        public var isBlank: Bool {
            text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    public let id: String
    public let kind: Kind
    /// Картинка или видео фона.
    public let background: String?
    /// Цвет полей вокруг вписанного медиа. Слайд без медиа его не использует.
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

    /// Длительность слайда, когда API её не прислал или прислал ноль — одна на всех платформах.
    public static let defaultDuration: TimeInterval = 10

    /// Медиа слайда. Видео — у слайда `video` с адресом; картинка — у любого другого слайда
    /// с картинкой фона. Без адреса медиа нет.
    public var media: Media? {
        guard let url = background?.trimmingCharacters(in: .whitespacesAndNewlines), !url.isEmpty else { return nil }
        return kind == .video ? .video(url) : .image(url)
    }

    /// Медиа-слайд: фото или видео, вписанные в экран.
    public var isMedia: Bool {
        media != nil
    }

    /// Текстовые блоки, которые рисуются: непустые и не на слайде с товаром — у него
    /// карточка товара вместо текста.
    public var visibleTextBlocks: [TextBlock] {
        offer == nil ? textBlocks.filter { !$0.isBlank } : []
    }

    /// Промокод текстовых блоков слайда: первый непустой код, кроме строки «null» (H2).
    /// На товарном слайде блоки не рисуются, и код уходит в блок цены карточки.
    public var textBlockPromoCode: String? {
        textBlocks.lazy
            .compactMap { $0.promoCode?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty && $0 != "null" }
    }

    /// Товар для карточки слайда: свой промокод товара, без него — промокод текстового блока
    /// того же слайда (H2, H3).
    public var cardOffer: Offer? {
        offer?.withTextBlockPromoCode(textBlockPromoCode)
    }

    /// Затемнение сверху и снизу: 50% — у голого медиа (без товара и текстов), иначе 30%.
    public var scrimStrength: CGFloat {
        isMedia && offer == nil && visibleTextBlocks.isEmpty ? 0.5 : 0.3
    }

    /// Цвет полей вокруг вписанного медиа: `background_color` слайда, без него чёрный.
    public var letterboxColor: UIColor {
        backgroundColor ?? .black
    }

    /// Тема слайда: медиа — тёмная тема кита (светлая шапка и текст поверх фото),
    /// остальные — тема приложения на Background/Card.
    @available(iOS 12.0, *)
    public var interfaceStyle: UIUserInterfaceStyle {
        isMedia ? .dark : .unspecified
    }

    /// Ссылка кнопки товарного слайда: своя, без неё — ссылка товара.
    public func link(of button: Button) -> String? {
        button.link ?? offer?.link
    }
}
