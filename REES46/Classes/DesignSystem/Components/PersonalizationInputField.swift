import UIKit

/// Поле ввода дизайн-системы.
///
/// Источник: Figma Mobile SDK UI Kit, секция Input (167:3746), фрейм Input Field (205:10194).
/// Матрица: 3 размера x 4 состояния x 3 типа.
///
/// Состояния из макета не задаются снаружи, а выводятся из самого поля:
/// Default — пусто, Filled — есть текст, Focus — поле в фокусе, Disabled — `isEnabled`.
public final class PersonalizationInputField: UIView {

    public enum Size {
        case lg, md, sm

        var textStyle: PersonalizationTextStyle {
            switch self {
            // LG берёт кегль со ступени lg, а интерлиньяж со ступени xl: в макете 18/32,
            // тогда как ступень lg — это 18/28.
            case .lg:
                return PersonalizationTextStyle(
                    size: PersonalizationTypography.lgDefault.size,
                    lineHeight: PersonalizationTypography.xlDefault.lineHeight,
                    tracking: PersonalizationTypography.lgDefault.tracking,
                    weight: PersonalizationTypography.lgDefault.weight
                )
            case .md:
                return PersonalizationTypography.baseDefault
            // SM смешан так же: 14/24 против 14/20 у ступени sm.
            case .sm:
                return PersonalizationTextStyle(
                    size: PersonalizationTypography.smDefault.size,
                    lineHeight: PersonalizationTypography.baseDefault.lineHeight,
                    tracking: PersonalizationTypography.smDefault.tracking,
                    weight: PersonalizationTypography.smDefault.weight
                )
            }
        }

        var cornerRadius: CGFloat {
            switch self {
            case .lg: return PersonalizationRadius.xl  // 10
            case .md: return PersonalizationRadius.lg  // 8
            // Радиус SM — 6, из переменной Button SM, а не 4 из общей шкалы: так в макете.
            case .sm: return PersonalizationRadius.md  // 6
            }
        }

        var paddingVertical: CGFloat {
            switch self {
            case .lg: return PersonalizationSpacing.lg  // 12
            case .md: return PersonalizationSpacing.md  // 8
            case .sm: return PersonalizationSpacing.sm  // 4
            }
        }

        /// Горизонтальный отступ типа Input. У Search он равен вертикальному.
        var paddingInput: CGFloat {
            switch self {
            case .lg: return PersonalizationSpacing.xl  // 16
            case .md, .sm: return PersonalizationSpacing.lg  // 12
            }
        }

        /// Отступ слева у типа Select. Справа там тоже вертикальный.
        var paddingSelectStart: CGFloat {
            switch self {
            case .lg: return PersonalizationSpacing.xl  // 16
            case .md: return PersonalizationSpacing.lg  // 12
            case .sm: return PersonalizationSpacing.md  // 8
            }
        }

        var iconSize: CGFloat {
            switch self {
            case .lg: return 32
            case .md, .sm: return 24
            }
        }
    }

    public enum FieldType {
        case search, input, select
    }

    public var text: String? {
        get { textField.text }
        set {
            textField.text = newValue
            applyStateStyle()
        }
    }

    public var placeholder: String? {
        didSet { applyStateStyle() }
    }

    public var size: Size = .lg {
        didSet { applyAll() }
    }

    public var type: FieldType = .search {
        didSet { applyAll() }
    }

    public override var isUserInteractionEnabled: Bool {
        didSet { applyStateStyle() }
    }

    /// Поле недоступно.
    public var isEnabled: Bool = true {
        didSet {
            textField.isEnabled = isEnabled
            applyStateStyle()
        }
    }

    /// Нажатие на крестик у типа Search. Не задан — поле просто очищается.
    public var onClear: (() -> Void)?

    /// Нажатие на поле у типа Select: список открывает потребитель.
    public var onSelectTap: (() -> Void)?

    /// Текст изменился.
    public var onTextChange: ((String) -> Void)?

    /// Само поле ввода: отдано наружу, чтобы можно было задать клавиатуру и делегата.
    public let textField = UITextField()

    private let stack = UIStackView()
    private let startIcon = UIImageView()
    private let endButton = UIButton(type: .system)
    private var stackInsets: [NSLayoutConstraint] = []
    private var iconConstraints: [NSLayoutConstraint] = []

