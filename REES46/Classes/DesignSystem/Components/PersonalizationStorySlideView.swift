import UIKit
import AVFoundation

/// Слайд просмотрщика сторис: фон, затемнения и содержимое.
///
/// Источник: Figma Mobile SDK UI Kit, страница Stories (1:32), Card/Story — виды Product,
/// Promo, Discount, Slide, Action, Text. Собирает его `PersonalizationStoriesViewController`,
/// шапку (прогресс и крестик) кладёт поверх он же.
///
/// Фон — картинка или видео слайда по заполнению, под ним цвет слайда; у слайда без медиа
/// и без своего цвета — Background/Card. Поверх — затемнения
/// сверху и снизу: чёрный 30% (50% у медиа) до нуля на 21% и от 86% высоты.
///
/// Слайд с товаром: заголовок (бренд SemiBold 20 и название SemiBold 16, интерлиньяж 140%,
/// шаг 8), белая карточка картинки (скругление 12, поле 16, квадрат во всю ширину, картинка
/// вписана) и внизу цена с кнопкой Primary LG, шаг 16. Кнопка — первая кнопка слайда,
/// без неё — `Texts.productButton`, ведущая на товар.
///
/// Остальные слайды: текстовые блоки на `yOffset` процентах высоты слайда во всю ширину без
/// полей, кнопки Primary LG внизу, под ними товары (`PersonalizationStoryUsedProducts`);
/// у видео — кнопка звука в начале нижнего ряда.
final class PersonalizationStorySlideView: UIView {

    /// Тексты кита, которые хост может заменить.
    struct Texts {
        var productButton = "More info"
        var promoCaption: String? = "Promo code"
        var promoCopied: String? = "Copied"
        var showProducts = "Used products"
        var hideProducts = "Hide products"
    }

    let slide: PersonalizationStorySlide

    /// Область содержимого: поля 16 по бокам и от низа безопасной зоны. Верх привязывает
    /// просмотрщик — к низу шапки; без него — 16 от верха безопасной зоны.
    let contentGuide = UILayoutGuide()

    var onButton: ((PersonalizationStorySlide.Button) -> Void)?
    var onProduct: ((PersonalizationStorySlide.Offer) -> Void)?
    var onPromoCopied: ((String) -> Void)?
    var onProductsToggle: ((Bool) -> Void)?
    var onMuteToggle: ((Bool) -> Void)?
    var onVideoEnd: (() -> Void)?
    /// Фон готов — можно запускать отсчёт.
    var onReady: (() -> Void)?

    /// Фон готов: картинка загрузилась или не смогла, видео готово к показу или не смогло.
    private(set) var isReady = false

    /// Видео не запустилось: слайд идёт по таймеру, как картинка.
    private(set) var videoFailed = false

    private let texts: Texts
    private let imageLoader: ((UIImageView, String) -> Void)?
    private let backgroundImage = UIImageView()
    private let videoView = VideoView()
    private let scrim = ScrimView()
    private var player: AVPlayer?
    private var statusObservation: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?
    private var soundButton: PersonalizationStorySoundButton?

    private static let brandStyle = PersonalizationTextStyle(size: 20, lineHeight: 28, tracking: 0, weight: .semibold)
    private static let nameStyle = PersonalizationTextStyle(size: 16, lineHeight: 22, tracking: 0, weight: .semibold)
    private static let nameMaxLines = 5

