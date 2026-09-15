import UIKit

/// Заголовок выдачи поиска.
///
/// Источник: Figma Mobile SDK UI Kit, секция Title (167:3802), символ Search results (167:3807).
/// Три ряда: заголовок с кнопкой «назад» и переключателем вида, строка с фильтром,
/// сортировкой и числом найденного, ряд применённых фильтров-тегов.
/// Два нижних ряда в макете скрываемые (showResults, showFilters) — здесь они
/// прячутся сами, когда данных нет.
///
/// Собран из готовых компонентов: `PersonalizationTitle`, `PersonalizationButton`,
/// `PersonalizationButtonGroup`, `PersonalizationTag`.
@_spi(PersonalizationUI) public final class PersonalizationSearchResultsTitle: UIView {

    /// Тег применённого фильтра: подпись и снятие по крестику.
    public struct Filter {
        public let label: String
        public let onRemove: () -> Void

        public init(label: String, onRemove: @escaping () -> Void) {
            self.label = label
            self.onRemove = onRemove
        }
    }

    public var text: String? {
        get { titleRow.text }
        set { titleRow.text = newValue }
    }

    /// Индекс выбранного вида выдачи: 0 — плитка, 1 — список.
    public var selectedViewIndex: Int {
        get { viewSwitch.selectedIndex }
        set { viewSwitch.selectedIndex = newValue }
    }

    public var onBack: (() -> Void)?
    public var onViewChanged: ((Int) -> Void)?
    public var onFilters: (() -> Void)?
    public var onSort: (() -> Void)?

    private let column = UIStackView()
    private let titleRow = PersonalizationTitle()
    private let backButton = PersonalizationButton(size: .md, view: .ghost)
    private let viewSwitch = PersonalizationButtonGroup(size: .md)

    private let resultsRow = UIStackView()
    private let filtersButton = PersonalizationButton(size: .md, view: .ghost)
    private let sortButton = PersonalizationButton(size: .md, view: .ghost)
    private let foundPrefix = UILabel()
    private let foundCount = UILabel()
    private let foundSuffix = UILabel()

    private let filtersRow = UIStackView()

    public init() {
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        column.axis = .vertical
        column.alignment = .fill
        column.spacing = PersonalizationSpacing.md  // 8
        column.translatesAutoresizingMaskIntoConstraints = false
        addSubview(column)
        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: topAnchor),
            column.bottomAnchor.constraint(equalTo: bottomAnchor),
            column.leadingAnchor.constraint(equalTo: leadingAnchor),
            column.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])

        backButton.iconStart = PersonalizationIcons.arrowLeft
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)

        viewSwitch.items = [
            .init(icon: PersonalizationIcons.grid2x2, activeIcon: PersonalizationIcons.grid2x2Fill),
            .init(icon: PersonalizationIcons.list, activeIcon: PersonalizationIcons.listFill)
        ]
        viewSwitch.onSelected = { [weak self] index in self?.onViewChanged?(index) }

        titleRow.leading = backButton
        titleRow.trailing = viewSwitch
        column.addArrangedSubview(titleRow)

        buildResultsRow()
        buildFiltersRow()
    }

    private func buildResultsRow() {
        filtersButton.iconStart = PersonalizationIcons.equalizerHorizontal
        filtersButton.addTarget(self, action: #selector(filtersTapped), for: .touchUpInside)
        sortButton.iconStart = PersonalizationIcons.arrowsUpDown
        sortButton.addTarget(self, action: #selector(sortTapped), for: .touchUpInside)

        let controls = UIStackView(arrangedSubviews: [filtersButton, sortButton])
        controls.axis = .horizontal
        controls.alignment = .center
        controls.spacing = PersonalizationSpacing.sm  // 4

        let found = UIStackView(arrangedSubviews: [foundPrefix, foundCount, foundSuffix])
        found.axis = .horizontal
        found.alignment = .center
        found.spacing = PersonalizationSpacing.sm  // 4

        resultsRow.axis = .horizontal
        resultsRow.alignment = .center
        resultsRow.spacing = PersonalizationSpacing.lg  // 12
        resultsRow.addArrangedSubview(controls)
        resultsRow.addArrangedSubview(found)
        resultsRow.addArrangedSubview(PersonalizationFlexibleSpace())
        resultsRow.isHidden = true
        column.addArrangedSubview(resultsRow)
    }

    private func buildFiltersRow() {
        filtersRow.axis = .horizontal
        filtersRow.alignment = .center
        filtersRow.spacing = PersonalizationSpacing.sm  // 4
        filtersRow.isHidden = true
        column.addArrangedSubview(filtersRow)
    }

    @objc private func backTapped() { onBack?() }
    @objc private func filtersTapped() { onFilters?() }
    @objc private func sortTapped() { onSort?() }

    /// Строка «найдено N товаров». Слова — параметры, локализация за интегратором.
    /// Не задана — ряд скрыт.
    public func setResults(prefix: String?, count: Int, suffix: String?) {
        guard prefix != nil || suffix != nil else {
            resultsRow.isHidden = true
            return
        }
        foundPrefix.attributedText = found(prefix ?? "", emphasized: false)
        foundCount.attributedText = found("\(count)", emphasized: true)
        foundSuffix.attributedText = found(suffix ?? "", emphasized: true)
        resultsRow.isHidden = false
    }

    /// Применённые фильтры. Пусто — ряд скрыт.
    public func setFilters(_ filters: [Filter]) {
        filtersRow.arrangedSubviews.forEach { $0.removeFromSuperview() }
        filtersRow.isHidden = filters.isEmpty
        for filter in filters {
            let tag = PersonalizationTag(
                text: filter.label,
                view: .secondary,
                onRemove: filter.onRemove
            )
            filtersRow.addArrangedSubview(tag)
        }
        filtersRow.addArrangedSubview(PersonalizationFlexibleSpace())
    }

    private func found(_ string: String, emphasized: Bool) -> NSAttributedString {
        var attributes = emphasized
            ? PersonalizationTypography.smEmphasized.attributes
            : PersonalizationTypography.smDefault.attributes
        attributes[.foregroundColor] = PersonalizationColor.textSecondary
        return NSAttributedString(string: string, attributes: attributes)
    }
}
