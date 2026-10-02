import UIKit
@_spi(PersonalizationUI) import REES46

/// "Stories V2" segment of the UI Kit tab: the kit's stories, one exhibit per component of the
/// design file's Stories page, the fullscreen viewer on sample stories, and the data-bound block
/// of the demo shop (`AppEnvironments.storiesCode`) that opens the same viewer on real data.
///
/// The legacy stories stay in the "Stories" segment and the "Legacy UI" tab, untouched.
/// Sample images ship with the app (`asset://uikit-…`) and load through `DemoImageLoader`.
enum StoriesV2Exhibits {

    static func all() -> [ShowcaseViewController.Exhibit] {
        [
            ("Live — stories block of the demo shop (tap a story to open the viewer)", { LiveStoriesExhibit() }),
            ("Viewer — sample stories: product, promo, discount, text blocks, media with products", {
                ViewerExhibit()
            }),
            ("Stories Bar — sample stories (tap to open the viewer)", { sampleBar() }),
            ("Stories Bar — loading", {
                let bar = PersonalizationStoriesBar()
                bar.contentInsets = barInsets
                bar.isLoading = true
                return bar
            }),
            ("Story Preview — pinned, default, viewed, skeleton", {
                scrollableRow([
                    preview("Pinned", .pinned, image: "pegasus"),
                    preview("Default", .default, image: "headphones"),
                    preview("Viewed", .viewed, image: "backpack"),
                    preview(nil, .skeleton, image: nil)
                ])
            }),
            ("Story Cover — segments: 5 slides, 2 seen (default, pinned, viewed)", {
                scrollableRow([PersonalizationStoryCover.State.default, .pinned, .viewed].map { state in
                    let cover = PersonalizationStoryCover(state: state)
                    cover.segments = 5
                    cover.seen = [0, 2]
                    DemoImageLoader.shared.load(DemoStories.image("jacket"), into: cover.imageView)
                    return cover
                })
            }),
            ("Story Progress — 5 slides, the second at 40%", {
                let progress = PersonalizationStoryProgress(count: 5)
                progress.current = 1
                progress.progress = 0.4
                return padded(progress, background: nil)
            }),
            ("Story Navigation — app theme and on a photo (dark)", {
                column([navigation(dark: false), navigation(dark: true)])
            }),
            ("Story Price — price, discount, promo code (tap to copy), long promo code", {
                column([
                    PersonalizationStoryPrice(price: "1 190 900 ₽", oldPrice: "1 245 000 ₽", kind: .price),
                    PersonalizationStoryPrice(price: "1 190 900 ₽", oldPrice: "1 245 000 ₽", kind: .discount("10%")),
                    PersonalizationStoryPrice(price: "1 190 900 ₽", oldPrice: "1 245 000 ₽", kind: .promoCode("PROMO")),
                    PersonalizationStoryPrice(price: "1 190 900 ₽", kind: .promoCode("YAGODA-MALINA"))
                ])
            }),
            ("Story Timer — merged and separate", {
                // 2d 18h 33m 24s from now, as in the design file.
                let end = Date().addingTimeInterval(((2 * 24 + 18) * 60 + 33) * 60 + 24)
                return column([
                    PersonalizationStoryTimer(endDate: end, view: .merged),
                    PersonalizationStoryTimer(endDate: end, view: .separate)
                ])
            }),
            ("Story Text Block — solid large / medium / small, then transparent (on a photo)", {
                textBlocks()
            }),
            ("Used Products — collapsed and expanded, with the sound button (on a photo)", {
                column([usedProducts(expanded: false), usedProducts(expanded: true)])
            }),
            ("Badge — \"Sale!\" (LG warning, action slides)", {
                row([PersonalizationBadge(text: "Sale!", size: .lg, view: .warning)])
            }),
            ("Icons — speaker, speaker off; the sound button toggles", {
                row([
                    icon(PersonalizationIcons.speaker),
                    icon(PersonalizationIcons.speakerOff),
                    PersonalizationStorySoundButton(isMuted: true)
                ])
            })
        ]
    }

    // MARK: - Exhibits

    /// The bar as a host fills it by hand; a tap opens the viewer on the same sample stories.
    private static func sampleBar() -> UIView {
        let bar = PersonalizationStoriesBar()
        bar.contentInsets = barInsets
        let stories = DemoStories.all
        bar.items = stories.enumerated().map { index, story in
            PersonalizationStoriesBar.Item(
                id: story.id,
                title: story.name,
                imageUrl: story.avatarUrl,
                // A pinned story stays pinned once viewed; only the others turn grey.
                state: story.pinned ? .pinned : (story.viewed ? .viewed : .default),
                segments: story.slides.count,
                seen: index == 1 ? [0] : []
            )
        }
        bar.imageLoader = { view, item in DemoImageLoader.shared.load(item.imageUrl, into: view) }
        bar.onItemTap = { [weak bar] _, index in
            guard let host = bar?.nearestViewController else { return }
            DemoStories.present(from: host, startIndex: index)
        }
        return bar
    }