    init(
        slide: PersonalizationStorySlide,
        texts: Texts,
        isMuted: Bool,
        imageLoader: ((UIImageView, String) -> Void)?
    ) {
        self.slide = slide
        self.texts = texts
        self.imageLoader = imageLoader
        super.init(frame: .zero)
        setup(isMuted: isMuted)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    deinit {
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        statusObservation?.invalidate()
        player?.pause()
    }

    private func setup(isMuted: Bool) {
        clipsToBounds = true
        // Слайд без медиа и без своего цвета — Background/Card в теме приложения
        // (белый в светлой, #1A1A1A в тёмной); медиа до загрузки — чёрный.
        backgroundColor = slide.backgroundColor
            ?? (slide.isMedia ? .black : PersonalizationColor.backgroundCard)

        backgroundImage.contentMode = .scaleAspectFill
        backgroundImage.clipsToBounds = true
        videoView.isUserInteractionEnabled = false
        scrim.strength = slide.isMedia ? 0.5 : 0.3
        for view in [backgroundImage, videoView, scrim] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
            NSLayoutConstraint.activate([
                view.topAnchor.constraint(equalTo: topAnchor),
                view.bottomAnchor.constraint(equalTo: bottomAnchor),
                view.leadingAnchor.constraint(equalTo: leadingAnchor),
                view.trailingAnchor.constraint(equalTo: trailingAnchor)
            ])
        }

        addLayoutGuide(contentGuide)
        let side = PersonalizationSpacing.xl  // 16
        NSLayoutConstraint.activate([
            contentGuide.leadingAnchor.constraint(equalTo: leadingAnchor, constant: side),
            contentGuide.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -side),
            contentGuide.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -side),
            // Уступает только привязке просмотрщика к шапке; квадрату карточки (700) не уступает.
            contentGuide.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: side).withPriority(UILayoutPriority(999))
        ])

        if slide.kind == .video {
            let button = PersonalizationStorySoundButton(isMuted: isMuted)
            button.onToggle = { [weak self] muted in
                self?.player?.isMuted = muted
                self?.onMuteToggle?(muted)
            }
            soundButton = button
        }

        if let offer = slide.offer {
            buildProduct(offer)
        } else {
            buildOverlay()
        }
        loadBackground(isMuted: isMuted)
    }

    // MARK: - Фон

    private func loadBackground(isMuted: Bool) {
        switch slide.kind {
        case .video:
            // Постер виден, пока не пошли кадры: слой плеера до первого кадра прозрачный.
            load(backgroundImage, slide.preview)
            setupVideo(isMuted: isMuted)
        case .image, .content:
            guard let url = slide.background, !url.isEmpty else {
                markReady()
                return
            }
            if let imageLoader {
                // Свой загрузчик хоста о готовности не сообщает — отсчёт идёт сразу.
                imageLoader(backgroundImage, url)
                markReady()
                return
            }
            PersonalizationStoryImages.shared.load(url) { [weak self] image in
                guard let self else { return }
                self.backgroundImage.image = image
                self.markReady()
            }
        }
    }

    private func setupVideo(isMuted: Bool) {
        guard let raw = slide.background, let url = URL(string: raw) else {
            videoFailed = true
            markReady()
            return
        }
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.isMuted = isMuted
        player.actionAtItemEnd = .pause
        videoView.playerLayer.videoGravity = .resizeAspectFill
        videoView.playerLayer.player = player
        self.player = player

        statusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            let status = item.status
            MainThread.run {
                guard let self else { return }
                switch status {
                case .readyToPlay:
                    self.markReady()
                case .failed:
                    self.videoFailed = true
                    self.markReady()
                default:
                    break
                }
            }
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.onVideoEnd?()
        }
    }

    private func markReady() {
        guard !isReady else { return }
        isReady = true
        onReady?()
    }

    /// Фон так и не загрузился: слайд идёт дальше по таймеру.
    func giveUpWaiting() {
        guard !isReady else { return }
        if slide.kind == .video {
            videoFailed = true
            player?.pause()
        }
        markReady()
    }

    // MARK: - Видео

    var isVideo: Bool {
        slide.kind == .video && !videoFailed
    }

    /// Доля просмотренного ролика; `nil`, пока длина неизвестна.
    var videoProgress: CGFloat? {
        guard let item = player?.currentItem, item.status == .readyToPlay else { return nil }
        let duration = item.duration.seconds
        guard duration.isFinite, duration > 0 else { return nil }
        return CGFloat(min(max(item.currentTime().seconds / duration, 0), 1))
    }

    func play() {
        guard !videoFailed else { return }
        player?.play()
    }

    func pause() {
        player?.pause()
    }

    func setMuted(_ muted: Bool) {
        player?.isMuted = muted
        soundButton?.isMuted = muted
    }

    /// Слайд уходит с экрана: плеер больше не нужен.
    func stop() {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
    }

    // MARK: - Слайд с товаром

    private func buildProduct(_ offer: PersonalizationStorySlide.Offer) {
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

        // Карточка картинки белая в обеих темах: фото товара — на белом, как в макете.
        let card = UIView()
        card.backgroundColor = .white
        card.layer.cornerRadius = PersonalizationRadius.xl2  // 12
        card.clipsToBounds = true
        let image = UIImageView()
        image.contentMode = .scaleAspectFit
        image.translatesAutoresizingMaskIntoConstraints = false
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
        load(image, offer.imageUrl)

        let price = PersonalizationStoryPrice(price: offer.displayedPrice, oldPrice: offer.oldPrice, kind: offer.priceKind)
        price.promoCaption = texts.promoCaption
        price.copiedText = texts.promoCopied
        price.onPromoCopied = { [weak self] code in self?.onPromoCopied?(code) }

        let button = PersonalizationButton(text: slide.buttons.first?.title ?? texts.productButton, size: .lg, view: .primary)
        button.addTarget(self, action: #selector(productButtonTapped), for: .touchUpInside)

        let bottom = UIStackView(arrangedSubviews: [price, button])
        bottom.axis = .vertical
        bottom.alignment = .fill
        bottom.spacing = PersonalizationSpacing.xl  // 16

        // Между заголовком и низом — середина, карточка стоит по её центру с полями 16.
        let middle = UILayoutGuide()
        addLayoutGuide(middle)
        for view in [header, card, bottom] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: contentGuide.topAnchor),
            header.leadingAnchor.constraint(equalTo: contentGuide.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: contentGuide.trailingAnchor),
            bottom.bottomAnchor.constraint(equalTo: contentGuide.bottomAnchor),
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

    @objc private func offerTapped() {
        guard let offer = slide.offer else { return }
        onProduct?(offer)
    }

    @objc private func productButtonTapped() {
        if let button = slide.buttons.first {
            onButton?(button)
        } else if let offer = slide.offer {
            onProduct?(offer)
        }
    }

    // MARK: - Медиа и прочие слайды

    private func buildOverlay() {
        for block in slide.textBlocks where !block.text.isEmpty {
            let view = PersonalizationStoryTextBlock()
            view.apply(block)
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

        let bottom = UIStackView()
        bottom.axis = .vertical
        bottom.alignment = .fill

        let products = slide.products.flatMap { $0.items.isEmpty ? nil : $0 }
        let hasRow = products != nil || soundButton != nil

        if !slide.buttons.isEmpty {
            let buttons = UIStackView()
            buttons.axis = .vertical
            buttons.alignment = .fill
            buttons.spacing = PersonalizationSpacing.xl  // 16
            for (index, item) in slide.buttons.enumerated() {
                let button = PersonalizationButton(text: item.title, size: .lg, view: .primary)
                button.tag = index
                button.addTarget(self, action: #selector(overlayButtonTapped(_:)), for: .touchUpInside)
                buttons.addArrangedSubview(button)
            }
            // Под кнопкой ряд со своими полями 16 — тогда своё нижнее поле не нужно.
            bottom.addArrangedSubview(padded(buttons, bottom: hasRow ? 0 : PersonalizationSpacing.xl))
        }

        if let products {
            let used = PersonalizationStoryUsedProducts()
            used.showText = Self.nonEmpty(products.showLabel) ?? texts.showProducts
            used.hideText = Self.nonEmpty(products.hideLabel) ?? texts.hideProducts
            used.products = products.items.enumerated().map { index, offer in offer.cardProduct(id: String(index)) }
            used.imageLoader = { [weak self] view, product in self?.load(view, product.imageUrl) }
            used.onProductTap = { [weak self] product in
                guard let self, let index = Int(product.id), index < products.items.count else { return }
                self.onProduct?(products.items[index])
            }
            used.onToggle = { [weak self] expanded in self?.onProductsToggle?(expanded) }
            used.leadingView = soundButton
            bottom.addArrangedSubview(used)
        } else if let soundButton {
            let row = UIView()
            soundButton.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview(soundButton)
            NSLayoutConstraint.activate([
                row.heightAnchor.constraint(equalToConstant: PersonalizationStoryUsedProducts.rowHeight),
                soundButton.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: PersonalizationSpacing.xl),
                soundButton.centerYAnchor.constraint(equalTo: row.centerYAnchor)
            ])
            bottom.addArrangedSubview(row)
        }

        guard !bottom.arrangedSubviews.isEmpty else { return }
        bottom.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bottom)
        NSLayoutConstraint.activate([
            bottom.leadingAnchor.constraint(equalTo: leadingAnchor),
            bottom.trailingAnchor.constraint(equalTo: trailingAnchor),
            bottom.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),
            bottom.topAnchor.constraint(greaterThanOrEqualTo: contentGuide.topAnchor)
        ])
    }

    @objc private func overlayButtonTapped(_ sender: UIControl) {
        guard sender.tag < slide.buttons.count else { return }
        onButton?(slide.buttons[sender.tag])
    }

    private func padded(_ content: UIView, bottom: CGFloat) -> UIView {
        let wrap = UIView()
        content.translatesAutoresizingMaskIntoConstraints = false
        wrap.addSubview(content)
        let side = PersonalizationSpacing.xl
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: wrap.topAnchor),
            content.bottomAnchor.constraint(equalTo: wrap.bottomAnchor, constant: -bottom),
            content.leadingAnchor.constraint(equalTo: wrap.leadingAnchor, constant: side),
            content.trailingAnchor.constraint(equalTo: wrap.trailingAnchor, constant: -side)
        ])
        return wrap
    }

    // MARK: - Помощники

    private func load(_ imageView: UIImageView, _ url: String?) {
        guard let url, !url.isEmpty else {
            imageView.image = nil
            return
        }
        if let imageLoader {
            imageLoader(imageView, url)
        } else {
            SearchImages.shared.load(imageView, url: url)
        }
    }

    private static func text(_ value: String?, _ style: PersonalizationTextStyle) -> NSAttributedString? {
        guard let value else { return nil }
        var attributes = style.attributes
        attributes[.foregroundColor] = PersonalizationColor.textPrimary
        return NSAttributedString(string: value, attributes: attributes)
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }
}

/// Вью, у которой основной слой — слой плеера: кадр тянется за размером вью сам.
private final class VideoView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer {
        // swiftlint:disable:next force_cast
        layer as! AVPlayerLayer
    }
}

/// Затемнения сверху и снизу: чёрный `strength` до нуля на 21% высоты и от нуля
/// на 86% до `strength` у низа. Цвет чёрный в обеих темах — `cgColor` здесь статичный.
private final class ScrimView: UIView {

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
