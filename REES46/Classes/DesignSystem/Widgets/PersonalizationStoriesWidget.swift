import UIKit
#if canImport(SwiftUI)
import SwiftUI
#endif

/// Управление сторис, которые хост не держит сам, — например, из SwiftUI: открыть сторис,
/// поставить на паузу, продолжить, перезагрузить. Привязывается к виджету при показе.
/// Открытие до привязки ждёт виджет, а тот — загрузки блока; пауза и продолжение без
/// открытого просмотрщика ничего не делают.
@_spi(PersonalizationUI) public final class PersonalizationStoriesController {

    weak var stories: PersonalizationStories? {
        didSet {
            guard let stories, let open = pendingOpen else { return }
            pendingOpen = nil
            open(stories)
        }
    }
    /// Открытие, пришедшее до привязки к виджету.
    private var pendingOpen: ((PersonalizationStories) -> Void)?

    public init() {}

    /// Открыть сторис по индексу в ленте.
    public func open(at index: Int) {
        guard let stories else { return pendingOpen = { $0.open(at: index) } }
        stories.open(at: index)
    }

    /// Открыть сторис по id.
    public func open(storyId: String) {
        guard let stories else { return pendingOpen = { $0.open(storyId: storyId) } }
        stories.open(storyId: storyId)
    }

    public func pause() {
        stories?.pause()
    }

    public func resume() {
        stories?.resume()
    }

    public func reload() {
        stories?.reload()
    }
}

#if canImport(SwiftUI)
/// Сторис для SwiftUI: тот же `PersonalizationStories` — лента блока и просмотрщик, с теми же
/// параметрами. Высота — лента, у пустого или упавшего блока — ноль.
///
/// ```swift
/// PersonalizationStoriesWidget(code: "stories_code", communicationDelegate: router, controller: stories)
/// ```
@available(iOS 13.0, *)
@_spi(PersonalizationUI) public struct PersonalizationStoriesWidget: UIViewRepresentable {

    public var code: String
    public var shopId: String?
    public var sdk: PersonalizationSDK?
    public var texts: PersonalizationStoriesTexts
    public var imageLoader: ((UIImageView, String) -> Void)?
    public weak var communicationDelegate: StoriesCommunicationProtocol?
    public var controller: PersonalizationStoriesController?
    public var onError: ((SdkError) -> Void)?
    public var onLoaded: ((Int) -> Void)?

    public init(
        code: String,
        shopId: String? = nil,
        sdk: PersonalizationSDK? = nil,
        texts: PersonalizationStoriesTexts = PersonalizationStoriesTexts(),
        imageLoader: ((UIImageView, String) -> Void)? = nil,
        communicationDelegate: StoriesCommunicationProtocol? = nil,
        controller: PersonalizationStoriesController? = nil,
        onError: ((SdkError) -> Void)? = nil,
        onLoaded: ((Int) -> Void)? = nil
    ) {
        self.code = code
        self.shopId = shopId
        self.sdk = sdk
        self.texts = texts
        self.imageLoader = imageLoader
        self.communicationDelegate = communicationDelegate
        self.controller = controller
        self.onError = onError
        self.onLoaded = onLoaded
    }

    public func makeUIView(context: Context) -> PersonalizationStories {
        let view = PersonalizationStories(code: code, shopId: shopId)
        // Загрузчик — один раз: замыкания не сравнить, а новый перегружал бы обложки
        // на каждом обновлении SwiftUI.
        view.imageLoader = imageLoader
        apply(to: view)
        // Явный инстанс — после колбэков, чтобы первая загрузка их уже застала.
        if let sdk { view.attach(sdk) }
        return view
    }

    public func updateUIView(_ uiView: PersonalizationStories, context: Context) {
        apply(to: uiView)
        // Смена кода перезагружает ленту сама.
        uiView.code = code
    }

    private func apply(to view: PersonalizationStories) {
        view.shopId = shopId
        view.texts = texts
        view.communicationDelegate = communicationDelegate
        view.onError = onError
        view.onLoaded = onLoaded
        controller?.stories = view
    }

    /// Ширина — предложенная, высота — лента или ноль у схлопнутого блока.
    @available(iOS 16.0, *)
    public func sizeThatFits(_ proposal: ProposedViewSize, uiView: PersonalizationStories, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? UIView.layoutFittingExpandedSize.width, height: uiView.intrinsicContentSize.height)
    }
}
#endif
