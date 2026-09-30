import UIKit

// Сборка моделей кита из ответа `getStories`. Разбор JSON остаётся за SDK (`StoryContent`,
// общий со старыми сторис) — здесь только перекладка в `PersonalizationStory`.

extension PersonalizationStory {

    /// Сторис блока. Сторис без слайдов показывать нечем — они отбрасываются.
    static func list(from content: StoryContent) -> [PersonalizationStory] {
        content.stories.map { PersonalizationStory(story: $0) }.filter { !$0.slides.isEmpty }
    }

    init(story: Story) {
        self.init(
            id: story.id,
            name: story.name,
            avatarUrl: story.avatar.isEmpty ? nil : story.avatar,
            pinned: story.pinned,
            viewed: story.viewed,
            startPosition: story.startPosition,
            slides: story.slides.map { PersonalizationStorySlide(slide: $0) }
        )
    }
}

extension PersonalizationStorySlide {

    init(slide: Slide) {
        let elements = slide.elements
        self.init(
            id: slide.id,
            kind: Self.kind(of: slide.type),
            background: slide.background.nonEmpty,
            backgroundColor: PersonalizationStoryColors.parse(slide.backgroundColor),
            preview: slide.preview?.nonEmpty,
            duration: TimeInterval(slide.duration),
            buttons: elements.filter { $0.type == .button }.compactMap { Button(element: $0) },
            offer: elements.first { $0.type == .product }?.product.flatMap { Offer(item: $0) },
            products: elements.first { $0.type == .products }.flatMap { Products(element: $0) },
            textBlocks: elements.filter { $0.type == .textBlock }.compactMap { TextBlock(element: $0) }
        )
    }

    /// Тип слайда API: `image`, `video`, всё прочее (`""`) — слайд без медиа.
    static func kind(of type: SlideType) -> Kind {
        switch type {
        case .image: return .image
        case .video: return .video
        case .unknown: return .content
        }
    }
}

extension PersonalizationStorySlide.Button {

    /// Кнопка без подписи не рисуется.
    init?(element: StoriesElement) {
        guard let title = element.title?.nonEmpty else { return nil }
        self.init(title: title, link: element.linkIos?.nonEmpty ?? element.link?.nonEmpty)
    }
}

extension PersonalizationStorySlide.Offer {

    /// Товар элемента `product`. Без названия товара нет.
    init?(item: StoriesPromoCodeElement) {
        guard !item.name.isEmpty else { return nil }
        let resized = item.image_url_resized?.image_url_resized520.nonEmpty
        self.init(
            id: item.id,
            brand: item.brand.nonEmpty,
            name: item.name,
            imageUrl: resized ?? item.image_url.nonEmpty ?? item.picture.nonEmpty,
            price: item.price_formatted.nonEmpty ?? "\(item.price) \(item.currency)",
            oldPrice: item.oldprice > item.price ? item.oldprice_formatted.nonEmpty : nil,
            discountPercent: item.discount_percent,
            promoCode: item.promocode.nonEmpty,
            priceWithPromoCode: item.price_with_promocode_formatted.nonEmpty,
            link: item.deeplinkIos.nonEmpty ?? item.url.nonEmpty
        )
    }

    /// Товар карусели `products`. Своего id в ответе нет — им служит ссылка;
    /// процент скидки считается по ценам.
    init?(carousel item: StoriesProduct, index: Int) {
        guard !item.name.isEmpty else { return nil }
        let old = item.oldprice ?? 0
        let hasOldPrice = old > item.price && !item.oldprice_formatted.isEmpty
        let percent = hasOldPrice ? Int((Double(old - item.price) / Double(old) * 100).rounded()) : 0
        self.init(
            id: item.url.nonEmpty ?? String(index),
            name: item.name,
            imageUrl: item.picture.nonEmpty,
            price: item.price_formatted.nonEmpty ?? "\(item.price) \(item.currency)",
            oldPrice: hasOldPrice ? item.oldprice_formatted : nil,
            discountPercent: percent,
            link: item.deeplinkIos.nonEmpty ?? item.url.nonEmpty
        )
    }
}

extension PersonalizationStorySlide.Products {

    init?(element: StoriesElement) {
        let items = (element.products ?? []).enumerated().compactMap {
            PersonalizationStorySlide.Offer(carousel: $0.element, index: $0.offset)
        }
        guard !items.isEmpty else { return nil }
        self.init(
            showLabel: element.labels?.showCarousel.nonEmpty,
            hideLabel: element.labels?.hideCarousel.nonEmpty,
            items: items
        )
    }
}

