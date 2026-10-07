import UIKit

// Данные Stories V2: блок `stories/{code}` разбирается здесь, прямо из JSON. Модели старых
// сторис (`StoryContent` → `Slide`) при создании сами качают все картинки и ролики блока,
// поэтому V2 их не строит — иначе каждый файл качался бы дважды. Типы элементов старых сторис
// (`StoriesElement`, `StoriesProduct`, `StoriesPromoCodeElement`) побочных эффектов не имеют —
// они собираются из тех же словарей и уходят делегату, как у старых сторис.

/// Значения JSON ответа: числа и строки сервер присылает вперемешку.
enum StoriesJSON {

    /// Непустая строка без пробелов по краям; число — его запись.
    static func string(_ value: Any?) -> String? {
        let raw: String?
        switch value {
        case let text as String: raw = text
        case let number as NSNumber where !(number === kCFBooleanTrue || number === kCFBooleanFalse): raw = number.stringValue
        default: raw = nil
        }
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }

    /// Число с дробной частью: из числа или строки (`"19990.5"`, `"12,5"`), никогда не обрезается до целого.
    static func number(_ value: Any?) -> Double? {
        switch value {
        case let number as NSNumber where !(number === kCFBooleanTrue || number === kCFBooleanFalse):
            return number.doubleValue
        case let text as String:
            let cleaned = text
                .replacingOccurrences(of: ",", with: ".")
                .components(separatedBy: .whitespacesAndNewlines).joined()
            return Double(cleaned)
        default:
            return nil
        }
    }

    static func bool(_ value: Any?) -> Bool? {
        switch value {
        case let flag as Bool: return flag
        case let number as NSNumber: return number.boolValue
        case let text as String: return ["true", "1"].contains(text.lowercased()) ? true : (["false", "0"].contains(text.lowercased()) ? false : nil)
        default: return nil
        }
    }

    static func object(_ value: Any?) -> [String: Any]? {
        value as? [String: Any]
    }

    static func objects(_ value: Any?) -> [[String: Any]] {
        value as? [[String: Any]] ?? []
    }
}

extension PersonalizationStory {

    /// Сторис блока. Сторис без слайдов показывать нечем — они отбрасываются. Повтор id тоже:
    /// сервер иногда отдаёт одну сторис дважды; остаётся первая, иначе просмотренность склеивается.
    static func list(json: [String: Any]) -> [PersonalizationStory] {
        var ids = Set<String>()
        return StoriesJSON.objects(json["stories"])
            .compactMap { PersonalizationStory(json: $0) }
            .filter { !$0.slides.isEmpty && ids.insert($0.id).inserted }
    }

    init?(json: [String: Any]) {
        guard let id = StoriesJSON.string(json["id"]) else { return nil }
        let start = StoriesJSON.number(json["start_position"]).map { Int($0) } ?? 0
        self.init(
            id: id,
            name: StoriesJSON.string(json["name"]) ?? "",
            avatarUrl: StoriesJSON.string(json["avatar"]),
            pinned: StoriesJSON.bool(json["pinned"]) ?? false,
            viewed: StoriesJSON.bool(json["viewed"]) ?? false,
            startPosition: start,
            slides: StoriesJSON.objects(json["slides"]).compactMap { PersonalizationStorySlide(json: $0) }
        )
    }
}

extension PersonalizationStorySlide {

    init?(json: [String: Any]) {
        guard let id = StoriesJSON.string(json["id"]) else { return nil }
        let elements = StoriesJSON.objects(json["elements"])
        func of(_ type: String) -> [[String: Any]] {
            elements.filter { StoriesJSON.string($0["type"]) == type }
        }
        self.init(
            id: id,
            kind: Self.kind(of: StoriesJSON.string(json["type"]) ?? ""),
            background: StoriesJSON.string(json["background"]),
            backgroundColor: PersonalizationStoryColors.parse(StoriesJSON.string(json["background_color"])),
            preview: StoriesJSON.string(json["preview"]),
            duration: StoriesJSON.number(json["duration"]) ?? Self.defaultDuration,
            buttons: of("button").compactMap { Button(json: $0) },
            offer: of("product").lazy.compactMap { Offer(element: $0) }.first,
            products: of("products").lazy.compactMap { Products(json: $0) }.first,
            textBlocks: of("text_block").compactMap { TextBlock(json: $0) }
        )
    }

