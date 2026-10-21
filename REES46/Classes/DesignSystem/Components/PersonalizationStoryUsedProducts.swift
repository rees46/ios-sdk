import UIKit

/// Товары слайда сторис: кнопка-переключатель внизу слайда и карусель над ней.
///
/// Источник: Figma Mobile SDK UI Kit, страница Stories (1:32), компонент Used Products
/// (свёрнутый и развёрнутый).
///
/// Свёрнутый — ряд высотой 64 с полями 16 и переключателем по центру: кнопка кита
/// SM Secondary со скруглением Rounded и иконкой `angleUp` после текста (`showText`,
/// по умолчанию «Used products»). Развёрнутый — лист Background/Card: карусель кита
/// (карточки 220, поля 16/0/16/16, шаг 16) и тот же ряд с `hideText` и `angleDown`.
///
/// В начале ряда хост может поставить свою вью — просмотрщик кладёт туда кнопку звука
/// видео-слайда (`leadingView`). Картинки карточек грузит хост через `imageLoader`.
@_spi(PersonalizationUI) public final class PersonalizationStoryUsedProducts: UIView {

    /// Высота ряда с переключателем.
    public static let rowHeight: CGFloat = 64

    public var products: [PersonalizationProduct] = [] {
        didSet { list.products = products }
    }

    /// Подпись свёрнутого переключателя.
    public var showText: String? = "Used products" {
        didSet { applyState() }
    }

    /// Подпись развёрнутого переключателя.
    public var hideText: String? = "Hide products" {
        didSet { applyState() }
    }

    public var isExpanded = false {
        didSet {
            guard oldValue != isExpanded else { return }
            applyState()
        }
    }

    /// Хост кладёт изображение товара в `UIImageView` своим загрузчиком.
    public var imageLoader: ((UIImageView, PersonalizationProduct) -> Void)? {
        didSet { list.imageLoader = imageLoader }
    }

    /// Нажатие на карточку товара.
    public var onProductTap: ((PersonalizationProduct) -> Void)?

    /// Переключатель нажат: новое значение `isExpanded`.
    public var onToggle: ((Bool) -> Void)?

    /// Вью в начале ряда, по центру его высоты. Обычно — кнопка звука.
    public var leadingView: UIView? {
        didSet {
            oldValue?.removeFromSuperview()
            placeLeadingView()
        }
    }

    /// Лист на медиа-слайде: тёмные токены и на iOS 12.
    var forcesDarkTokens = false {
        didSet { applyState() }
    }

    /// Карусель товаров.
    public let list = PersonalizationProductsList(layout: .carousel)

    private let sheet = UIStackView()
    private let listContainer = UIView()
    private let row = UIView()
    private let toggle = PersonalizationButton(size: .sm, view: .secondary)

    public init() {
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        // Поля карусели 16/0/16/16: слева отступ, справа карточки уходят за край листа.
        list.collectionView.contentInset = UIEdgeInsets(
            top: 0, left: PersonalizationSpacing.xl, bottom: 0, right: PersonalizationSpacing.xl
        )
        list.onProductTap = { [weak self] product in self?.onProductTap?(product) }
        list.translatesAutoresizingMaskIntoConstraints = false
        listContainer.addSubview(list)
        NSLayoutConstraint.activate([
            list.topAnchor.constraint(equalTo: listContainer.topAnchor, constant: PersonalizationSpacing.xl),
            list.bottomAnchor.constraint(equalTo: listContainer.bottomAnchor, constant: -PersonalizationSpacing.xl),
            list.leadingAnchor.constraint(equalTo: listContainer.leadingAnchor),
            list.trailingAnchor.constraint(equalTo: listContainer.trailingAnchor)
        ])

        toggle.rounded = true
        toggle.addTarget(self, action: #selector(toggled), for: .touchUpInside)
        toggle.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(toggle)
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: Self.rowHeight),
            toggle.centerXAnchor.constraint(equalTo: row.centerXAnchor),
            toggle.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            toggle.leadingAnchor.constraint(greaterThanOrEqualTo: row.leadingAnchor, constant: Self.toggleSideInset),
            toggle.trailingAnchor.constraint(lessThanOrEqualTo: row.trailingAnchor, constant: -Self.toggleSideInset)
        ])

        sheet.axis = .vertical
        sheet.alignment = .fill
        sheet.addArrangedSubview(listContainer)
        sheet.addArrangedSubview(row)
        sheet.translatesAutoresizingMaskIntoConstraints = false
        addSubview(sheet)
        NSLayoutConstraint.activate([
            sheet.topAnchor.constraint(equalTo: topAnchor),
            sheet.bottomAnchor.constraint(equalTo: bottomAnchor),
            sheet.leadingAnchor.constraint(equalTo: leadingAnchor),
            sheet.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        applyState()
    }

    /// Переключатель не заезжает на вью в начале ряда: поле 16, вью 32 и шаг 8.
    private static let toggleSideInset: CGFloat = PersonalizationSpacing.xl + PersonalizationStorySoundButton.side + PersonalizationSpacing.md

    private func placeLeadingView() {
        guard let leadingView else { return }
        leadingView.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(leadingView)
        NSLayoutConstraint.activate([
            leadingView.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: PersonalizationSpacing.xl),
            leadingView.centerYAnchor.constraint(equalTo: row.centerYAnchor)
        ])
    }

    @objc private func toggled() {
        isExpanded.toggle()
        onToggle?(isExpanded)
    }

    private func applyState() {
        listContainer.isHidden = !isExpanded
        // Фон листа — на самом компоненте: у UIStackView до iOS 14 фона нет.
        backgroundColor = isExpanded
            ? PersonalizationStoryColors.token(PersonalizationColor.backgroundCard, forcingDark: forcesDarkTokens)
            : .clear
        toggle.text = isExpanded ? hideText : showText
        toggle.iconEnd = isExpanded ? PersonalizationIcons.angleDown : PersonalizationIcons.angleUp
    }
}