extension PersonalizationStorySlide.TextBlock {

    /// Кегль по умолчанию — Small; интерлиньяж в админке — множитель кегля.
    init?(element: StoriesElement) {
        guard let text = element.textInput?.nonEmpty else { return nil }
        let size = CGFloat(element.fontSize ?? Double(PersonalizationStoryTextBlock.Style.small.size))
        let spacing = CGFloat(element.textLineSpacing ?? 0)
        let multiple = spacing > 0 ? spacing : 1.2
        self.init(
            text: text,
            style: PersonalizationStoryTextBlock.Style(size: size, lineHeight: (size * multiple).rounded()),
            fontFamily: Self.family(element.fontType),
            bold: element.textBold ?? false,
            italic: element.textItalic ?? false,
            alignment: Self.alignment(element.textAlignment),
            textColor: PersonalizationStoryColors.parse(element.textColor),
            fill: Self.fill(color: element.textBackgroundColor, opacity: element.textBackgroundColorOpacity),
            yOffset: CGFloat(element.yOffset ?? 0)
        )
    }

    /// Заливка блока: цвет с прозрачностью из админки. Без цвета заливки нет,
    /// без прозрачности — непрозрачная.
    static func fill(color: String?, opacity: String?) -> UIColor? {
        guard let base = PersonalizationStoryColors.parse(color) else { return nil }
        return base.withAlphaComponent(PersonalizationStoryColors.opacity(opacity) ?? 1)
    }

    private static func family(_ type: FontType?) -> PersonalizationStoryTextBlock.FontFamily {
        switch type {
        case .monospaced: return .monospaced
        case .serif: return .serif
        case .sansSerif: return .sansSerif
        case .unknown, .none: return .default
        }
    }

    private static func alignment(_ value: TextAlignment?) -> NSTextAlignment {
        switch value {
        case .left: return .left
        case .right: return .right
        case .center: return .center
        case .none: return .natural
        }
    }
}

private extension String {
    /// Пустая строка из ответа — то же, что её отсутствие.
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

/// Просмотренные слайды сторис — общее хранилище SDK по магазину (`localState`), то же,
/// что у старых сторис: кольца обеих лент сходятся.
struct StoriesSeenState {
    let sdk: PersonalizationSDK?

    func seen(_ story: PersonalizationStory) -> Set<String> {
        let ids = Set(story.slides.map(\.id))
        return Set(sdk?.localState?.viewedSlides(storyId: story.id) ?? []).intersection(ids)
    }

    func markSeen(_ slide: PersonalizationStorySlide, of story: PersonalizationStory) {
        guard let state = sdk?.localState else { return }
        var ids = state.viewedSlides(storyId: story.id)
        guard !ids.contains(slide.id) else { return }
        ids.append(slide.id)
        state.setViewedSlides(ids, storyId: story.id)
    }

    /// Превью ленты. Закреплённая остаётся закреплённой и после просмотра — кольцо
    /// Semantic/Warning и звезда, как на остальных платформах и у старых сторис;
    /// досмотренную закреплённую сегменты не осветляют. Незакреплённая просмотренная
    /// (сервером или все слайды локально) — серая; начатая — с осветлёнными сегментами.
    func barItem(_ story: PersonalizationStory) -> PersonalizationStoriesBar.Item {
        let seenCount = seen(story).count
        let viewed = story.viewed || seenCount >= story.slides.count
        let state: PersonalizationStoryCover.State = story.pinned ? .pinned : (viewed ? .viewed : .default)
        return PersonalizationStoriesBar.Item(
            id: story.id,
            title: story.name,
            imageUrl: story.avatarUrl,
            state: state,
            segments: story.slides.count,
            seen: viewed ? 0 : seenCount
        )
    }

    /// Откуда открыть сторис: начатую — с первого непросмотренного слайда, как старые сторис;
    /// нетронутую или досмотренную — с `startPosition`.
    func startSlide(_ story: PersonalizationStory) -> Int {
        let seenIds = seen(story)
        if !seenIds.isEmpty, seenIds.count < story.slides.count,
           let first = story.slides.firstIndex(where: { !seenIds.contains($0.id) }) {
            return first
        }
        return story.startPosition
    }
}
