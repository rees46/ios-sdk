import UIKit
import AVFoundation

/// Слайд просмотрщика сторис: медиа, затемнения и содержимое.
///
/// Источник: Figma Mobile SDK UI Kit, страница Stories (1:32), Card/Story — виды Product,
/// Promo, Discount, Slide, Action, Text. Собирает его `PersonalizationStoriesViewController`,
/// шапку (прогресс и крестик) кладёт поверх он же.
///
/// Фото и видео вписаны в экран целиком, без обрезки; поля вокруг — `background_color`
/// слайда, без него чёрные. Слайд без медиа — всегда Background/Card. Поверх — затемнения
/// сверху и снизу: чёрный 50% у голого медиа (без товара и текстов), иначе 30%, до нуля
/// на 21% и от 86% высоты.
///
/// Слайд с товаром: заголовок (бренд SemiBold 20 и название SemiBold 16, интерлиньяж 140%,
/// шаг 8), белая карточка картинки (скругление 12, поле 16, квадрат во всю ширину, картинка
/// вписана), внизу цена и все кнопки слайда Primary LG, шаг 16; без кнопок — одна
/// `Texts.productButton`, ведущая на товар. Текстовые блоки на нём не рисуются.
///
/// Остальные слайды: текстовые блоки на `yOffset` процентах высоты слайда во всю ширину
/// без полей, кнопки Primary LG внизу. Ряд внизу — товары (`PersonalizationStoryUsedProducts`)
/// и кнопка звука у видео — есть на любом слайде, где они нужны, и на товарном тоже.
///
/// Медиа готово — картинка раскодирована или ролик готов к показу; не загрузилось —
/// по центру кнопка «Повторить» (её показывает просмотрщик).
final class PersonalizationStorySlideView: UIView {

    /// Тексты кита, которые хост может заменить.
    struct Texts {
        var productButton = "More info"
        var promoCaption: String? = "Promo code"
        var promoCopied: String? = "Copied"
        var showProducts = "Used products"
        var hideProducts = "Hide products"
        var retry = "Retry"
        var soundOn: String? = "Sound on"
        var soundOff: String? = "Sound off"
    }

    let slide: PersonalizationStorySlide

    /// Область содержимого: поля 16 по бокам и от низа безопасной зоны. Верх привязывает
    /// просмотрщик — к низу шапки; без него — 16 от верха безопасной зоны.
    let contentGuide = UILayoutGuide()

    /// Безопасная зона экрана. Задаётся снаружи: слайд лежит в прокрутке
    /// `UIPageViewController`, и своя безопасная зона до него не доходит. Фон и затемнения
    /// идут от края до края, органы управления — внутри зоны.
    var safeInsets: UIEdgeInsets = .zero {
        didSet {
            guard oldValue != safeInsets else { return }
            applySafeInsets()
        }
    }

    var onButton: ((PersonalizationStorySlide.Button) -> Void)?
    var onProduct: ((PersonalizationStorySlide.Offer) -> Void)?
    var onPromoCopied: ((String) -> Void)?
    var onProductsToggle: ((Bool) -> Void)?
    var onMuteToggle: ((Bool) -> Void)?
    var onVideoEnd: (() -> Void)?
    /// Медиа готово или не загрузилось.
    var onMediaReady: (() -> Void)?
    var onMediaFailed: (() -> Void)?
    /// Нажата «Повторить».
    var onRetry: (() -> Void)?

    /// Медиа готово: у слайда без медиа — сразу.
    private(set) var isMediaReady = false

    let texts: Texts
    let imageLoader: ((UIImageView, String) -> Void)?
    let mediaImage = UIImageView()
    let videoView = PersonalizationStoryVideoView()
    let scrim = PersonalizationStoryScrimView()
    let retryButton: PersonalizationButton
    var player: AVPlayer?
    var videoLoader: PersonalizationStoryVideoLoader?
    var videoObservations: [NSKeyValueObservation] = []
    var videoObservers: [NSObjectProtocol] = []
    var soundButton: PersonalizationStorySoundButton?
    var usedProducts: PersonalizationStoryUsedProducts?
    private var guideTop: NSLayoutConstraint?
    private var guideBottom: NSLayoutConstraint?
    private var guideLeading: NSLayoutConstraint?
    private var guideTrailing: NSLayoutConstraint?
    var bottomRowBottom: NSLayoutConstraint?
    var productGroupBottom: NSLayoutConstraint?

