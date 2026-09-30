import UIKit

/// Превью сторис в ленте: обложка и подпись под ней.
///
/// Источник: Figma Mobile SDK UI Kit, страница Stories (1:32), компонент Story/Preview.
/// Колонка шириной 88 с шагом 8: `PersonalizationStoryCover` и подпись Regular 12/16
/// с трекингом 0.05, по центру, Text/Primary, одна строка с многоточием.
/// В состоянии skeleton вместо подписи — переливающаяся плашка 64x8 со скруглением 5.
@_spi(PersonalizationUI) public final class PersonalizationStoryPreview: UIView {

    /// Ширина превью — ширина обложки.
    public static let width: CGFloat = PersonalizationStoryCover.side
    /// Высота превью: обложка, шаг и строка подписи.
    public static let height: CGFloat = PersonalizationStoryCover.side + PersonalizationSpacing.md + labelHeight

    private static let labelHeight: CGFloat = 16
    private static let skeletonSize = CGSize(width: 64, height: 8)
    private static let skeletonRadius: CGFloat = 5

    public let cover = PersonalizationStoryCover()

    public var title: String? {
        didSet { applyTitle() }
    }

    public var state: PersonalizationStoryCover.State {
        get { cover.state }
        set {
            cover.state = newValue
            applyState()
        }
    }

    /// Нажатие на превью. В состоянии skeleton не приходит.
    public var onTap: (() -> Void)?

    private let label = UILabel()
    private let labelSlot = UIView()
    private let labelSkeleton = PersonalizationStoryShimmer()

    public init(title: String? = nil, state: PersonalizationStoryCover.State = .default) {
        super.init(frame: .zero)
        self.title = title
        cover.state = state
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        labelSlot.addSubview(label)

        labelSkeleton.layer.cornerRadius = Self.skeletonRadius
        labelSkeleton.clipsToBounds = true
        labelSkeleton.translatesAutoresizingMaskIntoConstraints = false
        labelSlot.addSubview(labelSkeleton)

        let column = UIStackView(arrangedSubviews: [cover, labelSlot])
        column.axis = .vertical
        column.alignment = .center
        column.spacing = PersonalizationSpacing.md  // 8
        column.isUserInteractionEnabled = false
        column.translatesAutoresizingMaskIntoConstraints = false
        addSubview(column)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Self.width),
            column.topAnchor.constraint(equalTo: topAnchor),
            column.bottomAnchor.constraint(equalTo: bottomAnchor),
            column.leadingAnchor.constraint(equalTo: leadingAnchor),
            column.trailingAnchor.constraint(equalTo: trailingAnchor),
            labelSlot.widthAnchor.constraint(equalToConstant: Self.width),
            labelSlot.heightAnchor.constraint(equalToConstant: Self.labelHeight),
            label.topAnchor.constraint(equalTo: labelSlot.topAnchor),
            label.bottomAnchor.constraint(equalTo: labelSlot.bottomAnchor),
            label.leadingAnchor.constraint(equalTo: labelSlot.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: labelSlot.trailingAnchor),
            labelSkeleton.widthAnchor.constraint(equalToConstant: Self.skeletonSize.width),
            labelSkeleton.heightAnchor.constraint(equalToConstant: Self.skeletonSize.height),
            labelSkeleton.centerXAnchor.constraint(equalTo: labelSlot.centerXAnchor),
            labelSkeleton.centerYAnchor.constraint(equalTo: labelSlot.centerYAnchor)
        ])

        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
        isAccessibilityElement = true
        accessibilityTraits = .button

        applyTitle()
        applyState()
    }

    @objc private func tapped() {
        guard state != .skeleton else { return }
        onTap?()
    }

    private func applyState() {
        let skeleton = state == .skeleton
        label.isHidden = skeleton
        labelSkeleton.isHidden = !skeleton
        accessibilityElementsHidden = skeleton
    }

    private func applyTitle() {
        accessibilityLabel = title
        guard let title else {
            label.attributedText = nil
            return
        }
        let style = PersonalizationTypography.xsDefault
        var attributes = style.attributes
        attributes[.foregroundColor] = PersonalizationColor.textPrimary
        // Выравнивание и перенос живут в параграфе стиля: он перекрывает настройки лейбла.
        let paragraph = (style.paragraphStyle.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byTruncatingTail
        attributes[.paragraphStyle] = paragraph
        label.attributedText = NSAttributedString(string: title, attributes: attributes)
    }
}
