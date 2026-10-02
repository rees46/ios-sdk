import SwiftUI
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
            ("SwiftUI — PersonalizationStoriesWidget with a controller", { SwiftUIStoriesExhibit() }),
            ("Viewer — sample stories: product, product video with buttons + carousel + sound, text-block promo code, fitted media, Retry", {
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
        addArrangedSubview(controls(for: stories))
    }

    required init(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// Programmatic control: open by index and by id, and the block without its bar. Pause and
    /// resume act on an open viewer, so the demo pauses it 2 s after opening and resumes 3 s later.
    private func controls(for stories: PersonalizationStories) -> UIView {
        let second = PersonalizationButton(text: "Open #2", size: .sm, view: .secondary)
        second.addAction { stories.open(at: 1) }
        let byId = PersonalizationButton(text: "Open last by id", size: .sm, view: .secondary)
        byId.addAction { if let id = stories.stories.last?.id { stories.open(storyId: id) } }
        let paused = PersonalizationButton(text: "Open, pause, resume", size: .sm, view: .secondary)
        paused.addAction {
            stories.open(at: 0)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                stories.pause()
                PersonalizationToast.show("Paused by the host", position: .top)
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { stories.resume() }
            }
        }
        let show = PersonalizationButton(text: "Show without bar", size: .sm, view: .secondary)
        show.addAction { [weak self] in
            PersonalizationStories.show(
                code: AppEnvironments.storiesCode,
                shopId: AppEnvironments.shopId,
                startStoryId: stories.stories.last?.id,
                from: self?.nearestViewController,
                communicationDelegate: self,
                onError: { error in PersonalizationToast.show("Stories: \(error)") },
                onClose: { PersonalizationToast.show("Stories closed", position: .top) }
            )
        }
        let row = UIStackView(arrangedSubviews: [second, byId, paused, show])
        row.axis = .horizontal
        row.spacing = 8
        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        row.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            row.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            row.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            scroll.heightAnchor.constraint(equalTo: row.heightAnchor)
        ])
        return scroll
    }
}

private var demoActionKey: UInt8 = 0