    private static func preview(_ title: String?, _ state: PersonalizationStoryCover.State, image: String?) -> UIView {
        let preview = PersonalizationStoryPreview(title: title, state: state)
        preview.cover.segments = 4
        if let image {
            DemoImageLoader.shared.load(DemoStories.image(image), into: preview.cover.imageView)
        }
        return preview
    }

    private static func navigation(dark: Bool) -> UIView {
        let navigation = PersonalizationStoryNavigation()
        navigation.progress.count = 5
        navigation.progress.current = 1
        navigation.progress.progress = 0.5
        navigation.onClose = { PersonalizationToast.show("Close") }
        return padded(navigation, background: dark ? DemoStories.image("jacket") : nil)
    }

    private static func textBlocks() -> UIView {
        let info = PersonalizationColor.semanticInfo
        let text = "Open eat dear winding belonging."
        let blocks: [UIView] = [
            PersonalizationStoryTextBlock(text: text, style: .large, fill: info),
            PersonalizationStoryTextBlock(text: text, style: .medium, fill: info),
            PersonalizationStoryTextBlock(text: text + " Though differed stand left.", style: .small, fill: info),
            PersonalizationStoryTextBlock(text: text, style: .large),
            PersonalizationStoryTextBlock(text: text, style: .medium),
            PersonalizationStoryTextBlock(text: text + " Though differed stand left.", style: .small)
        ]
        let stack = UIStackView(arrangedSubviews: blocks)
        stack.axis = .vertical
        stack.spacing = 16
        return padded(stack, background: DemoStories.image("jacket"))
    }

    private static func usedProducts(expanded: Bool) -> UIView {
        let used = PersonalizationStoryUsedProducts()
        used.showText = "Используемые товары"
        used.hideText = "Скрыть товары"
        used.products = DemoStories.carousel.enumerated().map { index, offer in
            PersonalizationProduct(
                id: String(index), name: offer.name, price: offer.price, imageUrl: offer.imageUrl,
                brand: offer.brand, oldPrice: offer.oldPrice,
                discount: offer.discountPercent > 0 ? "-" + PersonalizationStorySlide.Offer.percentText(offer.discountPercent) : nil
            )
        }
        used.imageLoader = { view, product in DemoImageLoader.shared.load(product.imageUrl, into: view) }
        used.onProductTap = { product in PersonalizationToast.show("Product: \(product.name)") }
        used.leadingView = PersonalizationStorySoundButton(isMuted: !expanded)
        used.isExpanded = expanded
        return photoBox(used, image: DemoStories.image("sneakers"), inset: 0)
    }

    // MARK: - Layout helpers

    /// The bar's own 16 would double the showcase's side margins.
    private static let barInsets = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)

    /// The content on a 16-padded box: plain, or on a photo with the kit's dark theme forced,
    /// the way the viewer shows media slides.
    private static func padded(_ content: UIView, background: String?) -> UIView {
        guard let background else {
            content.translatesAutoresizingMaskIntoConstraints = false
            let box = UIView()
            box.addSubview(content)
            NSLayoutConstraint.activate([
                content.topAnchor.constraint(equalTo: box.topAnchor, constant: 8),
                content.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -8),
                content.leadingAnchor.constraint(equalTo: box.leadingAnchor),
                content.trailingAnchor.constraint(equalTo: box.trailingAnchor)
            ])
            return box
        }
        return photoBox(content, image: background, inset: 16)
    }

    private static func photoBox(_ content: UIView, image: String, inset: CGFloat) -> UIView {
        let box = UIView()
        box.backgroundColor = .black
        box.layer.cornerRadius = 12
        box.clipsToBounds = true
        box.overrideUserInterfaceStyle = .dark
        let photo = UIImageView()
        photo.contentMode = .scaleAspectFill
        photo.alpha = 0.6
        DemoImageLoader.shared.load(image, into: photo)
        for view in [photo, content] {
            view.translatesAutoresizingMaskIntoConstraints = false
            box.addSubview(view)
        }
        NSLayoutConstraint.activate([
            photo.topAnchor.constraint(equalTo: box.topAnchor),
            photo.bottomAnchor.constraint(equalTo: box.bottomAnchor),
            photo.leadingAnchor.constraint(equalTo: box.leadingAnchor),
            photo.trailingAnchor.constraint(equalTo: box.trailingAnchor),
            content.topAnchor.constraint(equalTo: box.topAnchor, constant: inset),
            content.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -inset),
            content.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: inset),
            content.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -inset)
        ])
        return box
    }

    private static func row(_ views: [UIView]) -> UIView {
        let stack = UIStackView(arrangedSubviews: views)
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 16
        let spacer = UIView()
        spacer.setContentHuggingPriority(UILayoutPriority(1), for: .horizontal)
        stack.addArrangedSubview(spacer)
        return stack
    }

    private static func scrollableRow(_ views: [UIView]) -> UIView {
        let stack = UIStackView(arrangedSubviews: views)
        stack.axis = .horizontal
        stack.alignment = .top
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            stack.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor),
            scroll.heightAnchor.constraint(equalTo: stack.heightAnchor)
        ])
        return scroll
    }

    private static func column(_ views: [UIView]) -> UIView {
        let stack = UIStackView(arrangedSubviews: views)
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 12
        return stack
    }

    private static func icon(_ image: UIImage?) -> UIView {
        let view = UIImageView(image: image)
        view.tintColor = PersonalizationColor.textPrimary
        view.contentMode = .scaleAspectFit
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: 32),
            view.heightAnchor.constraint(equalToConstant: 32)
        ])
        return view
    }
}

