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
/// `Texts.productButton`, ведущая на товар (у слайда v3 её нет, как в вебе). Текстовые блоки на нём не рисуются; промокод
/// первого блока с кодом идёт в блок цены, если у товара своего кода нет. Товар открывают
/// только кнопки: картинка, заголовок и скидка не нажимаются, касание по ним — касание
/// слайда (листание по третям, удержание — пауза).
///
/// Остальные слайды: текстовые блоки на `yOffset` процентах высоты слайда во всю ширину
/// без полей, но целиком между шапкой и кнопками (`place(_:yOffset:)`); карточка опроса — на
/// своём `y_offset`, как в вебе (`attachPoll`); кнопки Primary LG внизу. Ряд внизу — товары
/// (`PersonalizationStoryUsedProducts`) и кнопка звука у видео — есть на любом слайде, где
/// они нужны, и на товарном тоже.
///
/// Медиа готово — картинка раскодирована (у GIF — первый кадр на экране) или ролик готов
/// к показу; не загрузилось — по центру кнопка «Повторить» (её показывает просмотрщик).
///
/// GIF фона (его загрузил встроенный загрузчик) играет по кругу со своими длинами кадров и
/// стоит, пока стоит слайд; слайд с ним идёт не меньше одного круга. GIF от загрузчика хоста
/// SDK не анимирует и не меряет.
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
    var onHeader: ((PersonalizationStorySlide.Header) -> Void)?
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
    /// Ролик встал сам, хотя просмотрщик велел играть: звук забрала система (наушники,
    /// прерывание). Сообщается раз, пока ролик снова не пойдёт.
    var onSystemStop: (() -> Void)?

    /// Медиа готово: у слайда без медиа — сразу.
    private(set) var isMediaReady = false

    let texts: Texts
    let imageLoader: ((UIImageView, String) -> Void)?
    let mediaImage = UIImageView()
    let videoView = PersonalizationStoryVideoView()
    let scrim = PersonalizationStoryScrimView()
    let retryButton: PersonalizationButton
    var player: AVPlayer?
    /// Проигрыватель GIF фона.
    var gifPlayer: PersonalizationStoryGifPlayer?
    var videoLoader: PersonalizationStoryVideoLoader?
    var videoObservations: [NSKeyValueObservation] = []
    var videoObservers: [NSObjectProtocol] = []
    var soundButton: PersonalizationStorySoundButton?
    var usedProducts: PersonalizationStoryUsedProducts?
    /// Просмотрщик велел играть и не велел остановиться.
    private(set) var wantsPlayback = false
    /// Ролик без звука — как велел просмотрщик.
    private(set) var isMuted: Bool
    private var reportedSystemStop = false
    private var guideTop: NSLayoutConstraint?
    private var guideBottom: NSLayoutConstraint?
    private var guideLeading: NSLayoutConstraint?
    private var guideTrailing: NSLayoutConstraint?
    var bottomRowBottom: NSLayoutConstraint?
    var productGroupBottom: NSLayoutConstraint?
    /// Ряд товаров и звука: лист товаров накрывает карточку опроса.
    var bottomRow: UIView?
    /// Верх кнопок слайда (у товарного — цены с кнопками): ниже текстовые блоки не опускаются,
    /// см. `place(_:yOffset:)`.
    var offsetLimit: NSLayoutYAxisAnchor?
    /// Низы элементов на `yOffset` у слайда без кнопок: идут за безопасной зоной.
    var offsetBottoms: [NSLayoutConstraint] = []
    /// Карточка опроса слайда, см. `attachPoll`.
    private(set) var pollView: PersonalizationStoryPollView?
    /// Шапка слайда (элемент `header`, API v3).
    private(set) var headerView: PersonalizationStoryHeaderView?
    /// Низ карточки опроса — на 16 выше видимого ряда внизу, без него — выше безопасной зоны.
    private var pollBottom: NSLayoutConstraint?
    /// Верх карточки опроса — не выше безопасной зоны (под статус-баром она не встаёт).
    private var pollTop: NSLayoutConstraint?
    static let pollBottomGap = PersonalizationSpacing.xl  // 16
    /// Верх содержимого: под шапкой слайда, без неё — верх области содержимого.
    var contentTop: NSLayoutYAxisAnchor { headerBottom?.anchor ?? contentGuide.topAnchor }
    private var headerBottom: (anchor: NSLayoutYAxisAnchor, guide: UILayoutGuide)?

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
        self.isMuted = isMuted
        super.init(frame: .zero)
        setup(isMuted: isMuted)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    deinit {
        stop()
    }

    private func setup(isMuted: Bool) {
        clipsToBounds = true
        // Слайд без медиа — Background/Card в теме приложения (белый в светлой, #1A1A1A в
        // тёмной), у слайда v3 — его `background_color`; у медиа фон — поля вокруг кадра.
        backgroundColor = slide.fillColor

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
            button.onToggle = { [weak self] muted in self?.onMuteToggle?(muted) }
            // Слайд v3: кнопка звука прячется, только когда дорожки ролика известны и звука среди
            // них нет (`updateSoundButton`); пока неясно — видна.
            soundButton = button
        }

        buildHeader()
        // Текстовые блоки товарного слайда не рисуются, их промокод — в блоке цены карточки.
        if let offer = slide.cardOffer {
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
    /// нижний ряд (товары, звук) стоит прямо на её нижнем крае, над ним — кнопки. Без видимого
    /// ряда места под него нет.
    private func applySafeInsets() {
        let side = PersonalizationSpacing.xl  // 16
        guideTop?.constant = safeInsets.top + side
        guideBottom?.constant = -(safeInsets.bottom + side)
        guideLeading?.constant = safeInsets.left + side
        guideTrailing?.constant = -(safeInsets.right + side)
        bottomRowBottom?.constant = -safeInsets.bottom
        productGroupBottom?.constant = -(safeInsets.bottom + productGroupInset)
        for bottom in offsetBottoms {
            bottom.constant = -(safeInsets.bottom + productGroupInset)
        }
        pollBottom?.constant = -pollBottomInset
        pollTop?.constant = safeInsets.top
    }

    /// Отступ низа товарного слайда от безопасной зоны: над рядом товаров и звука — его
    /// высота, без ряда — обычное поле 16.
    var productGroupInset: CGFloat {
        hasBottomRow ? PersonalizationStoryUsedProducts.rowHeight : PersonalizationSpacing.xl
    }

    /// Отступ низа карточки опроса от низа слайда: 16 над свёрнутым рядом внизу (переключатель
    /// товаров, кнопка звука), когда он виден, иначе 16 над безопасной зоной. Раскрытый лист
    /// товаров карточку не двигает — накрывает.
    var pollBottomInset: CGFloat {
        safeInsets.bottom + (hasBottomRow ? PersonalizationStoryUsedProducts.rowHeight : 0) + Self.pollBottomGap
    }

    /// Внизу виден ряд: переключатель товаров или кнопка звука. Спрятанная кнопка места не держит.
    var hasBottomRow: Bool {
        slide.products != nil || soundButton.map { !$0.isHidden } ?? false
    }

    /// Ряд появился или пропал (кнопка звука после дорожек ролика): всё, что стоит над ним, —
    /// на новое место.
    func updateBottomRow() {
        if usedProducts == nil { bottomRow?.isHidden = !hasBottomRow }
        applySafeInsets()
        setNeedsLayout()
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
        stopGif()
        if let imageLoader {
            // Загрузчик хоста о готовности не сообщает — её видно по появившейся картинке.
            // Его GIF SDK не анимирует и не меряет: слайд идёт `duration` с сервера.
            mediaImage.image = nil
            imageLoader(mediaImage, url)
            pollReadiness()
            return
        }
        PersonalizationStoryImages.shared.load(url) { [weak self] picture in
            guard let self, self.slide.media == .image(url) else { return }
            switch picture {
            case .image(let image)?:
                self.mediaImage.image = image
                self.markReady()
            case .gif(let gif)?:
                self.startGif(gif)
            case nil:
                self.markFailed()
            }
        }
    }

    /// GIF фона: готово, когда первый кадр на экране; первый кадр не раскодировался —
    /// «Повторить», как у битого фото. Играть начнёт `play()`.
    private func startGif(_ gif: PersonalizationStoryGif) {
        stopGif()
        let screen = window?.screen ?? UIScreen.main
        // До раскладки слайд ещё без размера — он во весь экран.
        let area = bounds.isEmpty ? screen.bounds.size : bounds.size
        let player = PersonalizationStoryGifPlayer(gif: gif, maxPixelSize: gif.maxPixelSize(fitting: area, scale: screen.scale))
        player.onFrame = { [weak self] image in self?.mediaImage.image = image }
        player.onReady = { [weak self] in self?.markReady() }
        player.onFailure = { [weak self] in self?.markFailed() }
        gifPlayer = player
        player.prepare()
    }

    private func stopGif() {
        gifPlayer?.stop()
        gifPlayer = nil
    }

    /// Один круг GIF фона, когда он известен: GIF загрузил встроенный загрузчик.
    var gifLoopDuration: TimeInterval? {
        gifPlayer?.gif.loopDuration
    }

    /// Длина слайда по таймеру: `duration` с сервера, у GIF — не меньше одного круга.
    var timerDuration: TimeInterval {
        PersonalizationStoriesViewerState.timerDuration(slide.duration, gifLoop: gifLoopDuration)
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
        player.isMuted = isMuted
        player.actionAtItemEnd = .pause
        videoView.playerLayer.player = player
        self.player = player

        videoObservations = [item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            let status = item.status
            MainThread.run {
                guard let self, self.player?.currentItem === item else { return }
                switch status {
                case .readyToPlay:
                    self.updateSoundButton(item)
                    self.markReady()
                case .failed: self.markFailed()
                default: break
                }
            }
        }, player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            // Не сразу: сначала доходят свои уведомления (ошибка ролика, смена выхода звука),
            // и ответ просмотрщика трогает плеер уже не внутри уведомления.
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.systemStopDelay) { self?.playbackStatusChanged(player) }
        }, item.observe(\.tracks, options: [.new]) { [weak self] item, _ in
            // Дорожки приходят и после готовности: звук проверяется заново.
            MainThread.run {
                guard let self, self.player?.currentItem === item else { return }
                self.updateSoundButton(item)
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
        wantsPlayback = false
        player?.pause()
        gifPlayer?.pause()
        onMediaFailed?()
    }

    /// Звук ролика по его дорожкам.
    enum AudioTrack: Equatable {
        /// Есть звуковая дорожка.
        case present
        /// Дорожки известны, звуковой среди них нет.
        case absent
        /// Дорожек ещё нет или они не прочитаны — неясно.
        case unknown
    }

    static func audioTrack(_ item: AVPlayerItem) -> AudioTrack {
        audioTrack(item.tracks.map { $0.assetTrack?.mediaType })
    }

    /// Типы дорожек ролика; `nil` — дорожка без прочитанного типа.
    static func audioTrack(_ types: [AVMediaType?]) -> AudioTrack {
        if types.contains(.audio) { return .present }
        return types.isEmpty || types.contains(nil) ? .unknown : .absent
    }

    /// Кнопка звука слайда v3: спрятана, только когда звука в ролике точно нет (веб прячет её и
    /// без ответа — здесь неясный ответ оставляет кнопку). Старая лента кнопку не прячет.
    func updateSoundButton(_ item: AVPlayerItem) {
        setSoundAvailability(Self.audioTrack(item))
    }

    func setSoundAvailability(_ track: AudioTrack) {
        guard slide.isV3, let soundButton else { return }
        let hidden = track == .absent
        guard soundButton.isHidden != hidden else { return }
        soundButton.isHidden = hidden
        updateBottomRow()
    }

    /// Сколько ждать, прежде чем счесть паузу плеера делом системы.
    static let systemStopDelay: TimeInterval = 0.3

    /// Пауза, которой просмотрщик не просил, у готового ролика и не в конце — дело системы.
    func playbackStatusChanged(_ player: AVPlayer) {
        guard player === self.player else { return }
        switch player.timeControlStatus {
        case .playing:
            reportedSystemStop = false
        case .paused:
            guard wantsPlayback, isMediaReady, !reportedSystemStop,
                  player.currentItem?.status == .readyToPlay, !Self.isAtEnd(player) else { return }
            reportedSystemStop = true
            onSystemStop?()
        default:
            break
        }
    }

    /// Ролик дошёл до конца (или длина неизвестна — тогда не гадаем).
    static func isAtEnd(_ player: AVPlayer) -> Bool {
        guard let item = player.currentItem, item.duration.isNumeric else { return true }
        return item.currentTime().seconds >= item.duration.seconds - 0.25
    }

    /// «Повторить» по центру слайда.
    func setRetryVisible(_ visible: Bool) {
        retryButton.isHidden = !visible
    }

    func play() {
        guard isMediaReady else { return }
        wantsPlayback = true
        player?.play()
        gifPlayer?.resume()
    }

    /// GIF встаёт на текущем кадре, `play()` продолжит с него.
    func pause() {
        wantsPlayback = false
        player?.pause()
        gifPlayer?.pause()
    }

    /// Тот же слайд с начала: ролик — с нулевой секунды, GIF — с первого кадра без перезагрузки.
    func restart() {
        player?.seek(to: .zero)
        gifPlayer?.restart()
    }

    /// Слайд ушёл с экрана, но остаётся на странице: GIF встаёт на первый кадр и отпускает
    /// остальные — вернутся к слайду, он пойдёт с начала.
    func rewindAnimation() {
        gifPlayer?.rewind()
    }

    func setMuted(_ muted: Bool) {
        isMuted = muted
        player?.isMuted = muted
        soundButton?.isMuted = muted
    }

    /// Слайд уходит с экрана: плеер и загрузка ролика, кадры GIF больше не нужны.
    func stop() {
        stopVideo()
        stopGif()
    }

    private func stopVideo() {
        wantsPlayback = false
        reportedSystemStop = false
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

        // Все кнопки слайда; без них — одна, ведущая на товар. У слайда v3 — нет: веб её не рисует.
        var group: [UIView] = [price]
        if slide.buttons.isEmpty, !slide.isV3 {
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
        offsetLimit = bottom.topAnchor
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: contentTop),
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
    /// Не нажимается: касание по ней листает слайд, как касание в любом месте слайда.
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
        // Касания проходят сквозь карточку к жестам страницы: нажатие по третям и удержание.
        card.isUserInteractionEnabled = false
        // Для VoiceOver — картинка с названием товара, без действия.
        card.isAccessibilityElement = true
        card.accessibilityLabel = offer.name
        card.accessibilityTraits = .image
        PersonalizationStoryImages.load(into: image, url: offer.imageUrl, loader: imageLoader)
        return card
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
        let blocks = slide.visibleTextBlocks.map { block -> (view: UIView, yOffset: CGFloat) in
            let view = textBlockView(block)
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
            return (view, block.yOffset)
        }
        // Кнопки лежат над блоками, а блоки стоят над кнопками: место блокам — после кнопок.
        buildButtons()
        for block in blocks {
            place(block.view, yOffset: block.yOffset)
            NSLayoutConstraint.activate([
                block.view.leadingAnchor.constraint(equalTo: contentGuide.leadingAnchor),
                block.view.trailingAnchor.constraint(equalTo: contentGuide.trailingAnchor)
            ])
        }
    }

    private func buildButtons() {
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
        offsetLimit = buttons.topAnchor
        NSLayoutConstraint.activate([
            bottom,
            buttons.leadingAnchor.constraint(equalTo: contentGuide.leadingAnchor),
            buttons.trailingAnchor.constraint(equalTo: contentGuide.trailingAnchor),
            buttons.topAnchor.constraint(greaterThanOrEqualTo: contentTop)
        ])
    }

    /// Шапка слайда (элемент `header`) — вверху области содержимого во всю ширину; остальное
    /// содержимое — под ней.
    fileprivate func buildHeader() {
        guard let header = slide.header else { return }
        let view = PersonalizationStoryHeaderView(header: header, imageLoader: imageLoader)
        view.addTarget(self, action: #selector(headerTapped), for: .touchUpInside)
        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)
        let below = UILayoutGuide()
        addLayoutGuide(below)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: contentGuide.topAnchor),
            view.leadingAnchor.constraint(equalTo: contentGuide.leadingAnchor),
            view.trailingAnchor.constraint(lessThanOrEqualTo: contentGuide.trailingAnchor),
            below.topAnchor.constraint(equalTo: view.bottomAnchor, constant: PersonalizationSpacing.xl),
            below.heightAnchor.constraint(equalToConstant: 0)
        ])
        headerView = view
        headerBottom = (below.topAnchor, below)
    }

    @objc private func headerTapped() {
        guard let header = slide.header else { return }
        onHeader?(header)
    }

    /// Текстовый блок; с промокодом нажатие копирует код и показывает тост сверху.
    private func textBlockView(_ block: PersonalizationStorySlide.TextBlock) -> PersonalizationStoryTextBlock {
        let view = PersonalizationStoryTextBlock()
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
            usedProducts = used
            row = used
        } else if let soundButton {
            row = PersonalizationStoryPassThroughView()
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
        bottomRow = row
        // Низ ряда — край безопасной зоны: у ряда товаров свои поля 16.
        let rowBottom = row.bottomAnchor.constraint(equalTo: bottomAnchor)
        bottomRowBottom = rowBottom
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            rowBottom,
            row.topAnchor.constraint(greaterThanOrEqualTo: contentTop)
        ])
    }

    /// Свернуть лист товаров: нажатие мимо него или смена слайда.
    func collapseProducts() {
        usedProducts?.isExpanded = false
    }
}

