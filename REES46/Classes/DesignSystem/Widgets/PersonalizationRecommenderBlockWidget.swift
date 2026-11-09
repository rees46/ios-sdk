import UIKit
#if canImport(SwiftUI)
import SwiftUI
#endif

/// Перезагрузка блока рекомендаций, который хост не держит сам, — например, из SwiftUI.
/// Привязывается к блоку при показе; до привязки ничего не делает.
public final class PersonalizationRecommenderBlockController {

    weak var block: PersonalizationRecommenderBlock?

    public init() {}

    /// Загрузить заново мимо кэша, см. `PersonalizationRecommenderBlock.reload()`.
    public func reload() {
        block?.reload()
    }
}

#if canImport(SwiftUI)
/// Блок рекомендаций для SwiftUI: тот же `PersonalizationRecommenderBlock` с теми же
/// параметрами. Высота — по содержимому при предложенной ширине, у скрытого блока — ноль.
///
/// ```swift
/// PersonalizationRecommenderBlockWidget(code: "block_code", onProductTap: { open($0) })
/// PersonalizationRecommenderBlockWidget(collectionId: "42", layout: .grid)
/// ```
@available(iOS 13.0, *)
public struct PersonalizationRecommenderBlockWidget: UIViewRepresentable {

    public var source: PersonalizationRecommenderBlock.Source
    public var shopId: String?
    public var sdk: PersonalizationSDK?
    public var layout: PersonalizationProductsList.Layout
    public var title: String?
    public var limit: Int?
    public var minProducts: Int
    public var imageAspect: PersonalizationProductImage.Aspect
    public var actionText: String?
    public var showAllText: String?
    public var showDots: Bool
    public var showRating: Bool
    public var imageLoader: ((UIImageView, String) -> Void)?
    public var controller: PersonalizationRecommenderBlockController?
    public var onShowAll: (() -> Void)?
    public var onProductTap: ((PersonalizationProduct) -> Void)?
    public var onProductAction: ((PersonalizationProduct) -> Void)?
    public var onLoaded: ((Int) -> Void)?
    public var onError: ((SdkError) -> Void)?

    /// Параметры — как у `PersonalizationRecommenderBlock`.
    public init(
        source: PersonalizationRecommenderBlock.Source,
        shopId: String? = nil,
        sdk: PersonalizationSDK? = nil,
        layout: PersonalizationProductsList.Layout = .carousel,
        title: String? = nil,
        limit: Int? = nil,
        minProducts: Int = 1,
        imageAspect: PersonalizationProductImage.Aspect = .square,
        actionText: String? = nil,
        showAllText: String? = nil,
        showDots: Bool = false,
        showRating: Bool = false,
        imageLoader: ((UIImageView, String) -> Void)? = nil,
        controller: PersonalizationRecommenderBlockController? = nil,
        onShowAll: (() -> Void)? = nil,
        onProductTap: ((PersonalizationProduct) -> Void)? = nil,
        onProductAction: ((PersonalizationProduct) -> Void)? = nil,
        onLoaded: ((Int) -> Void)? = nil,
        onError: ((SdkError) -> Void)? = nil
    ) {
        self.source = source
        self.shopId = shopId
        self.sdk = sdk
        self.layout = layout
        self.title = title
        self.limit = limit
        self.minProducts = minProducts
        self.imageAspect = imageAspect
        self.actionText = actionText
        self.showAllText = showAllText
        self.showDots = showDots
        self.showRating = showRating
        self.imageLoader = imageLoader
        self.controller = controller
        self.onShowAll = onShowAll
        self.onProductTap = onProductTap
        self.onProductAction = onProductAction
        self.onLoaded = onLoaded
        self.onError = onError
    }

    public func makeUIView(context: Context) -> PersonalizationRecommenderBlock {
        let view = PersonalizationRecommenderBlock(source: source, shopId: shopId, layout: layout)
        // Загрузчик — один раз: замыкания не сравнить, а новый перегружал бы картинки
        // на каждом обновлении SwiftUI.
        view.imageLoader = imageLoader
        apply(to: view)
        // Явный инстанс — после колбэков и вида, чтобы первая загрузка их уже застала.
        if let sdk { view.attach(sdk) }
        return view
    }

    public func updateUIView(_ uiView: PersonalizationRecommenderBlock, context: Context) {
        apply(to: uiView)
        // Смена источника перезагружает блок сама.
        uiView.source = source
    }