    /// Тип слайда API: `image`, `video`, всё прочее (`""`) — слайд без медиа.
    static func kind(of type: String) -> Kind {
        switch type {
        case "image": return .image
        case "video": return .video
        default: return .content
        }
    }
}

extension PersonalizationStorySlide.Button {

    /// Кнопка без подписи не рисуется. Ссылка — `link_ios`, иначе `link`.
    init?(json: [String: Any]) {
        guard let title = StoriesJSON.string(json["title"]) else { return nil }
        self.init(
            title: title,
            link: StoriesJSON.string(json["link_ios"]) ?? StoriesJSON.string(json["link"]),
            element: StoriesElement(json: json)
        )
    }
}

extension PersonalizationStorySlide.Offer {

    /// Товар элемента `product`. Без названия товара нет. Подпись промокода — `title` элемента.
    init?(element json: [String: Any]) {
        guard let item = StoriesJSON.object(json["item"]), let name = StoriesJSON.string(item["name"]) else { return nil }
        let resized = StoriesJSON.object(item["image_url_resized"]).flatMap { StoriesJSON.string($0["520"]) }
        self.init(
            id: StoriesJSON.string(item["id"]) ?? "",
            brand: StoriesJSON.string(item["brand"]),
            name: name,
            imageUrl: resized ?? StoriesJSON.string(item["image_url"]) ?? StoriesJSON.string(item["picture"]),
            price: Self.price(item),
            oldPrice: Self.oldPrice(item),
            discountPercent: max(0, StoriesJSON.number(item["discount_percent"]) ?? 0),
            promoCode: StoriesJSON.string(item["promocode"]),
            priceWithPromoCode: StoriesJSON.string(item["price_with_promocode_formatted"]),
            promoCaption: StoriesJSON.string(json["title"]),
            link: StoriesJSON.string(item["deeplink_ios"]) ?? StoriesJSON.string(item["url"]),
            source: .product(StoriesElement(json: json))
        )
    }

    /// Товар карусели `products`. Скидка — `discount_percent`, а без неё считается по ценам.
    init?(carousel item: [String: Any], index: Int) {
        guard let name = StoriesJSON.string(item["name"]) else { return nil }
        let oldPrice = Self.oldPrice(item)
        var percent = StoriesJSON.number(item["discount_percent"]) ?? 0
        if percent <= 0, oldPrice != nil,
           let price = StoriesJSON.number(item["price"]), let old = StoriesJSON.number(item["oldprice"]), old > 0 {
            percent = ((old - price) / old * 100).rounded()
        }
        self.init(
            id: StoriesJSON.string(item["id"]) ?? StoriesJSON.string(item["url"]) ?? String(index),
            brand: StoriesJSON.string(item["brand"]),
            name: name,
            imageUrl: StoriesJSON.string(item["picture"]) ?? StoriesJSON.string(item["image_url"]),
            price: Self.price(item),
            oldPrice: oldPrice,
            discountPercent: max(0, percent),
            link: StoriesJSON.string(item["deeplink_ios"]) ?? StoriesJSON.string(item["url"]),
            source: .carousel(StoriesProduct(json: item))
        )
    }

    /// Цена строкой сервера; без неё — число и валюта.
    private static func price(_ item: [String: Any]) -> String {
        if let formatted = StoriesJSON.string(item["price_formatted"]) { return formatted }
        guard let number = StoriesJSON.string(item["price"]) else { return "" }
        return [number, StoriesJSON.string(item["currency"])].compactMap { $0 }.joined(separator: " ")
    }

    /// Старая цена — только если она численно больше цены; числа сравниваются с дробной частью.
    private static func oldPrice(_ item: [String: Any]) -> String? {
        guard let old = StoriesJSON.number(item["oldprice"]),
              let price = StoriesJSON.number(item["price"]),
              old > price else { return nil }
        return StoriesJSON.string(item["oldprice_formatted"])
    }
}

extension PersonalizationStorySlide.Products {