/// Ряд во всю ширину слайда (кнопка звука внизу): пустые места касаний не берут — они достаются
/// тому, что под рядом, карточке опроса или слайду; берут только кнопки ряда.
final class PersonalizationStoryPassThroughView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return hit === self ? nil : hit
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

// MARK: - Место по `y_offset`

extension PersonalizationStorySlideView {

    /// Место текстового блока на `yOffset`, как `top: y%` в контейнере слайда в вебе: верх —
    /// `yOffset` процентов высоты всего слайда (зажато в 0...100, `nil` — 0); потом элемент целиком
    /// сдвигается в область
    /// между шапкой и кнопками (без кнопок — рядом товаров и звука или полем 16): ниже области —
    /// поднимается, выше — встаёт к её верху. Ширина — у вызывающего.
    func place(_ view: UIView, yOffset: CGFloat?) {
        let offset = UILayoutGuide()
        addLayoutGuide(offset)
        let share = Self.offsetShare(yOffset)
        let bottom: NSLayoutConstraint
        if let offsetLimit {
            bottom = view.bottomAnchor.constraint(lessThanOrEqualTo: offsetLimit, constant: -PersonalizationSpacing.xl)
        } else {
            bottom = view.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -(safeInsets.bottom + productGroupInset))
            offsetBottoms.append(bottom)
        }
        NSLayoutConstraint.activate([
            offset.topAnchor.constraint(equalTo: topAnchor),
            share > 0
                ? offset.heightAnchor.constraint(equalTo: heightAnchor, multiplier: share)
                : offset.heightAnchor.constraint(equalToConstant: 0),
            // Слабее высоты по содержимому (у карточки опроса — 700, у текста — 750): сначала
            // сдвиг; карточку, не влезшую совсем, дальше прокрутка.
            view.topAnchor.constraint(equalTo: offset.bottomAnchor).withPriority(UILayoutPriority(600)),
            // Под шапку и под кнопки элемент не заезжает.
            view.topAnchor.constraint(greaterThanOrEqualTo: contentTop),
            bottom
        ])
    }

    /// Доля высоты слайда для `y_offset`: проценты, зажатые в 0...100; `nil` и не число — 0.
    static func offsetShare(_ yOffset: CGFloat?) -> CGFloat {
        guard let yOffset, yOffset.isFinite else { return 0 }
        return min(max(yOffset, 0), 100) / 100
    }
}