private extension UIControl {
    /// A tap handler as a closure (`UIAction` needs iOS 14, the demo runs on 13).
    func addAction(_ handler: @escaping () -> Void) {
        let target = DemoAction(handler)
        objc_setAssociatedObject(self, &demoActionKey, target, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        addTarget(target, action: #selector(DemoAction.fire), for: .touchUpInside)
    }
}

private final class DemoAction: NSObject {
    private let handler: () -> Void

    init(_ handler: @escaping () -> Void) {
        self.handler = handler
    }

    @objc func fire() {
        handler()
    }
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

// MARK: - SwiftUI

/// The SwiftUI wrapper in a hosting controller, the way a SwiftUI screen embeds it.
private final class SwiftUIStoriesExhibit: UIView {

    private let hosting = UIHostingController(rootView: SwiftUIStoriesV2())

    init() {
        super.init(frame: .zero)
        hosting.view.backgroundColor = .clear
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hosting.view)
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: bottomAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        if #available(iOS 16.0, *) {
            hosting.sizingOptions = .intrinsicContentSize
        } else {
            hosting.view.heightAnchor.constraint(equalToConstant: 230).isActive = true
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil, hosting.parent == nil, let parent = nearestViewController else { return }
        parent.addChild(hosting)
        hosting.didMove(toParent: parent)
    }
}

private struct SwiftUIStoriesV2: View {
    @State private var controller = PersonalizationStoriesController()
    @State private var status = "Loading block \(AppEnvironments.storiesCode)…"

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PersonalizationStoriesWidget(
                code: AppEnvironments.storiesCode,
                shopId: AppEnvironments.shopId,
                controller: controller,
                onError: { status = "Stories failed to load: \($0)" },
                onLoaded: { status = "Stories loaded: \($0)" }
            )
            HStack(spacing: 16) {
                Button("Open the first") { controller.open(at: 0) }
                Button("Reload") { controller.reload() }
            }
            .font(.footnote)
            Text(status)
                .font(.caption)
                .foregroundColor(.secondary)
        }
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

    /// A real story video of the demo shop's block (and its poster).
    static let video = "https://cdn.stories.rees46.ru/9f3065c8-82bc-4f4f-8fca-6b9ee4d4ae57.mp4"
    static let poster = "https://cdn.stories.rees46.ru/69c1044a-0ba5-42a4-b8b8-2fae2dff9125.jpg"

    static let all: [PersonalizationStory] = [
        PersonalizationStory(id: "product", name: "Product", avatarUrl: image("headphones"), pinned: true, slides: [
            PersonalizationStorySlide(id: "price", kind: .content, offer: laptop),
            PersonalizationStorySlide(id: "promo", kind: .content, offer: offer(laptop, promo: "PROMO")),
            PersonalizationStorySlide(
                id: "discount", kind: .content,
                // Ignored without media: a product slide is always on Background/Card.
                backgroundColor: UIColor(red: 0, green: 0x80 / 255.0, blue: 0xF0 / 255.0, alpha: 1),
                buttons: [.init(title: "Buy", link: "https://example.com/laptop")],
                offer: offer(laptop, discount: 12.5)
            )
        ]),
        // Every slide button, the carousel and the sound button on a product video slide.
        PersonalizationStory(id: "product-video", name: "Product video with buttons and carousel", avatarUrl: image("pegasus"), slides: [
            PersonalizationStorySlide(
                id: "product-video", kind: .video, background: video, preview: poster,
                buttons: [.init(title: "Buy now", link: "https://example.com/buy"), .init(title: "Add to wishlist")],
                offer: offer(carousel[0], promo: "RUN10", withCode: "8 999 ₽"),
                products: .init(showLabel: "Используемые товары", hideLabel: "Скрыть товары", items: carousel)
            )
        ]),
        PersonalizationStory(id: "text", name: "Text blocks and a promo code", avatarUrl: image("jacket"), slides: [
            PersonalizationStorySlide(id: "text-solid", kind: .image, background: image("jacket"), textBlocks: [
                .init(text: "Open eat dear winding belonging.", style: .large, fill: PersonalizationColor.semanticInfo, yOffset: 2),
                .init(text: "Tap to copy STORIES10", style: .medium, alignment: .center,
                      fill: PersonalizationColor.semanticWarning, yOffset: 38, promoCode: "STORIES10"),
                .init(text: "Open eat dear winding belonging though differed stand left.", style: .small, alignment: .right, fill: PersonalizationColor.brandPrimary, yOffset: 62)
            ]),
            PersonalizationStorySlide(id: "text-transparent", kind: .image, background: image("backpack"), textBlocks: [
                .init(text: "Open eat dear winding belonging.", style: .large, yOffset: 12),
                .init(text: "Open eat dear winding belonging.", style: .medium, fontFamily: .serif, italic: true, yOffset: 45),
                .init(text: "Open eat dear winding belonging though differed stand left.", style: .small, fontFamily: .monospaced, bold: true, yOffset: 62)
            ])
        ]),
        // Photos are fitted whole: the letterbox is the slide's background_color, black without it.
        PersonalizationStory(id: "media", name: "Fitted media", avatarUrl: image("sneakers"), slides: [
            PersonalizationStorySlide(
                id: "action", kind: .image, background: image("sneakers"),
                backgroundColor: UIColor(red: 0x1E / 255.0, green: 0x3A / 255.0, blue: 0x5F / 255.0, alpha: 1),
                buttons: [.init(title: "Shop now", link: "https://example.com/sale")],
                products: .init(showLabel: "Используемые товары", hideLabel: "Скрыть товары", items: carousel)
            ),
            PersonalizationStorySlide(id: "plain", kind: .image, background: image("watch"), duration: 3),
            PersonalizationStorySlide(id: "video", kind: .video, background: video, preview: poster)
        ]),
        // Media that never arrives: Retry after 10 s; the broken video retries itself after 15 s.
        PersonalizationStory(id: "retry", name: "Retry", avatarUrl: image("bottle"), slides: [
            PersonalizationStorySlide(id: "missing-photo", kind: .image, background: "asset://uikit-missing"),
            PersonalizationStorySlide(id: "broken-video", kind: .video, background: "https://invalid.example/clip.mp4")
        ]),
        PersonalizationStory(id: "viewed", name: "Viewed", avatarUrl: image("sunglasses"), viewed: true, slides: [
            PersonalizationStorySlide(id: "photo", kind: .image, background: image("sunglasses"))
        ])
    ]

    private static func offer(
        _ base: PersonalizationStorySlide.Offer,
        promo: String? = nil,
        discount: Double = 0,
        withCode: String = "1 090 900 ₽"
    ) -> PersonalizationStorySlide.Offer {
        PersonalizationStorySlide.Offer(
            id: base.id, brand: base.brand, name: base.name, imageUrl: base.imageUrl, price: base.price,
            oldPrice: base.oldPrice, discountPercent: discount, promoCode: promo,
            priceWithPromoCode: promo == nil ? nil : withCode, link: base.link
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
