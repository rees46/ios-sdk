import UIKit

/// Блок рекомендаций: заголовок, товары, у карусели — точки.
///
/// Источник: Figma Mobile SDK UI Kit, секция Card — Recommender/Carousel (90:655),
/// Recommender/Grid (126:1944), Recommender/List (126:2551).
/// У карусели заголовок с кнопкой «Show all» и точки под лентой, шаг блока 16;
/// у плитки и списка только заголовок, шаг 12.
///
/// Собран из `PersonalizationTitle`, `PersonalizationButton`,
/// `PersonalizationProductsList`, `PersonalizationDots`.
@_spi(PersonalizationUI) public final class PersonalizationRecommenderBlock: UIView {

    public var layout: PersonalizationProductsList.Layout = .carousel {
        didSet { applyLayout() }
    }

    public var text: String? {
        get { title.text }
        set { title.text = newValue }
    }

    /// Подпись кнопки «показать все» у карусели. `nil` — без кнопки.
    public var showAllText: String? {
        didSet {
            showAllButton.text = showAllText
            applyLayout()
        }
    }

    public var onShowAll: (() -> Void)?

    /// У карусели точки под лентой; выключаются, как в макете (showDots).
    public var showDots: Bool = true {
        didSet { applyLayout() }
    }

    public var products: [PersonalizationProduct] {
        get { list.products }
        set {
            list.products = newValue
            dots.count = newValue.count
        }
    }

    public var imageLoader: ((UIImageView, PersonalizationProduct) -> Void)? {
        get { list.imageLoader }
        set { list.imageLoader = newValue }
    }

    public var onProductAction: ((PersonalizationProduct) -> Void)? {
        get { list.onProductAction }
        set { list.onProductAction = newValue }
    }

    /// Нажатие на карточку — открыть товар.
    public var onProductTap: ((PersonalizationProduct) -> Void)? {
        get { list.onProductTap }
        set { list.onProductTap = newValue }
    }

    /// Пропорция картинок карточек, см. `PersonalizationProductCard.imageAspect`.
    public var imageAspect: PersonalizationProductImage.Aspect {
        get { list.imageAspect }
        set { list.imageAspect = newValue }
    }

    private let stack = UIStackView()
    private let title = PersonalizationTitle()
    private let showAllButton = PersonalizationButton(size: .sm, view: .ghost)
    private let list = PersonalizationProductsList()
    private let dots = PersonalizationDots()

    public init(layout: PersonalizationProductsList.Layout = .carousel) {
        super.init(frame: .zero)
        self.layout = layout
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        stack.axis = .vertical
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        stack.addArrangedSubview(title)
        stack.addArrangedSubview(list)
        stack.addArrangedSubview(dots)

        showAllButton.iconEnd = PersonalizationIcons.angleLargeRight
        showAllButton.addTarget(self, action: #selector(showAllTapped), for: .touchUpInside)
        list.onFirstVisibleChanged = { [weak self] index in self?.dots.selectedIndex = index }

        applyLayout()
    }

    @objc private func showAllTapped() {
        onShowAll?()
    }

    private func applyLayout() {
        let carousel = layout == .carousel
        stack.spacing = carousel ? PersonalizationSpacing.xl : PersonalizationSpacing.lg  // 16 / 12
        list.layout = layout
        title.trailing = carousel && !(showAllText ?? "").isEmpty ? showAllButton : nil
        dots.isHidden = !(carousel && showDots)
    }
}
