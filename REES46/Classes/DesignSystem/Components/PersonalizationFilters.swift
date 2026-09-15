import UIKit

/// Экран фильтров выдачи: заголовок с крестиком, секции и две кнопки внизу.
///
/// Источник: Figma Mobile SDK UI Kit, страница SearchResultsScreen — Search Results/Filters
/// (203:8083) и /Filters Dark Theme (241:10831). Заголовок — `PersonalizationTitle` c
/// ghost-кнопкой `cross-large` (Title/Filters, 204:8340). Секции двух видов: диапазон
/// «From — to» из двух `PersonalizationInputField` MD и список
/// `PersonalizationCheckboxWithLabel` с `PersonalizationAccordion` «показать ещё».
/// Внизу `PersonalizationButton` MD: secondary «Reset» и primary «Apply» поровну.
/// Шаг между секциями 16, внутри секции 12, заголовок секции — LG/Emphasized 18/28.
/// Фон экрана — Background/Generic.
///
/// Состояние чекбоксов и раскрытия секций живёт здесь; хост получает изменения
/// через `onOptionToggle` и `onRangeChanged` и на «Apply» читает `sections`.
@_spi(PersonalizationUI) public final class PersonalizationFilters: UIView {

    public enum Section {
        /// Два поля «от — до». `select` — поля типа Select, список открывает хост.
        case range(id: String, title: String, fromLabel: String, toLabel: String, from: String? = nil, to: String? = nil, select: Bool = false)
        /// Список чекбоксов; сверх `collapsedCount` прячется за аккордеон.
        case options(id: String, title: String, options: [Option], collapsedCount: Int = 5, showMoreText: String? = nil, showLessText: String? = nil)

        public var id: String {
            switch self {
            case let .range(id, _, _, _, _, _, _): return id
            case let .options(id, _, _, _, _, _): return id
            }
        }
    }

    public struct Option {
        public let id: String
        public let label: String
        public var checked: Bool

        public init(id: String, label: String, checked: Bool = false) {
            self.id = id
            self.label = label
            self.checked = checked
        }
    }

    /// Текущее состояние секций с учётом нажатий пользователя.
    public private(set) var sections: [Section] = []

    public var text: String? {
        get { title.text }
        set { title.text = newValue }
    }

    public var onClose: (() -> Void)?

    public var resetText: String? {
        get { resetButton.text }
        set { resetButton.text = newValue }
    }

    public var applyText: String? {
        get { applyButton.text }
        set { applyButton.text = newValue }
    }

    public var onReset: (() -> Void)?
    public var onApply: (() -> Void)?

    /// Изменился чекбокс: секция, вариант, новое значение.
    public var onOptionToggle: ((_ sectionId: String, _ optionId: String, _ checked: Bool) -> Void)?

    /// Изменилось поле диапазона: секция, «от», «до».
    public var onRangeChanged: ((_ sectionId: String, _ from: String, _ to: String) -> Void)?

    /// Нажато поле диапазона типа Select: секция и какое из двух (`true` — «от»).
    public var onRangeSelectTap: ((_ sectionId: String, _ isFrom: Bool) -> Void)?

    private let stack = UIStackView()
    private let title = PersonalizationTitle()
    private let closeButton = PersonalizationButton(size: .md, view: .ghost, iconStart: PersonalizationIcons.crossLarge)
    private let sectionsColumn = UIStackView()
    private let resetButton = PersonalizationButton(size: .md, view: .secondary)
    private let applyButton = PersonalizationButton(size: .md, view: .primary)
    // Какой секции и варианту принадлежит строка чекбокса; цель iOS 12, UIAction недоступен.
    private var optionRows: [ObjectIdentifier: (sectionId: String, optionId: String)] = [:]