    init(
        slide: PersonalizationStorySlide,
        texts: Texts,
        isMuted: Bool,
        imageLoader: ((UIImageView, String) -> Void)?
    ) {
        self.slide = slide
        self.texts = texts
        self.imageLoader = imageLoader
        self.retryButton = PersonalizationButton(text: texts.retry, size: .md, view: .primary)
        super.init(frame: .zero)
        setup(isMuted: isMuted)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    deinit {
        stop()
    }

    private func setup(isMuted: Bool) {
        clipsToBounds = true
        // Слайд без медиа — всегда Background/Card в теме приложения (белый в светлой,
        // #1A1A1A в тёмной); у медиа фон — поля вокруг вписанного кадра.
        backgroundColor = slide.isMedia ? slide.letterboxColor : PersonalizationColor.backgroundCard

        mediaImage.contentMode = .scaleAspectFit
        mediaImage.clipsToBounds = true
        videoView.isUserInteractionEnabled = false
        videoView.playerLayer.videoGravity = .resizeAspect
        scrim.strength = slide.scrimStrength
        for view in [mediaImage, videoView, scrim] {
            pinEdges(view)
        }

        addLayoutGuide(contentGuide)
        let leading = contentGuide.leadingAnchor.constraint(equalTo: leadingAnchor)
        let trailing = contentGuide.trailingAnchor.constraint(equalTo: trailingAnchor)
        let bottom = contentGuide.bottomAnchor.constraint(equalTo: bottomAnchor)
        // Уступает только привязке просмотрщика к шапке; квадрату карточки (700) не уступает.
        let top = contentGuide.topAnchor.constraint(equalTo: topAnchor).withPriority(UILayoutPriority(999))
        NSLayoutConstraint.activate([leading, trailing, bottom, top])
        guideLeading = leading
        guideTrailing = trailing
        guideBottom = bottom
        guideTop = top

        if case .video = slide.media {
            let button = PersonalizationStorySoundButton(isMuted: isMuted)
            button.soundOnLabel = texts.soundOn
            button.soundOffLabel = texts.soundOff
            button.forcesDarkTokens = true
            button.onToggle = { [weak self] muted in self?.onMuteToggle?(muted) }
            soundButton = button
        }

        if let offer = slide.offer {
            buildProduct(offer)
        } else {
            buildOverlay()
        }
        buildBottomRow()
        applySafeInsets()

        retryButton.isHidden = true
        retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)
        retryButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(retryButton)
        NSLayoutConstraint.activate([
            retryButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            retryButton.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        loadMedia()
    }

    func pinEdges(_ view: UIView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: topAnchor),
            view.bottomAnchor.constraint(equalTo: bottomAnchor),
            view.leadingAnchor.constraint(equalTo: leadingAnchor),
            view.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    /// Поля содержимого от краёв безопасной зоны: 16 по бокам, сверху и снизу;
    /// нижний ряд (товары, звук) стоит прямо на её нижнем крае, над ним — кнопки.
    private func applySafeInsets() {
        let side = PersonalizationSpacing.xl  // 16
        guideTop?.constant = safeInsets.top + side
        guideBottom?.constant = -(safeInsets.bottom + side)
        guideLeading?.constant = safeInsets.left + side
        guideTrailing?.constant = -(safeInsets.right + side)
        bottomRowBottom?.constant = -safeInsets.bottom
        productGroupBottom?.constant = -(safeInsets.bottom + productGroupInset)
    }

    /// Отступ низа товарного слайда от безопасной зоны: над рядом товаров и звука — его
    /// высота, без ряда — обычное поле 16.
    var productGroupInset: CGFloat {
        hasBottomRow ? PersonalizationStoryUsedProducts.rowHeight : PersonalizationSpacing.xl
    }

    var hasBottomRow: Bool {
        slide.products != nil || soundButton != nil
    }

    @objc private func retryTapped() {
        onRetry?()
    }
}

// MARK: - Медиа

extension PersonalizationStorySlideView {

    /// Слайд с роликом.
    var isVideo: Bool {
        if case .video = slide.media { return true }
        return false
    }

    /// Длина ролика, когда она известна; `nil` — слайд идёт по таймеру.
    var videoDuration: TimeInterval? {
        guard let item = player?.currentItem, item.status == .readyToPlay else { return nil }
        let seconds = item.duration.seconds
        return seconds.isFinite && seconds > 0 ? seconds : nil
    }

    /// Доля просмотренного ролика по позиции воспроизведения.
    var videoProgress: CGFloat? {
        guard let duration = videoDuration, let item = player?.currentItem else { return nil }
        return CGFloat(min(max(item.currentTime().seconds / duration, 0), 1))
    }

    /// Загрузить медиа (и заново — по «Повторить»).
    func loadMedia() {
        isMediaReady = false
        switch slide.media {
        case .none:
            markReady()
        case .image(let url):
            loadImage(url)
        case .video(let url):
            // Постер виден, пока не пошли кадры: слой плеера до первого кадра прозрачный.
            if let preview = slide.preview {
                PersonalizationStoryImages.load(into: mediaImage, url: preview, loader: imageLoader)
            }
            setupVideo(url)
        }
    }

    private func loadImage(_ url: String) {
        if let imageLoader {
            // Загрузчик хоста о готовности не сообщает — её видно по появившейся картинке.
            mediaImage.image = nil
            imageLoader(mediaImage, url)
            pollReadiness()
            return
        }
        PersonalizationStoryImages.shared.load(url) { [weak self] image in
            guard let self, self.slide.media == .image(url) else { return }
            if let image {
                self.mediaImage.image = image
                self.markReady()
            } else {
                self.markFailed()
            }
        }
    }

    /// Готовность картинки загрузчика хоста: просмотрщик спрашивает на каждом кадре.
    func pollReadiness() {
        guard !isMediaReady, imageLoader != nil, case .image = slide.media, mediaImage.image != nil else { return }
        markReady()
    }

    private func setupVideo(_ url: String) {
        stopVideo()
        guard let source = PersonalizationStoryVideos.shared.asset(for: url) else {
            markFailed()
            return
        }
        videoLoader = source.loader
        let item = AVPlayerItem(asset: source.asset)
        let player = AVPlayer(playerItem: item)
        player.isMuted = PersonalizationStoryAudio.shared.isMuted
        player.actionAtItemEnd = .pause
        videoView.playerLayer.player = player
        self.player = player

        videoObservations = [item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            let status = item.status
            MainThread.run {
                guard let self, self.player?.currentItem === item else { return }
                switch status {
                case .readyToPlay: self.markReady()
                case .failed: self.markFailed()
                default: break
                }
            }
        }]
        let center = NotificationCenter.default
        videoObservers = [
            center.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
                self?.onVideoEnd?()
            },
            center.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main) { [weak self] _ in
                self?.markFailed()
            }
        ]
    }

    private func markReady() {
        guard !isMediaReady else { return }
        isMediaReady = true
        onMediaReady?()
    }

    private func markFailed() {
        isMediaReady = false
        player?.pause()
        onMediaFailed?()
    }

    /// «Повторить» по центру слайда.
    func setRetryVisible(_ visible: Bool) {
        retryButton.isHidden = !visible
    }

    func play() {
        guard isMediaReady else { return }
        player?.play()
    }

    func pause() {
        player?.pause()
    }

    /// Тот же слайд с начала: ролик — с нулевой секунды.
    func restart() {
        player?.seek(to: .zero)
    }

    func setMuted(_ muted: Bool) {
        player?.isMuted = muted
        soundButton?.isMuted = muted
    }

    /// Слайд уходит с экрана: плеер и загрузка ролика больше не нужны.
    func stop() {
        stopVideo()
    }

    private func stopVideo() {
        videoObservations.forEach { $0.invalidate() }
        videoObservations = []
        videoObservers.forEach { NotificationCenter.default.removeObserver($0) }
        videoObservers = []
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        videoView.playerLayer.player = nil
        videoLoader = nil
    }
}

