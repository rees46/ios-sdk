import UIKit

/// Экран полной выдачи поиска с данными SDK: заголовок с числом найденного, плитка ⇄ список,
/// теги применённых фильтров, счётчик, «загрузить ещё» или бесконечная прокрутка,
/// пустое состояние и экран фильтров — виджет сам ходит в `search` и держит состояние.
///
/// Паттерн SearchResultsScreen из Figma (страница 1:30), источник — `searchFull(query)`.
/// Вся выдача, фильтры, ошибки и тексты — общие с экраном категории, см.
/// `PersonalizationResultsScreen`; здесь — только источник. Цвета и размеры экрана фильтров
/// берутся из `industrial_filters` поиска.
///
/// Каждый новый запрос трекается событием `search`; нажатие на карточку запоминает источник
/// `full_search` и отдаёт товар хосту через `onProductTap`.
@_spi(PersonalizationUI) public final class PersonalizationSearchResultsScreen: PersonalizationResultsScreen<Product> {

    /// Поисковая фраза; смена перезапрашивает первую страницу.
    public var query: String? {
        didSet {
            applyTitle()
            if oldValue != query { scheduleReload() }
        }
    }

    override var requestKey: String {
        (query ?? "").trimmingCharacters(in: .whitespaces)
    }

    override var defaultTitle: String? { query }

    override func trackNewResults(_ sdk: PersonalizationSDK, key: String) {
        sdk.tracking.search(query: key)
    }

    override func fetch(
        _ sdk: PersonalizationSDK,
        key: String,
        page: Int,
        completion: @escaping (Result<ResultsPage<Product>, SdkError>) -> Void
    ) {
        sdk.search(
            query: key,
            limit: pageSize,
            offset: (page - 1) * pageSize,
            sortBy: sortBy,
            sortDir: sortDir,
            locations: locations,
            brands: applied.brandsParam,
            filters: applied.facetsParam,
            priceMin: applied.priceMinValue,
            priceMax: applied.priceMaxValue,
            colors: applied.colors.isEmpty ? nil : applied.colors.sorted(),
            fashionSizes: applied.sizes.isEmpty ? nil : applied.sizes.sorted()
        ) { result in
            completion(result.map { response in
                ResultsPage(items: response.products, total: response.productsTotal, facets: ResultsFacets(
                    priceRange: response.priceRange,
                    brands: (response.brands ?? []).map { ResultsFacetValue(value: $0, count: response.brandCounts?[$0]) },
                    // Модель отдаёт 0, когда числа в ответе нет; цвета или размера без товаров
                    // в выдаче не бывает, так что ноль значит «числа нет».
                    colors: response.industrialFilters?.fashionColors.map {
                        ResultsFacetValue(value: $0.color, count: $0.count > 0 ? $0.count : nil)
                    } ?? [],
                    sizes: response.industrialFilters?.fashionSizes.map {
                        ResultsFacetValue(value: $0.size, count: $0.count > 0 ? $0.count : nil)
                    } ?? [],
                    filters: response.filters ?? [:]
                ))
            })
        }
    }

    override func card(of item: Product, actionText: String?) -> PersonalizationProduct {
        item.toCardProduct(actionText: actionText)
    }

    override func productTapped(_ item: Product) {
        let text = requestKey
        if !text.isEmpty {
            sdk?.tracking.setSource(TrackingSource(type: .fullSearch, code: text))
        }
        super.productTapped(item)
    }
}
