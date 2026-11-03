import UIKit

// Элементы попапа v3: реестр «тип → вью» и простые элементы — text, box, button, close, image,
// recommendation. Формы, промокод и опрос — в `PopupV3Forms.swift`. Неизвестный тип не роняет
// рендер: дизайн пропускает его при разборе с записью в лог; новый тип — одна запись в реестре.

/// Профиль из формы попапа: стандартные поля и свойства клиента (`custom`).
struct PopupV3Profile: Equatable {
    var email: String?
    var phone: String?
    var firstName: String?
    var lastName: String?
    /// `YYYY-MM-DD`.
    var birthday: String?
    /// `m` или `f`.
    var gender: String?
    var custom: [String: String] = [:]
}

/// Что элементам нужно от попапа и SDK. Колбэки — на главной очереди.
protocol PopupV3Actions: AnyObject {
    var sdk: PersonalizationSDK? { get }
    /// Открыть ссылку: сначала обработчик хоста, потом система. Попап остаётся открытым.
    func open(_ link: String)
    /// Товар ленты рекомендаций: сначала хук хоста (открыл сам — попап закрывается), иначе ссылка товара.
    func product(_ product: PersonalizationProduct)
    /// В буфер обмена и тост `toast`.
    func copy(_ text: String, toast: String?)
    /// Событие попапа: `click`, `submit`, `subscribe` (с каналом).
    func event(_ name: String, channel: String?)
    /// Закрыть попап с событием `close`.
    func close()
    /// Подписка email с флагами согласия.
    func subscribe(email: String, consents: [String], completion: @escaping (Bool) -> Void)
    func saveProfile(_ profile: PopupV3Profile, completion: @escaping (Bool) -> Void)
    func addToSegment(_ id: String, completion: @escaping (Bool) -> Void)
    /// Отзыв опроса в API v3 опросов.
    func review(kind: PersonalizationStoryPoll.Scale, body: [String: Any], completion: @escaping (Bool) -> Void)
    /// Содержимое поменяло высоту (картинка, рекомендации, экран успеха).
    func relayout()
    /// Прокрутить рамку так, чтобы вью было видно (текст ошибки под формой).
    func reveal(_ view: UIView)
}

extension PopupV3Actions {
    func reveal(_ view: UIView) {}
}

/// Общие данные для элементов одного показа. Элементы держат его сильно, а он действия — слабо:
/// действия принадлежат окну попапа.
final class PopupV3RenderContext {
    let runtime: [String: String]
    let texts: PopupV3Texts
    /// Экран — для высоты картинок в vh и %.
    let screenSize: CGSize
    weak var actions: PopupV3Actions?

    init(runtime: [String: String], texts: PopupV3Texts, screenSize: CGSize, actions: PopupV3Actions?) {
        self.runtime = runtime
        self.texts = texts
        self.screenSize = screenSize
        self.actions = actions
    }
}

enum PopupV3Elements {

    typealias Builder = (PopupV3Element, PopupV3RenderContext) -> UIView?

    /// `nil` от вью — элемент не рисуется (картинка с `showImage: false`, рекомендации без кода).
    static let registry: [String: Builder] = [
        "text": text,
        "box": text,
        "button": button,
        "close": close,
        "image": image,
        "recommendation": recommendation,
        "emailCollector": { PopupV3EmailView(element: $0, context: $1) },
        "form": { PopupV3FormView(element: $0, context: $1) },
        "promoCode": { PopupV3PromoView(element: $0, context: $1) },
        "survey": { PopupV3SurveyView(element: $0, context: $1) }
    ]

    static var types: Set<String> { Set(registry.keys) }

    static func make(_ element: PopupV3Element, context: PopupV3RenderContext) -> UIView? {
        guard let builder = registry[element.type] else {
            PopupsV3Log.log("element \(element.id) of type \(element.type) skipped")
            return nil
        }
        let view = builder(element, context)
        view?.accessibilityIdentifier = element.id.isEmpty ? nil : "popupV3.\(element.id)"
        return view
    }

    // MARK: - text, box

    static func text(_ element: PopupV3Element, _ context: PopupV3RenderContext) -> UIView? {
        let spec = PopupV3TextSpec(element, runtime: context.runtime)
        let box = element.box
        let view = PopupV3BoxView(box: box)
        if let message = spec.message {
            let label = PopupV3Label()
            label.attributedText = PopupV3Fonts.attributed(
                spec.spans, size: spec.fontSize, weight: spec.fontWeight, family: box.fontFamily,
                color: box.textColor, lineHeight: box.lineHeight, letterSpacing: box.letterSpacing,
                align: PopupV3Fonts.alignment(spec.align)
            )
            label.accessibilityLabel = PopupV3Markup.plain(message)
            view.fill(with: label)
        } else {
            NSLayoutConstraint.activate([
                view.content.heightAnchor.constraint(equalToConstant: 0),
                view.content.widthAnchor.constraint(equalToConstant: 0).withPriority(.defaultLow)
            ])
        }
        attachLink(element.link(runtime: context.runtime), to: view, context: context)
        return view
    }