// MARK: - Слайд с товаром

extension PersonalizationStorySlideView {

    private static let brandStyle = PersonalizationTextStyle(size: 20, lineHeight: 28, tracking: 0, weight: .semibold)
    private static let nameStyle = PersonalizationTextStyle(size: 16, lineHeight: 22, tracking: 0, weight: .semibold)
    private static let nameMaxLines = 5

    fileprivate func buildProduct(_ offer: PersonalizationStorySlide.Offer) {
        let brand = UILabel()
        brand.numberOfLines = 2
        brand.attributedText = Self.text(offer.brand, Self.brandStyle)
        brand.isHidden = (offer.brand ?? "").isEmpty
        let name = UILabel()
        name.numberOfLines = Self.nameMaxLines
        name.attributedText = Self.text(offer.name, Self.nameStyle)
        for label in [brand, name] {
            label.setContentCompressionResistancePriority(.required, for: .vertical)
        }
        let header = UIStackView(arrangedSubviews: [brand, name])
        header.axis = .vertical
        header.alignment = .fill
        header.spacing = PersonalizationSpacing.md  // 8

        let card = productCard(offer)

        let price = PersonalizationStoryPrice(price: offer.displayedPrice, oldPrice: offer.crossedOutPrice, kind: offer.priceKind)
        price.promoCaption = offer.promoCaption ?? texts.promoCaption
        price.copiedText = texts.promoCopied
        price.onPromoCopied = { [weak self] code in self?.onPromoCopied?(code) }

        // Все кнопки слайда; без них — одна, ведущая на товар.
        var group: [UIView] = [price]
        if slide.buttons.isEmpty {
            let button = PersonalizationButton(text: texts.productButton, size: .lg, view: .primary)
            button.addTarget(self, action: #selector(productButtonTapped), for: .touchUpInside)
            group.append(button)
        } else {
            group += slideButtons()
        }
        let bottom = UIStackView(arrangedSubviews: group)
        bottom.axis = .vertical
        bottom.alignment = .fill
        bottom.spacing = PersonalizationSpacing.xl  // 16

        // Между заголовком и низом — середина, карточка стоит по её центру с полями 16.
        let inset = PersonalizationSpacing.xl  // 16
        let middle = UILayoutGuide()
        addLayoutGuide(middle)
        for view in [header, card, bottom] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        // Над рядом товаров и звука низ стоит на высоте ряда, иначе — на поле 16.
        let groupBottom = bottom.bottomAnchor.constraint(equalTo: bottomAnchor)
        productGroupBottom = groupBottom
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: contentGuide.topAnchor),
            header.leadingAnchor.constraint(equalTo: contentGuide.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: contentGuide.trailingAnchor),
            groupBottom,
            bottom.leadingAnchor.constraint(equalTo: contentGuide.leadingAnchor),
            bottom.trailingAnchor.constraint(equalTo: contentGuide.trailingAnchor),
            middle.topAnchor.constraint(equalTo: header.bottomAnchor, constant: inset),
            middle.bottomAnchor.constraint(equalTo: bottom.topAnchor, constant: -inset),
            card.centerXAnchor.constraint(equalTo: contentGuide.centerXAnchor),
            card.centerYAnchor.constraint(equalTo: middle.centerYAnchor),
            card.heightAnchor.constraint(equalTo: card.widthAnchor),
            card.widthAnchor.constraint(lessThanOrEqualTo: contentGuide.widthAnchor),
            card.heightAnchor.constraint(lessThanOrEqualTo: middle.heightAnchor),
            // Во всю ширину, если по высоте помещается; иначе квадрат уменьшается.
            card.widthAnchor.constraint(equalTo: contentGuide.widthAnchor).withPriority(UILayoutPriority(700))
        ])
    }

    /// Белая карточка картинки в обеих темах: фото товара — на белом, как в макете.
    private func productCard(_ offer: PersonalizationStorySlide.Offer) -> UIView {
        let card = UIView()
        card.backgroundColor = .white
        card.layer.cornerRadius = PersonalizationRadius.xl2  // 12
        card.clipsToBounds = true
        let image = UIImageView()
        image.contentMode = .scaleAspectFit
        image.translatesAutoresizingMaskIntoConstraints = false
        // Размер картинки не держит карточку: при нехватке высоты уменьшается квадрат,
        // а не цена и кнопки под ним.
        for axis in [NSLayoutConstraint.Axis.horizontal, .vertical] {
            image.setContentCompressionResistancePriority(.defaultLow, for: axis)
            image.setContentHuggingPriority(.defaultLow, for: axis)
        }
        card.addSubview(image)
        let inset = PersonalizationSpacing.xl  // 16
        NSLayoutConstraint.activate([
            image.topAnchor.constraint(equalTo: card.topAnchor, constant: inset),
            image.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -inset),
            image.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: inset),
            image.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -inset)
        ])
        card.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(offerTapped)))
        card.isAccessibilityElement = true
        card.accessibilityLabel = offer.name
        card.accessibilityTraits = .button
        PersonalizationStoryImages.load(into: image, url: offer.imageUrl, loader: imageLoader)
        return card
    }

    @objc private func offerTapped() {
        guard let offer = slide.offer else { return }
        onProduct?(offer)
    }

    @objc private func productButtonTapped() {
        guard let offer = slide.offer else { return }
        onProduct?(offer)
    }

    private static func text(_ value: String?, _ style: PersonalizationTextStyle) -> NSAttributedString? {
        guard let value else { return nil }
        var attributes = style.attributes
        attributes[.foregroundColor] = PersonalizationColor.textPrimary
        return NSAttributedString(string: value, attributes: attributes)
    }
}

