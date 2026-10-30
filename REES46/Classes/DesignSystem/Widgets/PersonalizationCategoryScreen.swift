import UIKit

/// Экран категории с данными SDK — сестра `PersonalizationSearchResultsScreen`: в заголовке
/// название категории (`titleText`, задаёт хост) с кнопкой «назад», под ним фильтры,
/// сортировка и счётчик «N products», дальше плитка ⇄ список, «загрузить ещё» или бесконечная
/// прокрутка, пустое состояние и ошибка с повтором. Виджет сам ходит в `getCategory` и держит
/// состояние; всё визуальное, колбэки и тексты — общие с поиском, см.
/// `PersonalizationResultsScreen`.
///
/// В запрос уходят страница, применённые бренды, фасеты и цена, сортировка и локации.
/// Цветов и размеров у категории нет (`industrial_filters` в ответе нет) — этих секций
/// в фильтрах не бывает.
///
/// Трекинг: `categoryView` — один раз на категорию, а не на страницы, фильтры, сортировку
/// и повтор после ошибки. Источник трекинга при нажатии на товар не ставится.
@_spi(PersonalizationUI) public final class PersonalizationCategoryScreen: PersonalizationResultsScreen<CategoryProduct> {

    /// Id категории; смена перезапрашивает первую страницу.
    public var categoryId: String {
        didSet { if oldValue != categoryId { scheduleReload() } }
    }

    /// Категория, для которой уже ушло `categoryView`.
    private var trackedCategoryId: String?

    public init(categoryId: String, shopId: String? = nil) {
        self.categoryId = categoryId
        super.init()
        self.shopId = shopId
        setDefaults()
    }

    required init?(coder: NSCoder) {
        categoryId = ""
        super.init(coder: coder)
        setDefaults()
    }

    /// Счётчик — «N products», без «Found»: категорию не ищут.
    private func setDefaults() {
        foundPrefix = nil
        emptyText = "No products in this category yet."
    }

    override var requestKey: String {
        categoryId.trimmingCharacters(in: .whitespaces)
    }

    override func trackNewResults(_ sdk: PersonalizationSDK, key: String) {
        guard trackedCategoryId != key else { return }
        trackedCategoryId = key
        sdk.tracking.categoryView(categoryId: key)
    }

    override func fetch(
        _ sdk: PersonalizationSDK,
        key: String,
        page: Int,
        completion: @escaping (Result<ResultsPage<CategoryProduct>, SdkError>) -> Void
    ) {
        sdk.getCategory(
            category: key,
            limit: pageSize,
            page: page,
            brands: applied.brandsParam,
            locations: locations,
            filters: applied.facetsParam,
            priceMin: applied.priceMinValue,
            priceMax: applied.priceMaxValue,
            sortBy: sortBy,
            sortDir: sortDir
        ) { result in
            completion(result.map { response in
                ResultsPage(items: response.products, total: response.productsTotal, facets: ResultsFacets(
                    priceRange: response.priceRange,
                    brands: response.brands.compactMap { brand in
                        guard let name = brand.name, !name.isEmpty else { return nil }
                        return ResultsFacetValue(value: name, count: brand.count)
                    },
                    filters: response.filters ?? [:]
                ))
            })
        }
    }

    override func card(of item: CategoryProduct, actionText: String?) -> PersonalizationProduct {
        item.toCardProduct(actionText: actionText)
    }
}