    /// Ссылка на всём элементе: нажатие открывает её и шлёт `click`.
    static func attachLink(_ link: String?, to view: UIView, context: PopupV3RenderContext) {
        guard let link else { return }
        let tap = PopupV3Tap {
            context.actions?.event("click", channel: nil)
            context.actions?.open(link)
        }
        view.addGestureRecognizer(tap.recognizer)
        view.isUserInteractionEnabled = true
        view.accessibilityTraits.insert(.link)
        objc_setAssociatedObject(view, &PopupV3Tap.key, tap, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    // MARK: - button

    static func button(_ element: PopupV3Element, _ context: PopupV3RenderContext) -> UIView? {
        let spec = PopupV3ButtonSpec(element, texts: context.texts, runtime: context.runtime)
        let box = element.box
        let view = PopupV3BoxView(box: box)
        let control = PopupV3ButtonControl(text: spec.text, style: spec.style, family: spec.fontFamily, weight: box.fontWeight)
        view.fill(with: control)
        let once = PopupV3Debounce()
        control.popupV3OnTap {
            guard once.allow(), let actions = context.actions else { return }
            switch spec.action {
            case .link:
                actions.event("click", channel: nil)
                if let href = spec.href { actions.open(href) }
            case .copy:
                actions.event("click", channel: nil)
                actions.copy(spec.copyText ?? "", toast: context.texts.copied)
            case .close:
                actions.close()
            }
        }
        return view
    }

    // MARK: - close

    static func close(_ element: PopupV3Element, _ context: PopupV3RenderContext) -> UIView? {
        let spec = PopupV3CloseSpec(element, texts: context.texts, runtime: context.runtime)
        let box = element.box
        let view = PopupV3BoxView(box: box)
        let control: UIControl
        switch spec.mode {
        case .image where spec.imageUrl != nil, .svg:
            let icon = PopupV3CloseIcon(spec: spec)
            control = icon
        default:
            control = PopupV3ButtonControl(text: spec.text, style: spec.style, family: spec.fontFamily, weight: box.fontWeight)
        }
        control.accessibilityLabel = spec.mode == .text ? spec.text : spec.imageAlt
        view.fill(with: control)
        control.popupV3OnTap { context.actions?.close() }
        return view
    }

    // MARK: - image

    static func image(_ element: PopupV3Element, _ context: PopupV3RenderContext) -> UIView? {
        let spec = PopupV3ImageSpec(element, texts: context.texts, runtime: context.runtime)
        guard !spec.hidden, let url = spec.url else { return nil }
        let view = PopupV3BoxView(box: element.box)
        let picture = PopupV3ImageView(spec: spec, url: url, screenHeight: context.screenSize.height) {
            context.actions?.relayout()
        }
        view.fill(with: picture)
        attachLink(spec.link, to: view, context: context)
        return view
    }

    // MARK: - recommendation

    static func recommendation(_ element: PopupV3Element, _ context: PopupV3RenderContext) -> UIView? {
        let spec = PopupV3RecommendationSpec(element)
        guard let code = spec.code else { return nil }
        let view = PopupV3BoxView(box: element.box)
        let block = PersonalizationRecommenderBlock(code: code, sdk: context.actions?.sdk, layout: .carousel)
        block.translatesAutoresizingMaskIntoConstraints = false
        view.content.addSubview(block)
        NSLayoutConstraint.activate([
            block.topAnchor.constraint(equalTo: view.content.topAnchor),
            block.leadingAnchor.constraint(equalTo: view.content.leadingAnchor),
            block.trailingAnchor.constraint(equalTo: view.content.trailingAnchor),
            view.content.bottomAnchor.constraint(greaterThanOrEqualTo: block.bottomAnchor),
            view.content.bottomAnchor.constraint(equalTo: block.bottomAnchor).withPriority(.defaultHigh),
            // Пока товаров нет — заглушка минимальной высоты, как у веба.
            view.content.heightAnchor.constraint(greaterThanOrEqualToConstant: 40)
        ])
        block.onLoaded = { _ in context.actions?.relayout() }
        block.onError = { error in PopupsV3Log.log("recommendations \(code): \(error)") }
        let open = { (product: PersonalizationProduct) in
            context.actions?.event("click", channel: nil)
            context.actions?.product(product)
        }
        block.onProductTap = open
        block.onProductAction = open
        return view
    }
}

// MARK: - Вспомогательные вью

/// Картинка элемента `image`: на ширину ячейки, высота по режиму, радиус и отступ снизу.
final class PopupV3ImageView: UIView {

    let imageView = UIImageView()
    private let spec: PopupV3ImageSpec
    private var height: NSLayoutConstraint?
    private let onSize: () -> Void

    init(spec: PopupV3ImageSpec, url: String, screenHeight: CGFloat, onSize: @escaping () -> Void) {
        self.spec = spec
        self.onSize = onSize
        super.init(frame: .zero)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = CGFloat(spec.radius)
        imageView.accessibilityLabel = spec.alt
        imageView.isAccessibilityElement = true
        switch spec.fit {
        case .cover: imageView.contentMode = .scaleAspectFill
        case .contain: imageView.contentMode = .scaleAspectFit
        case .fill: imageView.contentMode = .scaleToFill
        case .none: imageView.contentMode = .center
        }
        addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -CGFloat(spec.marginBottom))
        ])
        switch spec.height {
        case .px(let value):
            setHeight(imageView.heightAnchor.constraint(equalToConstant: CGFloat(value)))
        case .percent(let value), .vh(let value):
            setHeight(imageView.heightAnchor.constraint(equalToConstant: screenHeight * CGFloat(value) / 100))
        case .auto:
            if let ratio = spec.aspectRatio {
                setHeight(imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: CGFloat(1 / ratio)))
            } else {
                setHeight(imageView.heightAnchor.constraint(equalToConstant: 0))
            }
        }
        PersonalizationStoryImages.shared.load(url) { [weak self] picture in
            guard let self, let picture else { return }
            let image: UIImage?
            switch picture {
            case .image(let value): image = value
            case .gif(let gif): image = UIImage(data: gif.data)
            }
            guard let image else { return }
            self.imageView.image = image
            if case .auto = spec.height, spec.aspectRatio == nil, image.size.width > 0 {
                self.setHeight(self.imageView.heightAnchor.constraint(equalTo: self.imageView.widthAnchor, multiplier: image.size.height / image.size.width))
                self.onSize()
            }
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setHeight(_ constraint: NSLayoutConstraint) {
        height?.isActive = false
        constraint.priority = UILayoutPriority(999)
        constraint.isActive = true
        height = constraint
    }
}