    public init(size: Size = .lg, type: FieldType = .search, placeholder: String? = nil) {
        super.init(frame: .zero)
        self.size = size
        self.type = type
        self.placeholder = placeholder
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        clipsToBounds = true
        layer.borderWidth = 1

        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = PersonalizationSpacing.md  // 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        startIcon.contentMode = .scaleAspectFit
        textField.borderStyle = .none
        textField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textField.addTarget(self, action: #selector(editingChanged), for: .editingChanged)
        textField.addTarget(self, action: #selector(focusChanged), for: .editingDidBegin)
        textField.addTarget(self, action: #selector(focusChanged), for: .editingDidEnd)
        endButton.addTarget(self, action: #selector(endTapped), for: .touchUpInside)

        stack.addArrangedSubview(startIcon)
        stack.addArrangedSubview(textField)
        stack.addArrangedSubview(endButton)

        let tap = UITapGestureRecognizer(target: self, action: #selector(selectTapped))
        addGestureRecognizer(tap)

        applyAll()
    }

    @objc private func editingChanged() {
        applyStateStyle()
        onTextChange?(textField.text ?? "")
    }

    @objc private func focusChanged() {
        applyStateStyle()
    }

    @objc private func endTapped() {
        switch type {
        case .search:
            textField.text = ""
            applyStateStyle()
            onClear?()
        case .select:
            onSelectTap?()
        case .input:
            break
        }
    }

    @objc private func selectTapped() {
        guard type == .select else { return }
        onSelectTap?()
    }

    private func applyAll() {
        applyContent()
        applyStateStyle()
    }

    private func applyContent() {
        layer.cornerRadius = size.cornerRadius

        startIcon.isHidden = type != .search
        startIcon.image = PersonalizationIcons.magnifier
        switch type {
        case .select: endButton.setImage(PersonalizationIcons.angleDown, for: .normal)
        case .search: endButton.setImage(PersonalizationIcons.cross, for: .normal)
        case .input: endButton.setImage(nil, for: .normal)
        }

        // Select — не поле ввода: текст не редактируется, нажатие ловит контейнер.
        textField.isUserInteractionEnabled = type != .select

        NSLayoutConstraint.deactivate(iconConstraints)
        iconConstraints = [
            startIcon.widthAnchor.constraint(equalToConstant: size.iconSize),
            startIcon.heightAnchor.constraint(equalToConstant: size.iconSize),
            endButton.widthAnchor.constraint(equalToConstant: size.iconSize),
            endButton.heightAnchor.constraint(equalToConstant: size.iconSize)
        ]
        NSLayoutConstraint.activate(iconConstraints)

        let vertical = size.paddingVertical
        let leading: CGFloat
        let trailing: CGFloat
        switch type {
        case .search:
            leading = vertical
            trailing = vertical
        case .input:
            leading = size.paddingInput
            trailing = size.paddingInput
        case .select:
            leading = size.paddingSelectStart
            trailing = vertical
        }

        NSLayoutConstraint.deactivate(stackInsets)
        stackInsets = [
            stack.topAnchor.constraint(equalTo: topAnchor, constant: vertical),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -vertical),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: leading),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -trailing)
        ]
        NSLayoutConstraint.activate(stackInsets)
    }

    private func applyStateStyle() {
        let filled = !(textField.text ?? "").isEmpty
        // Крестик — это очистка, поэтому он появляется только когда есть что чистить.
        switch type {
        case .select: endButton.isHidden = false
        case .search: endButton.isHidden = !(filled && isEnabled)
        case .input: endButton.isHidden = true
        }

        let foreground = filled && isEnabled
            ? PersonalizationColor.textPrimary
            : PersonalizationColor.textHint
        // В макете иконка идёт в цвет текста: серая в Default и Disabled, тёмная в Filled.
        startIcon.tintColor = foreground
        endButton.tintColor = foreground

        var attributes = fieldAttributes()
        attributes[.foregroundColor] = foreground
        textField.defaultTextAttributes = attributes
        if let placeholder {
            var hint = fieldAttributes()
            hint[.foregroundColor] = PersonalizationColor.textHint
            textField.attributedPlaceholder = NSAttributedString(string: placeholder, attributes: hint)
        } else {
            textField.attributedPlaceholder = nil
        }

        backgroundColor = isEnabled
            ? PersonalizationColor.backgroundInput
            : PersonalizationColor.backgroundInputDisabled
        layer.borderColor = (textField.isFirstResponder && isEnabled
            ? PersonalizationColor.lineInputFocus
            : PersonalizationColor.lineInput).cgColor
    }

    /// Атрибуты стиля рассчитаны на многострочный `UILabel`: `baselineOffset` там
    /// доводит текст до центра строки. В однострочном поле он сдвигал бы заодно
    /// каретку и выделение, поэтому здесь убран. Межстрочный интервал оставлен —
    /// именно он задаёт полю высоту 56/40/32 из макета.
    private func fieldAttributes() -> [NSAttributedString.Key: Any] {
        var attributes = size.textStyle.attributes
        attributes.removeValue(forKey: .baselineOffset)
        return attributes
    }

    public override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        // cgColor не переключается на смену темы сам.
        applyStateStyle()
    }
}
