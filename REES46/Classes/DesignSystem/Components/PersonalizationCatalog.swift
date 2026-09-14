import UIKit

/// Экран каталога: заголовок, плитка или список товаров, внизу лоадер, счётчик
/// и кнопка «загрузить ещё».
///
/// Источник: Figma Mobile SDK UI Kit, секция Card — Search results (167:4477) и
/// Category (167:4856). Оба одной формы, разница только в заголовке: у выдачи
/// `PersonalizationSearchResultsTitle`, у категории `PersonalizationTitle` с
/// переключателем вида. Поэтому заголовок здесь — слот, а не вариант.
/// Три нижних элемента в макете скрываемые (showLoader, showCount, showLoadMore).
/// Шаг блока 12.
public final class PersonalizationCatalog: UIView {

    /// Заголовок над товарами: выдача или категория. `nil` — убрать.
    public var header: UIView? {
        didSet {
            oldValue?.removeFromSuperview()
            if let header { stack.insertArrangedSubview(header, at: 0) }
        }
    }

    public let list = PersonalizationProductsList(layout: .grid)

    public var layout: PersonalizationProductsList.Layout {
        get { list.layout }
        set { list.layout = newValue }
    }

    public var products: [PersonalizationProduct] {
        get { list.products }
        set { list.products = newValue }
    }

    public var imageLoader: ((UIImageView, PersonalizationProduct) -> Void)? {
        get { list.imageLoader }
        set { list.imageLoader = newValue }
    }

    public var onProductAction: ((PersonalizationProduct) -> Void)? {
        get { list.onProductAction }
        set { list.onProductAction = newValue }
    }

    public var isLoading: Bool = false {
        didSet { loaderRow.isHidden = !isLoading }
    }

    /// Подпись кнопки «загрузить ещё». `nil` — без кнопки.
    public var loadMoreText: String? {
        didSet {
            loadMoreButton.text = loadMoreText
            loadMoreButton.isHidden = (loadMoreText ?? "").isEmpty
        }
    }

    public var onLoadMore: (() -> Void)?

    private let stack = UIStackView()
    private let loaderRow = UIView()
    private let loader = PersonalizationLoader()
    private let count = PersonalizationCount()
    private let loadMoreButton = PersonalizationButton(size: .md, view: .secondary)

    public init() {
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = PersonalizationSpacing.lg  // 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])

        // Лоадер в макете — по центру строки с полем 4 сверху и снизу.
        loader.translatesAutoresizingMaskIntoConstraints = false
        loaderRow.addSubview(loader)
        NSLayoutConstraint.activate([
            loader.centerXAnchor.constraint(equalTo: loaderRow.centerXAnchor),
            loader.topAnchor.constraint(equalTo: loaderRow.topAnchor, constant: PersonalizationSpacing.sm),
            loader.bottomAnchor.constraint(equalTo: loaderRow.bottomAnchor, constant: -PersonalizationSpacing.sm)
        ])
        loaderRow.isHidden = true

        count.isHidden = true

        loadMoreButton.iconStart = PersonalizationIcons.arrowRotateCw
        loadMoreButton.isHidden = true
        loadMoreButton.addTarget(self, action: #selector(loadMoreTapped), for: .touchUpInside)

        stack.addArrangedSubview(list)
        stack.addArrangedSubview(loaderRow)
        stack.addArrangedSubview(count)
        stack.addArrangedSubview(loadMoreButton)
    }

    @objc private func loadMoreTapped() {
        onLoadMore?()
    }

    /// Счётчик «показано N из M». Слова — параметры. `prefix == nil` — скрыть.
    public func setCount(prefix: String?, shown: Int, separator: String, total: Int) {
        count.isHidden = prefix == nil
        if let prefix { count.set(prefix: prefix, shown: shown, separator: separator, total: total) }
    }
}