// MARK: - Опрос

extension PersonalizationStorySlideView {

    /// Карточка опроса, как в вебе (`fittedTop`): верх — `y_offset` процентов высоты слайда
    /// (зажато в 0...100, без него — 0); не влезает ниже — поднимается, чтобы низ был на 16 выше
    /// ряда внизу (переключатель товаров, кнопка звука), когда он виден, иначе — безопасной зоны,
    /// но не выше верха безопасной зоны (под статус-бар не встаёт); не влезает совсем —
    /// прокручивается внутри. Пустые места ряда касаний не берут: под рядом карточка нажимается.
    /// Может уйти под шапку — прогресс, крестик и «Поделиться» остаются поверх и нажимаются. По ширине — 12 от краёв слайда (на 4 шире поля содержимого 16 с каждой
    /// стороны), не шире 420, по центру. Лист товаров её накрывает, «Повторить» — над ней.
    func attachPoll(_ card: PersonalizationStoryPollView) {
        if let old = pollView {
            pollBottom = nil
            pollTop = nil
            old.removeFromSuperview()
        }
        pollView = card
        card.translatesAutoresizingMaskIntoConstraints = false
        insertSubview(card, belowSubview: bottomRow ?? retryButton)
        let offset = UILayoutGuide()
        addLayoutGuide(offset)
        let share = Self.offsetShare(card.controller.poll.yOffset)
        let bottom = card.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -pollBottomInset)
        pollBottom = bottom
        let top = card.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: safeInsets.top)
        pollTop = top
        NSLayoutConstraint.activate([
            offset.topAnchor.constraint(equalTo: topAnchor),
            share > 0
                ? offset.heightAnchor.constraint(equalTo: heightAnchor, multiplier: share)
                : offset.heightAnchor.constraint(equalToConstant: 0),
            // Слабее высоты по содержимому (700): сначала сдвиг, не влезшую совсем — прокрутка.
            card.topAnchor.constraint(equalTo: offset.bottomAnchor).withPriority(UILayoutPriority(600)),
            top,
            bottom
        ])
        let outset = 2 * (PersonalizationSpacing.xl - PersonalizationStoryPollView.Style.margin)
        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: contentGuide.centerXAnchor),
            card.widthAnchor.constraint(lessThanOrEqualTo: contentGuide.widthAnchor, constant: outset),
            card.widthAnchor.constraint(lessThanOrEqualToConstant: PersonalizationStoryPollView.Style.maxWidth),
            card.widthAnchor.constraint(equalTo: contentGuide.widthAnchor, constant: outset).withPriority(UILayoutPriority(999))
        ])
    }
}