/// Крестик картинкой или SVG. SVG не разбираем — рисуем стандартный крестик цветом кнопки.
final class PopupV3CloseIcon: UIControl {

    private let imageView = UIImageView()
    private let spec: PopupV3CloseSpec

    init(spec: PopupV3CloseSpec) {
        self.spec = spec
        super.init(frame: .zero)
        isAccessibilityElement = true
        accessibilityTraits = .button
        backgroundColor = spec.style.background.uiColor
        let side = CGFloat(spec.size)
        let padX = CGFloat(spec.style.paddingX), padY = CGFloat(spec.style.paddingY)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = false
        addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: side),
            imageView.heightAnchor.constraint(equalToConstant: side),
            imageView.topAnchor.constraint(equalTo: topAnchor, constant: padY),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -padY),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: padX),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -padX)
        ])
        if spec.mode == .image, let url = spec.imageUrl {
            PersonalizationStoryImages.shared.load(url) { [weak self] picture in
                switch picture {
                case .image(let image)?: self?.imageView.image = image
                case .gif(let gif)?: self?.imageView.image = UIImage(data: gif.data)
                case nil: break
                }
            }
        } else {
            imageView.image = Self.cross(side: side, color: spec.style.textColor.uiColor)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = min(CGFloat(spec.style.radius), bounds.height / 2, bounds.width / 2)
    }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.6 : 1 }
    }

    static func cross(side: CGFloat, color: UIColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        return renderer.image { context in
            let inset = side * 0.25
            let path = UIBezierPath()
            path.move(to: CGPoint(x: inset, y: inset))
            path.addLine(to: CGPoint(x: side - inset, y: side - inset))
            path.move(to: CGPoint(x: side - inset, y: inset))
            path.addLine(to: CGPoint(x: inset, y: side - inset))
            path.lineWidth = max(1, side / 12)
            path.lineCapStyle = .round
            color.setStroke()
            path.stroke()
            _ = context
        }
    }
}

/// Нажатие на вью — замыкание.
final class PopupV3Tap: NSObject {
    static var key: UInt8 = 0
    let recognizer: UITapGestureRecognizer
    private let action: () -> Void

    init(_ action: @escaping () -> Void) {
        self.action = action
        self.recognizer = UITapGestureRecognizer()
        super.init()
        recognizer.addTarget(self, action: #selector(fire))
    }

    @objc private func fire() { action() }
}

/// Гасит двойные нажатия: второе в пределах `interval` не проходит.
final class PopupV3Debounce {
    private var last: Date?
    private let interval: TimeInterval

    init(interval: TimeInterval = 0.5) {
        self.interval = interval
    }

    func allow(now: Date = Date()) -> Bool {
        if let last, now.timeIntervalSince(last) < interval { return false }
        last = now
        return true
    }
}

extension UIControl {
    /// `touchUpInside` — замыкание (iOS 12 без `UIAction`).
    func popupV3OnTap(_ action: @escaping () -> Void) {
        let target = PopupV3ControlTarget(action)
        addTarget(target, action: #selector(PopupV3ControlTarget.fire), for: .touchUpInside)
        var targets = objc_getAssociatedObject(self, &PopupV3ControlTarget.key) as? [PopupV3ControlTarget] ?? []
        targets.append(target)
        objc_setAssociatedObject(self, &PopupV3ControlTarget.key, targets, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}

final class PopupV3ControlTarget: NSObject {
    static var key: UInt8 = 0
    private let action: () -> Void

    init(_ action: @escaping () -> Void) {
        self.action = action
    }

    @objc func fire() { action() }
}