    init?(json: [String: Any]) {
        let items = StoriesJSON.objects(json["products"]).enumerated().compactMap {
            PersonalizationStorySlide.Offer(carousel: $0.element, index: $0.offset)
        }
        guard !items.isEmpty else { return nil }
        let labels = StoriesJSON.object(json["labels"])
        self.init(
            showLabel: StoriesJSON.string(labels?["show_carousel"]),
            hideLabel: StoriesJSON.string(labels?["hide_carousel"]),
            items: items
        )
    }
}

extension PersonalizationStorySlide.TextBlock {

    /// Пустой блок пропускается. Кегль по умолчанию — Small; интерлиньяж в админке —
    /// множитель кегля, без него — интерлиньяж пресета для этого кегля.
    init?(json: [String: Any]) {
        guard let text = StoriesJSON.string(json["text_input"]) else { return nil }
        let size = CGFloat(StoriesJSON.number(json["font_size"]) ?? Double(PersonalizationStoryTextBlock.Style.small.size))
        let spacing = CGFloat(StoriesJSON.number(json["text_line_spacing"]) ?? 0)
        let lineHeight = spacing > 0
            ? (size * spacing).rounded()
            : PersonalizationStoryTextBlock.Style.presetLineHeight(for: size)
        self.init(
            text: text,
            style: PersonalizationStoryTextBlock.Style(size: size, lineHeight: lineHeight),
            fontFamily: Self.family(StoriesJSON.string(json["font_type"])),
            bold: StoriesJSON.bool(json["text_bold"]) ?? StoriesJSON.bool(json["bold"]) ?? false,
            italic: StoriesJSON.bool(json["italic"]) ?? StoriesJSON.bool(json["text_italic"]) ?? false,
            alignment: Self.alignment(StoriesJSON.string(json["text_align"])),
            textColor: PersonalizationStoryColors.parse(StoriesJSON.string(json["text_color"])),
            fill: Self.fill(
                color: StoriesJSON.string(json["text_background_color"]),
                opacity: StoriesJSON.string(json["text_background_color_opacity"])
            ),
            yOffset: CGFloat(StoriesJSON.number(json["y_offset"]) ?? 0),
            promoCode: StoriesJSON.string(json["promocode"])
        )
    }

    /// Заливка блока: цвет с прозрачностью из админки. Без цвета заливки нет,
    /// без прозрачности — непрозрачная.
    static func fill(color: String?, opacity: String?) -> UIColor? {
        guard let base = PersonalizationStoryColors.parse(color) else { return nil }
        return base.withAlphaComponent(PersonalizationStoryColors.opacity(opacity) ?? 1)
    }

    private static func family(_ type: String?) -> PersonalizationStoryTextBlock.FontFamily {
        switch type {
        case "monospaced": return .monospaced
        case "serif": return .serif
        case "sans-serif": return .sansSerif
        default: return .default
        }
    }

    /// `left`/`start`, `center`, `right`/`end`; `start` и `end` — по направлению письма.
    static func alignment(_ value: String?) -> NSTextAlignment {
        let rightToLeft = UIView.userInterfaceLayoutDirection(for: .unspecified) == .rightToLeft
        switch value?.lowercased() {
        case "left": return .left
        case "right": return .right
        case "center": return .center
        case "end": return rightToLeft ? .left : .right
        default: return .natural
        }
    }
}

// MARK: - Просмотренность