// MARK: - Медиа и прочие слайды

extension PersonalizationStorySlideView {

    fileprivate func buildOverlay() {
        for block in slide.visibleTextBlocks {
            let view = textBlockView(block)
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
            // Отступ сверху — доля высоты слайда: направляющая нужной высоты от верха.
            let offset = UILayoutGuide()
            addLayoutGuide(offset)
            let percent = min(max(block.yOffset, 0), 100) / 100
            NSLayoutConstraint.activate([
                offset.topAnchor.constraint(equalTo: topAnchor),
                percent > 0
                    ? offset.heightAnchor.constraint(equalTo: heightAnchor, multiplier: percent)
                    : offset.heightAnchor.constraint(equalToConstant: 0),
                view.topAnchor.constraint(equalTo: offset.bottomAnchor).withPriority(.defaultHigh),
                // Под шапку блок не заезжает.
                view.topAnchor.constraint(greaterThanOrEqualTo: contentGuide.topAnchor),
                view.leadingAnchor.constraint(equalTo: contentGuide.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: contentGuide.trailingAnchor)
            ])
        }

        guard !slide.buttons.isEmpty else { return }
        let buttons = UIStackView(arrangedSubviews: slideButtons())
        buttons.axis = .vertical
        buttons.alignment = .fill
        buttons.spacing = PersonalizationSpacing.xl  // 16
        buttons.translatesAutoresizingMaskIntoConstraints = false
        addSubview(buttons)
        // Над рядом товаров и звука кнопки стоят на высоте ряда, иначе — на поле 16.
        let bottom = buttons.bottomAnchor.constraint(equalTo: bottomAnchor)
        productGroupBottom = bottom
        NSLayoutConstraint.activate([
            bottom,
            buttons.leadingAnchor.constraint(equalTo: contentGuide.leadingAnchor),
            buttons.trailingAnchor.constraint(equalTo: contentGuide.trailingAnchor),
            buttons.topAnchor.constraint(greaterThanOrEqualTo: contentGuide.topAnchor)
        ])
    }