    private func apply(to view: PersonalizationRecommenderBlock) {
        view.shopId = shopId
        view.layout = layout
        view.title = title
        view.limit = limit
        view.minProducts = minProducts
        view.imageAspect = imageAspect
        view.actionText = actionText
        view.showAllText = showAllText
        view.showDots = showDots
        view.showRating = showRating
        view.onShowAll = onShowAll
        view.onProductTap = onProductTap
        view.onProductAction = onProductAction
        view.onLoaded = onLoaded
        view.onError = onError
        controller?.block = view
    }

    /// Ширина — предложенная, высота — содержимое при ней или ноль у скрытого блока.
    @available(iOS 16.0, *)
    public func sizeThatFits(_ proposal: ProposedViewSize, uiView: PersonalizationRecommenderBlock, context: Context) -> CGSize? {
        let width = proposal.width ?? (uiView.bounds.width > 0 ? uiView.bounds.width : UIScreen.main.bounds.width)
        return CGSize(width: width, height: uiView.fittingHeight(forWidth: width))
    }
}

@available(iOS 13.0, *)
extension PersonalizationRecommenderBlockWidget {

    /// Блок рекомендаций `code`; `itemId` и `categoryId` — для «похожих» и «с этим покупают».
    public init(
        code: String,
        itemId: String? = nil,
        categoryId: String? = nil,
        locations: String? = nil,
        shopId: String? = nil,
        sdk: PersonalizationSDK? = nil,
        layout: PersonalizationProductsList.Layout = .carousel,
        title: String? = nil,
        limit: Int? = nil,
        minProducts: Int = 1,
        imageAspect: PersonalizationProductImage.Aspect = .square,
        actionText: String? = nil,
        showAllText: String? = nil,
        showDots: Bool = false,
        showRating: Bool = false,
        imageLoader: ((UIImageView, String) -> Void)? = nil,
        controller: PersonalizationRecommenderBlockController? = nil,
        onShowAll: (() -> Void)? = nil,
        onProductTap: ((PersonalizationProduct) -> Void)? = nil,
        onProductAction: ((PersonalizationProduct) -> Void)? = nil,
        onLoaded: ((Int) -> Void)? = nil,
        onError: ((SdkError) -> Void)? = nil
    ) {
        self.init(
            source: .recommendations(code: code, itemId: itemId, categoryId: categoryId, locations: locations),
            shopId: shopId, sdk: sdk, layout: layout, title: title, limit: limit,
            minProducts: minProducts, imageAspect: imageAspect, actionText: actionText,
            showAllText: showAllText, showDots: showDots, showRating: showRating,
            imageLoader: imageLoader, controller: controller, onShowAll: onShowAll,
            onProductTap: onProductTap, onProductAction: onProductAction,
            onLoaded: onLoaded, onError: onError
        )
    }

    /// Коллекция `collectionId`: товары без заголовка.
    public init(
        collectionId: String,
        shopId: String? = nil,
        sdk: PersonalizationSDK? = nil,
        layout: PersonalizationProductsList.Layout = .carousel,
        title: String? = nil,
        limit: Int? = nil,
        minProducts: Int = 1,
        imageAspect: PersonalizationProductImage.Aspect = .square,
        actionText: String? = nil,
        showAllText: String? = nil,
        showDots: Bool = false,
        showRating: Bool = false,
        imageLoader: ((UIImageView, String) -> Void)? = nil,
        controller: PersonalizationRecommenderBlockController? = nil,
        onShowAll: (() -> Void)? = nil,
        onProductTap: ((PersonalizationProduct) -> Void)? = nil,
        onProductAction: ((PersonalizationProduct) -> Void)? = nil,
        onLoaded: ((Int) -> Void)? = nil,
        onError: ((SdkError) -> Void)? = nil
    ) {
        self.init(
            source: .collection(id: collectionId),
            shopId: shopId, sdk: sdk, layout: layout, title: title, limit: limit,
            minProducts: minProducts, imageAspect: imageAspect, actionText: actionText,
            showAllText: showAllText, showDots: showDots, showRating: showRating,
            imageLoader: imageLoader, controller: controller, onShowAll: onShowAll,
            onProductTap: onProductTap, onProductAction: onProductAction,
            onLoaded: onLoaded, onError: onError
        )
    }
}
#endif