// MARK: - Live block

/// The data-bound widget as a host drops it in: the block code and the shop, callbacks for links
/// and products. Link and product taps only show a toast here — navigation is the host's.
private final class LiveStoriesExhibit: UIStackView {

    private let status = UILabel()

    init() {
        super.init(frame: .zero)
        axis = .vertical
        spacing = 4

        let stories = PersonalizationStories(code: AppEnvironments.storiesCode, shopId: AppEnvironments.shopId)
        stories.bar.contentInsets = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        stories.promoCopiedText = "Code copied to clipboard"
        stories.communicationDelegate = self
        stories.onLoaded = { [weak self] count in self?.status.text = "Stories loaded: \(count)" }
        stories.onError = { [weak self] error in self?.status.text = "Stories failed to load: \(error)" }

        status.text = "Loading block \(AppEnvironments.storiesCode)…"
        status.font = .preferredFont(forTextStyle: .caption1)
        status.textColor = .secondaryLabel
        status.numberOfLines = 0

        addArrangedSubview(stories)
        addArrangedSubview(status)
    }

    required init(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}

/// The same delegate a legacy stories host implements: taps are reported, and links the demo
/// routes itself (`demo://`) are kept from the SDK. Everything else the SDK opens after the
/// viewer is gone.
extension LiveStoriesExhibit: StoriesCommunicationProtocol {
    func receiveIosLink(text: String) {}

    func receiveSelectedProductData(products: StoriesElement) {
        PersonalizationToast.show("Element: \(products.link ?? products.deeplinkIos ?? "no link")")
    }

    func receiveSelectedCarouselProductData(products: StoriesProduct) {
        PersonalizationToast.show("Carousel product: \(products.url)")
    }

    func receiveSelectedPromocodeProductData(promoCodeSlide: StoriesPromoCodeElement) {
        print("[stories v2] promo code copied")
    }

    func shouldOpenLinkBySdk(url: String) -> Bool {
        !url.hasPrefix("demo://")
    }
}

// MARK: - Viewer on sample data

/// Opens the viewer on the sample stories, with the callbacks a host would wire.
private final class ViewerExhibit: UIStackView {