    /// Текстовый блок; с промокодом нажатие копирует код и показывает тост сверху.
    private func textBlockView(_ block: PersonalizationStorySlide.TextBlock) -> PersonalizationStoryTextBlock {
        let view = PersonalizationStoryTextBlock()
        view.forcesDarkTokens = slide.isMedia
        view.apply(block)
        view.copiedText = texts.promoCopied
        view.onPromoCopied = { [weak self] code in self?.onPromoCopied?(code) }
        return view
    }

    /// Кнопки слайда — Primary LG, по порядку из админки.
    func slideButtons() -> [UIView] {
        slide.buttons.enumerated().map { index, item in
            let button = PersonalizationButton(text: item.title, size: .lg, view: .primary)
            button.tag = index
            button.addTarget(self, action: #selector(slideButtonTapped(_:)), for: .touchUpInside)
            return button
        }
    }

    @objc private func slideButtonTapped(_ sender: UIControl) {
        guard slide.buttons.indices.contains(sender.tag) else { return }
        onButton?(slide.buttons[sender.tag])
    }

    /// Ряд внизу: товары слайда и кнопка звука у видео — на любом виде слайда.
    fileprivate func buildBottomRow() {
        let row: UIView
        if let products = slide.products {
            let used = PersonalizationStoryUsedProducts()
            used.showText = products.showLabel ?? texts.showProducts
            used.hideText = products.hideLabel ?? texts.hideProducts
            used.products = products.items.enumerated().map { index, offer in offer.cardProduct(id: String(index)) }
            used.imageLoader = { [weak self] view, product in
                PersonalizationStoryImages.load(into: view, url: product.imageUrl, loader: self?.imageLoader)
            }
            used.onProductTap = { [weak self] product in
                guard let self, let index = Int(product.id), products.items.indices.contains(index) else { return }
                self.onProduct?(products.items[index])
            }
            used.onToggle = { [weak self] expanded in self?.onProductsToggle?(expanded) }
            used.leadingView = soundButton
            used.forcesDarkTokens = slide.isMedia
            usedProducts = used
            row = used
        } else if let soundButton {
            row = UIView()
            soundButton.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview(soundButton)
            NSLayoutConstraint.activate([
                row.heightAnchor.constraint(equalToConstant: PersonalizationStoryUsedProducts.rowHeight),
                soundButton.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: PersonalizationSpacing.xl),
                soundButton.centerYAnchor.constraint(equalTo: row.centerYAnchor)
            ])
        } else {
            return
        }
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        // Низ ряда — край безопасной зоны: у ряда товаров свои поля 16.
        let rowBottom = row.bottomAnchor.constraint(equalTo: bottomAnchor)
        bottomRowBottom = rowBottom
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            rowBottom,
            row.topAnchor.constraint(greaterThanOrEqualTo: contentGuide.topAnchor)
        ])
    }

    /// Свернуть лист товаров: нажатие мимо него или смена слайда.
    func collapseProducts() {
        usedProducts?.isExpanded = false
    }
}

/// Вью, у которой основной слой — слой плеера: кадр тянется за размером вью сам.
final class PersonalizationStoryVideoView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer {
        // swiftlint:disable:next force_cast
        layer as! AVPlayerLayer
    }
}

/// Затемнения сверху и снизу: чёрный `strength` до нуля на 21% высоты и от нуля
/// на 86% до `strength` у низа. Цвет чёрный в обеих темах — `cgColor` здесь статичный.
final class PersonalizationStoryScrimView: UIView {

    var strength: CGFloat = 0.3 {
        didSet { applyColors() }
    }

    private let top = CAGradientLayer()
    private let bottom = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        layer.addSublayer(top)
        layer.addSublayer(bottom)
        applyColors()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func applyColors() {
        let dark = UIColor(white: 0, alpha: strength).cgColor
        let clear = UIColor(white: 0, alpha: 0).cgColor
        top.colors = [dark, clear]
        bottom.colors = [clear, dark]
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let height = bounds.height
        top.frame = CGRect(x: 0, y: 0, width: bounds.width, height: height * 0.21)
        bottom.frame = CGRect(x: 0, y: height * 0.86, width: bounds.width, height: height * 0.14)
        CATransaction.commit()
    }
}
