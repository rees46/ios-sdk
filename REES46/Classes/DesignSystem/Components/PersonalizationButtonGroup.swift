import UIKit

/// Группа кнопок (сегментированный переключатель).
///
/// Источник: Figma Mobile SDK UI Kit, секция Button Group (185:5253):
/// фрейм Base Button (185:5315) — сегмент, фрейм Button Group (185:5484) — сама группа.
///
/// В макете нарисован только случай на два сегмента (Grid/List) в размере MD,
/// сегмент же есть и в MD, и в SM — поэтому размер вынесен в API,
/// а число сегментов не ограничено.
public final class PersonalizationButtonGroup: UIView {

    public enum Size {
        case md, sm

        var cornerRadius: CGFloat {
            switch self {
            case .md: return PersonalizationRadius.md  // 6
            case .sm: return PersonalizationRadius.sm  // 4
            }
        }

        /// Отступ сегмента: 6 в MD и 2 в SM, обоих значений нет в шкале спейсингов.
        var padding: CGFloat {
            switch self {
            case .md: return 6
            case .sm: return 2
            }
        }

        var iconSize: CGFloat {
            switch self {
            case .md: return 24
            case .sm: return 20
            }
        }
    }

    /// Сегмент группы.
    ///
    /// `activeIcon` — иконка выбранного сегмента. В макете Grid оставляет ту же
    /// иконку, а List подменяет её на залитую, поэтому это отдельное поле.
    public struct Item {
        public let icon: UIImage?
        public let activeIcon: UIImage?

        public init(icon: UIImage?, activeIcon: UIImage? = nil) {
            self.icon = icon
            self.activeIcon = activeIcon ?? icon
        }
    }

    public var size: Size = .md {
        didSet { rebuild() }
    }

    public var items: [Item] = [] {
        didSet {
            if selectedIndex >= items.count { selectedIndex = 0 }
            rebuild()
        }
    }

    public var selectedIndex: Int = 0 {
        didSet { applySelection() }
    }

    /// Зовётся при выборе сегмента пользователем.
    public var onSelected: ((Int) -> Void)?

    private let stack = UIStackView()
    private var segments: [UIButton] = []

    public init(items: [Item] = [], size: Size = .md) {
        super.init(frame: .zero)
        self.items = items
        self.size = size
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        clipsToBounds = true
        layer.cornerRadius = PersonalizationRadius.lg  // 8
        backgroundColor = PersonalizationColor.buttonSecondary

        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = PersonalizationSpacing.xs  // 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        let inset = PersonalizationSpacing.xs  // 2
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: inset),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -inset),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset)
        ])

        rebuild()
    }

    private func rebuild() {
        segments.forEach { $0.removeFromSuperview() }
        segments = []

        let side = size.iconSize + size.padding * 2
        for index in items.indices {
            let segment = UIButton(type: .custom)
            segment.tag = index
            segment.clipsToBounds = true
            segment.layer.cornerRadius = size.cornerRadius
            segment.imageView?.contentMode = .scaleAspectFit
            segment.imageEdgeInsets = UIEdgeInsets(
                top: size.padding, left: size.padding,
                bottom: size.padding, right: size.padding
            )
            segment.addTarget(self, action: #selector(segmentTapped(_:)), for: .touchUpInside)
            segment.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                segment.widthAnchor.constraint(equalToConstant: side),
                segment.heightAnchor.constraint(equalToConstant: side)
            ])
            stack.addArrangedSubview(segment)
            segments.append(segment)
        }
        applySelection()
    }

    @objc private func segmentTapped(_ sender: UIButton) {
        selectedIndex = sender.tag
        onSelected?(sender.tag)
    }

    private func applySelection() {
        for (index, segment) in segments.enumerated() {
            guard index < items.count else { continue }
            let item = items[index]
            let active = index == selectedIndex
            segment.setImage(active ? item.activeIcon : item.icon, for: .normal)
            segment.backgroundColor = active
                ? PersonalizationColor.buttonPrimary
                : PersonalizationColor.backgroundTransparent
            segment.tintColor = active
                ? PersonalizationColor.textInvertedPrimary
                : PersonalizationColor.textHint
        }
    }
}