    init() {
        super.init(frame: .zero)
        axis = .vertical
        alignment = .leading
        let open = PersonalizationButton(text: "Open the viewer", size: .md, view: .primary)
        open.addTarget(self, action: #selector(openViewer), for: .touchUpInside)
        addArrangedSubview(open)
    }

    required init(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    @objc private func openViewer() {
        guard let host = nearestViewController else { return }
        DemoStories.present(from: host, startIndex: 0)
    }
}

/// Sample stories covering every slide layout of the design file.
private enum DemoStories {

    static func image(_ seed: String) -> String { "asset://uikit-\(seed)" }

    static func present(from host: UIViewController, startIndex: Int) {
        let viewer = PersonalizationStoriesViewController(stories: all, startIndex: startIndex)
        viewer.imageLoader = { view, url in DemoImageLoader.shared.load(url, into: view) }
        viewer.promoCopiedText = "Code copied to clipboard"
        viewer.onSlideView = { story, slide in print("[stories v2] view \(story.id)/\(slide.id)") }
        viewer.onButtonTap = { [weak viewer] _, _, button in
            viewer?.close { PersonalizationToast.show("Button: \(button.title)") }
        }
        viewer.onProductTap = { [weak viewer] _, _, offer in
            viewer?.close { PersonalizationToast.show("Product: \(offer.name)") }
        }
        viewer.onPromoCopied = { _, _, code in print("[stories v2] promo copied \(code)") }
        host.present(viewer, animated: true)
    }

    static let laptop = PersonalizationStorySlide.Offer(
        id: "laptop",
        brand: "Apple",
        name: "16.2\" Ноутбук Apple Macbook Pro 16 (2021) 3456×2234, Apple M1 Pro 3.2 ГГц, RAM 16 ГБ, LPDDR5, SSD 512 ГБ, серый космос.",
        imageUrl: image("headphones"),
        price: "1 190 900 ₽",
        oldPrice: "1 245 000 ₽"
    )

    static let carousel: [PersonalizationStorySlide.Offer] = [
        .init(id: "1", brand: "Nike", name: "Air Zoom Pegasus 41", imageUrl: image("pegasus"), price: "9 999 ₽", oldPrice: "15 999 ₽", discountPercent: 38),
        .init(id: "2", brand: "Adidas", name: "Court sneakers", imageUrl: image("sneakers"), price: "7 490 ₽"),
        .init(id: "3", brand: "Garmin", name: "GPS running watch", imageUrl: image("watch"), price: "44 900 ₽", oldPrice: "49 900 ₽", discountPercent: 10)
    ]

    static let all: [PersonalizationStory] = [
        PersonalizationStory(id: "product", name: "Product", avatarUrl: image("headphones"), pinned: true, slides: [
            PersonalizationStorySlide(id: "price", kind: .content, offer: laptop),
            PersonalizationStorySlide(id: "promo", kind: .content, offer: offer(laptop, promo: "PROMO")),
            PersonalizationStorySlide(
                id: "discount", kind: .content,
                backgroundColor: UIColor(red: 0, green: 0x80 / 255.0, blue: 0xF0 / 255.0, alpha: 1),
                buttons: [.init(title: "Buy", link: "https://example.com/laptop")],
                offer: offer(laptop, discount: 10)
            )
        ]),
        PersonalizationStory(id: "text", name: "Text blocks", avatarUrl: image("jacket"), slides: [
            PersonalizationStorySlide(id: "text-solid", kind: .image, background: image("jacket"), textBlocks: [
                .init(text: "Open eat dear winding belonging.", style: .large, fill: PersonalizationColor.semanticInfo, yOffset: 2),
                .init(text: "Open eat dear winding belonging though differed stand left.", style: .medium, alignment: .center, fill: PersonalizationColor.semanticWarning, yOffset: 38),
                .init(text: "Open eat dear winding belonging though differed stand left.", style: .small, alignment: .right, fill: PersonalizationColor.brandPrimary, yOffset: 62)
            ]),
            PersonalizationStorySlide(id: "text-transparent", kind: .image, background: image("backpack"), textBlocks: [
                .init(text: "Open eat dear winding belonging.", style: .large, yOffset: 12),
                .init(text: "Open eat dear winding belonging.", style: .medium, fontFamily: .serif, italic: true, yOffset: 45),
                .init(text: "Open eat dear winding belonging though differed stand left.", style: .small, fontFamily: .monospaced, bold: true, yOffset: 62)
            ])
        ]),
        PersonalizationStory(id: "media", name: "Media", avatarUrl: image("sneakers"), slides: [
            PersonalizationStorySlide(
                id: "action", kind: .image, background: image("sneakers"),
                buttons: [.init(title: "Shop now", link: "https://example.com/sale")],
                products: .init(showLabel: "Используемые товары", hideLabel: "Скрыть товары", items: carousel)
            ),
            PersonalizationStorySlide(id: "plain", kind: .image, background: image("watch"), duration: 3)
        ]),
        PersonalizationStory(id: "viewed", name: "Viewed", avatarUrl: image("sunglasses"), viewed: true, slides: [
            PersonalizationStorySlide(id: "photo", kind: .image, background: image("sunglasses"))
        ])
    ]

    private static func offer(_ base: PersonalizationStorySlide.Offer, promo: String? = nil, discount: Double = 0) -> PersonalizationStorySlide.Offer {
        PersonalizationStorySlide.Offer(
            id: base.id, brand: base.brand, name: base.name, imageUrl: base.imageUrl, price: base.price,
            oldPrice: base.oldPrice, discountPercent: discount, promoCode: promo,
            priceWithPromoCode: promo == nil ? nil : "1 090 900 ₽", link: base.link
        )
    }
}

private extension UIView {
    /// The controller that owns this view, found through the responder chain.
    var nearestViewController: UIViewController? {
        var responder: UIResponder? = self
        while let current = responder {
            if let controller = current as? UIViewController { return controller }
            responder = current.next
        }
        return nil
    }
}