/// Просмотренные слайды сторис — общее хранилище SDK по магазину (`localState`), то же,
/// что у старых сторис: кольца обеих лент сходятся. Слайд просмотрен, как только стал
/// текущим на остановившейся странице.
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

    func barItem(_ story: PersonalizationStory) -> PersonalizationStoriesBar.Item {
        Self.barItem(story, seen: seen(story))
    }

    func startSlide(_ story: PersonalizationStory) -> Int {
        Self.startSlide(story, seen: seen(story))
    }

    /// Сторис просмотрена: так сказал сервер или просмотрены все её слайды.
    static func isViewed(_ story: PersonalizationStory, seen: Set<String>) -> Bool {
        story.viewed || (!story.slides.isEmpty && story.slides.allSatisfy { seen.contains($0.id) })
    }

    /// Превью ленты. Просмотренная незакреплённая — сплошное кольцо Neutral Subtle без сегментов.
    /// Закреплённая всегда остаётся закреплённой (кольцо Semantic/Warning и звезда), досмотренная
    /// закреплённая — тоже сплошное кольцо. Начатая — сегменты по слайдам, просмотренные
    /// подсвечены по своему номеру, а не по счёту.
    static func barItem(_ story: PersonalizationStory, seen: Set<String>) -> PersonalizationStoriesBar.Item {
        let viewed = isViewed(story, seen: seen)
        let state: PersonalizationStoryCover.State = story.pinned ? .pinned : (viewed ? .viewed : .default)
        let lit = Set(story.slides.indices.filter { seen.contains(story.slides[$0].id) })
        return PersonalizationStoriesBar.Item(
            id: story.id,
            title: story.name,
            imageUrl: story.avatarUrl,
            state: state,
            segments: viewed ? 0 : story.slides.count,
            seen: viewed ? [] : lit
        )
    }

    /// С какого слайда открыть сторис: просмотренную — с начала; начатую — с первого
    /// непросмотренного по порядку; нетронутую — с `startPosition` сервера в пределах сторис.
    static func startSlide(_ story: PersonalizationStory, seen: Set<String>) -> Int {
        guard !story.slides.isEmpty else { return 0 }
        if isViewed(story, seen: seen) { return 0 }
        if let first = story.slides.firstIndex(where: { !seen.contains($0.id) }), !seen.isEmpty {
            return first
        }
        return min(max(story.startPosition, 0), story.slides.count - 1)
    }
}

// MARK: - Загрузка блока

/// Блок сторис с сервера: тот же запрос, что у старых сторис (`stories/{code}`), но без их
/// разбора с загрузкой медиа и без смены сессии SDK. Ответ приходит на главную очередь.
enum StoriesBlockLoader {

    static func load(
        sdk: PersonalizationSDK,
        code: String,
        completion: @escaping (Result<[PersonalizationStory], SdkError>) -> Void
    ) {
        sdk.sessionQueue.addOperation {
            let params = [SdkConstants.shopId: sdk.shopId, SdkConstants.did: sdk.deviceId]
            sdk.getRequest(path: "stories/\(code)", params: params, false) { result in
                let mapped = result.map { PersonalizationStory.list(json: $0) }
                MainThread.run { completion(mapped) }
            }
        }
    }
}

// MARK: - Сессия просмотра

/// Просмотрщик на данных SDK: трекинг, просмотренность, делегат и ссылки — общие у виджета
/// и у `PersonalizationStories.show`. Просмотрщик держит сессию, пока открыт.
///
/// Трекинг (`track/stories`) — всегда с кодом своего блока и своим инстансом SDK: `view`,
/// когда слайд стал текущим, `click` — на кнопку, товар (кнопка товарного слайда, карусель)
/// и копирование промокода. Id не положительным целым (динамические слайды вида `39_0`)
/// не трекаются. Источник `stories` для атрибуции ставит сам трекинг SDK.
///
/// Ссылки — как у старых сторис: делегат узнаёт о нажатии и решает в
/// `shouldOpenLinkBySdk(url:)`, открыть ли ссылку SDK; просмотрщик закрывается до этого
/// в любом случае. `receiveIosLink` не зовётся, как и у старых сторис.
final class StoriesSession {

    let sdk: PersonalizationSDK?
    let code: String
    weak var delegate: StoriesCommunicationProtocol?
    var texts = PersonalizationStoriesTexts()
    var imageLoader: ((UIImageView, String) -> Void)?
    /// Слайд просмотрен — лента перерисовывает кольца.
    var onSeen: (() -> Void)?
    /// Открытие ссылки системой; подменяется в тестах.
    var openURL: (URL) -> Void = { UIApplication.shared.open($0) }

    init(sdk: PersonalizationSDK?, code: String) {
        self.sdk = sdk
        self.code = code
    }

    var seenState: StoriesSeenState {
        StoriesSeenState(sdk: sdk)
    }