    public init() {
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = PersonalizationColor.backgroundGeneric
        let sectionGap = PersonalizationSpacing.xl  // 16

        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = sectionGap
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])

        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        title.trailing = closeButton
        stack.addArrangedSubview(title)

        sectionsColumn.axis = .vertical
        sectionsColumn.alignment = .fill
        sectionsColumn.spacing = sectionGap
        stack.addArrangedSubview(sectionsColumn)

        resetButton.addTarget(self, action: #selector(resetTapped), for: .touchUpInside)
        applyButton.addTarget(self, action: #selector(applyTapped), for: .touchUpInside)
        let buttons = UIStackView(arrangedSubviews: [resetButton, applyButton])
        buttons.axis = .horizontal
        buttons.distribution = .fillEqually
        buttons.spacing = sectionGap
        buttons.isLayoutMarginsRelativeArrangement = true
        buttons.layoutMargins = UIEdgeInsets(top: sectionGap, left: 0, bottom: 0, right: 0)
        stack.addArrangedSubview(buttons)
    }

    public func setSections(_ items: [Section]) {
        sections = items
        optionRows.removeAll()
        sectionsColumn.arrangedSubviews.forEach { $0.removeFromSuperview() }
        items.forEach { sectionsColumn.addArrangedSubview(buildSection($0)) }
    }

    private func buildSection(_ section: Section) -> UIStackView {
        let column = UIStackView()
        column.axis = .vertical
        column.alignment = .fill
        column.spacing = PersonalizationSpacing.lg  // 12
        switch section {
        case let .range(id, title, fromLabel, toLabel, from, to, select):
            column.addArrangedSubview(heading(title))
            column.addArrangedSubview(buildRange(id: id, fromLabel: fromLabel, toLabel: toLabel, from: from, to: to, select: select))
        case let .options(id, title, options, collapsedCount, showMoreText, showLessText):
            column.addArrangedSubview(heading(title))
            column.addArrangedSubview(buildOptions(id: id, options: options, collapsedCount: collapsedCount, showMoreText: showMoreText, showLessText: showLessText))
        }
        return column
    }

    private func heading(_ text: String) -> UILabel {
        label(text, PersonalizationTypography.lgEmphasized)
    }

    private func label(_ text: String, _ style: PersonalizationTextStyle) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        var attributes = style.attributes
        attributes[.foregroundColor] = PersonalizationColor.textPrimary
        label.attributedText = NSAttributedString(string: text, attributes: attributes)
        return label
    }

    private func buildRange(id: String, fromLabel: String, toLabel: String, from: String?, to: String?, select: Bool) -> UIStackView {
        let fromField = rangeField(id: id, value: from, select: select, isFrom: true)
        let toField = rangeField(id: id, value: to, select: select, isFrom: false)
        let notify: (String) -> Void = { [weak self, weak fromField, weak toField] _ in
            self?.onRangeChanged?(id, fromField?.text ?? "", toField?.text ?? "")
        }
        fromField.onTextChange = notify
        toField.onTextChange = notify

        let fromLabelView = label(fromLabel, PersonalizationTypography.baseDefault)
        let toLabelView = label(toLabel, PersonalizationTypography.baseDefault)
        for view in [fromLabelView, toLabelView] {
            view.setContentHuggingPriority(.required, for: .horizontal)
            view.setContentCompressionResistancePriority(.required, for: .horizontal)
        }
        let row = UIStackView(arrangedSubviews: [fromLabelView, fromField, toLabelView, toField])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = PersonalizationSpacing.lg  // 12
        fromField.widthAnchor.constraint(equalTo: toField.widthAnchor).isActive = true
        return row
    }

    private func rangeField(id: String, value: String?, select: Bool, isFrom: Bool) -> PersonalizationInputField {
        let field = PersonalizationInputField(size: .md, type: select ? .select : .input)
        field.text = value
        field.onSelectTap = { [weak self] in self?.onRangeSelectTap?(id, isFrom) }
        return field
    }

    private func buildOptions(id: String, options: [Option], collapsedCount: Int, showMoreText: String?, showLessText: String?) -> UIStackView {
        let column = UIStackView()
        column.axis = .vertical
        column.alignment = .leading
        column.spacing = PersonalizationSpacing.lg  // 12
        let collapsible = options.count > collapsedCount && !(showMoreText ?? "").isEmpty

        var rows: [PersonalizationCheckboxWithLabel] = []
        for (index, option) in options.enumerated() {
            let row = PersonalizationCheckboxWithLabel(text: option.label, state: option.checked ? .checked : .unchecked)
            row.isHidden = collapsible && index >= collapsedCount
            optionRows[ObjectIdentifier(row)] = (id, option.id)
            row.addTarget(self, action: #selector(optionToggled(_:)), for: .valueChanged)
            rows.append(row)
            column.addArrangedSubview(row)
        }

        if collapsible {
            let hidden = options.count - collapsedCount
            let accordion = PersonalizationAccordion(text: showMoreText, count: hidden)
            accordion.onToggle = { [weak accordion] expanded in
                for (index, row) in rows.enumerated() { row.isHidden = !(expanded || index < collapsedCount) }
                accordion?.text = expanded ? (showLessText ?? showMoreText) : showMoreText
                accordion?.count = expanded ? nil : hidden
            }
            column.addArrangedSubview(accordion)
        }
        return column
    }

    private func updateOption(sectionId: String, optionId: String, checked: Bool) {
        sections = sections.map { section in
            guard case let .options(id, title, options, collapsedCount, showMoreText, showLessText) = section, id == sectionId else {
                return section
            }
            let updated = options.map { option -> Option in
                var copy = option
                if option.id == optionId { copy.checked = checked }
                return copy
            }
            return .options(id: id, title: title, options: updated, collapsedCount: collapsedCount, showMoreText: showMoreText, showLessText: showLessText)
        }
    }

    @objc private func optionToggled(_ sender: PersonalizationCheckboxWithLabel) {
        guard let ids = optionRows[ObjectIdentifier(sender)] else { return }
        let checked = sender.checkState == .checked
        updateOption(sectionId: ids.sectionId, optionId: ids.optionId, checked: checked)
        onOptionToggle?(ids.sectionId, ids.optionId, checked)
    }

    @objc private func closeTapped() {
        onClose?()
    }

    @objc private func resetTapped() {
        onReset?()
    }

    @objc private func applyTapped() {
        onApply?()
    }
}
