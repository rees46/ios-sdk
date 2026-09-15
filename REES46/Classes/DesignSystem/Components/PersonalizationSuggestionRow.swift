import UIKit

/// Строка подсказки поиска: товар или категория.
///
/// Источник: Figma Mobile SDK UI Kit, секция Card — Product (151:4003) и Category
/// (151:4011), у обоих варианты Image и Text. Строка с картинкой 40x40 и двумя
/// строками текста (у товара цена, у категории родительская категория), либо одна
/// строка текста. У категории справа шеврон. Шаг между картинкой и текстом 10 —
/// значения нет в шкале отступов, взято из макета как есть.
///
/// `highlight` выделяет совпадение с запросом полужирным, как в макете подсказок.
/// Картинку хост грузит в `imageView`.
@_spi(PersonalizationUI) public final class PersonalizationSuggestionRow: UIControl {

    public enum Kind {
        case product, category
    }

    /// Хост грузит картинку сюда; показывается только когда `showImage` включён.
    public let imageView = UIImageView()

    public var kind: Kind = .product {
        didSet { applyKind() }
    }

    public var showImage: Bool = false {
        didSet { applyVisibility() }
    }

    public var title: String? {
        didSet { applyTitle() }
    }

    /// Подстрока запроса, которую надо выделить в `title`.
    public var highlight: String? {
        didSet { applyTitle() }
    }

    /// Цена у товара, родительская категория у категории. Видна только с картинкой.
    public var subtitle: String? {
        didSet { applySubtitle(); applyVisibility() }
    }

    private let row = UIStackView()
    private let column = UIStackView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let chevron = UIImageView()

    public init(kind: Kind = .product) {
        super.init(frame: .zero)
        self.kind = kind
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        row.axis = .horizontal
        row.spacing = Self.gap
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor),
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])

        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = PersonalizationColor.backgroundCard
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: Self.imageSide),
            imageView.heightAnchor.constraint(equalToConstant: Self.imageSide)
        ])

        column.axis = .vertical
        column.alignment = .fill
        column.addArrangedSubview(titleLabel)
        column.addArrangedSubview(subtitleLabel)

        chevron.image = PersonalizationIcons.angleLargeRight
        chevron.tintColor = PersonalizationColor.textHint
        chevron.contentMode = .scaleAspectFit
        chevron.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            chevron.widthAnchor.constraint(equalToConstant: 24),
            chevron.heightAnchor.constraint(equalToConstant: 24)
        ])

        row.addArrangedSubview(imageView)
        row.addArrangedSubview(column)
        row.addArrangedSubview(chevron)

        applyKind()
        applyVisibility()
    }

    private func applyKind() {
        row.alignment = kind == .category ? .center : .top
        chevron.isHidden = kind != .category
        applySubtitle()
    }

    private func applyVisibility() {
        imageView.isHidden = !showImage
        subtitleLabel.isHidden = !showImage || (subtitle ?? "").isEmpty
    }

    private func applyTitle() {
        guard let title else {
            titleLabel.attributedText = nil
            return
        }
        var attributes = PersonalizationTypography.smDefault.attributes
        attributes[.foregroundColor] = PersonalizationColor.textPrimary
        let text = NSMutableAttributedString(string: title, attributes: attributes)
        if let highlight, !highlight.isEmpty,
           let range = title.range(of: highlight, options: .caseInsensitive) {
            text.addAttribute(.font, value: PersonalizationTypography.smEmphasized.font, range: NSRange(range, in: title))
        }
        titleLabel.attributedText = text
    }

    private func applySubtitle() {
        guard let subtitle else {
            subtitleLabel.attributedText = nil
            return
        }
        // У товара это цена полужирным, у категории — родитель серым.
        let style = kind == .product ? PersonalizationTypography.smEmphasized : PersonalizationTypography.smDefault
        var attributes = style.attributes
        attributes[.foregroundColor] = kind == .product ? PersonalizationColor.textPrimary : PersonalizationColor.textHint
        subtitleLabel.attributedText = NSAttributedString(string: subtitle, attributes: attributes)
    }

    private static let imageSide: CGFloat = 40
    private static let gap: CGFloat = 10
}