    /// Просмотрщик на сторис блока, связанный с этой сессией.
    func makeViewer(stories: [PersonalizationStory], startIndex: Int) -> PersonalizationStoriesViewController {
        let viewer = PersonalizationStoriesViewController(stories: stories, startIndex: startIndex)
        viewer.texts = texts
        viewer.imageLoader = imageLoader
        let seen = seenState
        viewer.startSlide = { seen.startSlide($0) }
        viewer.onSlideView = { [self] story, slide in slideShown(story, slide) }
        viewer.onButtonTap = { [self, weak viewer] story, slide, button in buttonTapped(story, slide, button, in: viewer) }
        viewer.onProductTap = { [self, weak viewer] story, slide, offer in productTapped(story, slide, offer, in: viewer) }
        viewer.onPromoCopied = { [self] story, slide, code in promoCopied(story, slide, code) }
        return viewer
    }

    /// Трекаются только положительные целые id.
    static func isTrackable(_ id: String) -> Bool {
        Int(id).map { $0 > 0 } ?? false
    }

    func slideShown(_ story: PersonalizationStory, _ slide: PersonalizationStorySlide) {
        if Self.isTrackable(story.id), Self.isTrackable(slide.id) {
            sdk?.tracking.storyView(storyId: story.id, slideId: slide.id, code: code)
        }
        seenState.markSeen(slide, of: story)
        onSeen?()
    }

    private func trackClick(_ story: PersonalizationStory, _ slide: PersonalizationStorySlide) {
        guard Self.isTrackable(story.id), Self.isTrackable(slide.id) else { return }
        sdk?.tracking.storyClick(storyId: story.id, slideId: slide.id, code: code)
    }

    /// Кнопка слайда: ссылка кнопки, у товарного слайда без неё — ссылка товара.
    func buttonTapped(
        _ story: PersonalizationStory,
        _ slide: PersonalizationStorySlide,
        _ button: PersonalizationStorySlide.Button,
        in viewer: PersonalizationStoriesViewController?
    ) {
        trackClick(story, slide)
        let element = button.element ?? slide.offer.flatMap { offer -> StoriesElement? in
            if case .product(let element)? = offer.source { return element }
            return nil
        }
        // Замыкания разовые и держат сессию сами: после `show` её больше никто не держит.
        leave(viewer, link: slide.link(of: button)) { [self] in
            if let element { delegate?.receiveSelectedProductData(products: element) }
        }
    }

    /// Товар: кнопка товарного слайда без своих кнопок, карточка карусели. Картинка товара
    /// не нажимается.
    func productTapped(
        _ story: PersonalizationStory,
        _ slide: PersonalizationStorySlide,
        _ offer: PersonalizationStorySlide.Offer,
        in viewer: PersonalizationStoriesViewController?
    ) {
        trackClick(story, slide)
        leave(viewer, link: offer.link) { [self] in
            switch offer.source {
            case .product(let element)?: delegate?.receiveSelectedProductData(products: element)
            case .carousel(let product)?: delegate?.receiveSelectedCarouselProductData(products: product)
            case nil: break
            }
        }
    }

    /// Промокод скопирован — из цены товара или из текстового блока.
    func promoCopied(_ story: PersonalizationStory, _ slide: PersonalizationStorySlide, _ code: String) {
        trackClick(story, slide)
        delegate?.receiveSelectedPromocodeProductData(promoCodeSlide: Self.promoElement(code, on: slide))
    }

    /// Промокод для делегата: товар слайда, если код его; иначе — элемент с одним кодом.
    static func promoElement(_ code: String, on slide: PersonalizationStorySlide) -> StoriesPromoCodeElement {
        if let offer = slide.offer, offer.promoCode == code, case .product(let element)? = offer.source, let item = element.product {
            return item
        }
        return StoriesPromoCodeElement(json: ["promocode": code])
    }

    /// Со ссылкой — закрыть просмотрщик, потом сообщить делегату и открыть ссылку, если
    /// он не против; без ссылки — только сообщить.
    private func leave(_ viewer: PersonalizationStoriesViewController?, link: String?, notify: @escaping () -> Void) {
        guard let link else {
            notify()
            return
        }
        let finish = { [self] in
            notify()
            open(link)
        }
        guard let viewer else {
            finish()
            return
        }
        viewer.close(completion: finish)
    }

    func open(_ link: String) {
        guard let url = URL(string: link), delegate?.shouldOpenLinkBySdk(url: link) ?? true else { return }
        openURL(url)
    }
}
